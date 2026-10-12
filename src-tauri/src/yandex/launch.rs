//! Reversible launch arguments; never modifies the installed client or enables autostart.
use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use std::{
    fs,
    path::{Path, PathBuf},
};

#[cfg(windows)]
mod windows;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
enum Location {
    Shortcut(PathBuf),
    Run(String),
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct Entry {
    location: Location,
    executable: PathBuf,
    original: String,
    applied: String,
}

#[derive(Default, Serialize, Deserialize)]
struct Journal {
    port: u16,
    entries: Vec<Entry>,
}

trait Backend {
    fn discover(&self, executable: &Path) -> Result<Vec<(Location, String)>>;
    fn read(&self, location: &Location) -> Result<Option<(PathBuf, String)>>;
    fn write(&self, entry: &Entry, expected: &str, value: &str) -> Result<()>;
}

fn journal_path() -> Result<PathBuf> {
    Ok(crate::config::config_path()?.with_file_name("yandex-launch.json"))
}

fn load(path: &Path) -> Result<Option<Journal>> {
    match fs::symlink_metadata(path) {
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(error.into()),
        Ok(meta) if meta.len() > 2 * 1024 * 1024 => bail!("Yandex launch backup is too large"),
        Ok(_) => {}
    }
    plain_path(path)?;
    let journal: Journal = serde_json::from_slice(&fs::read(path)?)?;
    if journal.port < 1024 || journal.entries.len() > 512 {
        bail!("Invalid Yandex launch backup");
    }
    Ok(Some(journal))
}

fn save(path: &Path, journal: &Journal) -> Result<()> {
    handy_core::embedded_assets::atomic_write(path, &serde_json::to_vec(journal)?)
}

pub(super) fn same_path(left: &Path, right: &Path) -> bool {
    let normalize = |path: &Path| {
        path.to_string_lossy()
            .trim_start_matches(r"\\?\")
            .to_lowercase()
    };
    normalize(left) == normalize(right)
}

fn debug_arguments(port: u16) -> String {
    format!("--remote-debugging-port={port} --remote-debugging-address=127.0.0.1")
}

// Keep original argument spelling, quoting and spacing when removing our two tokens.
fn tokens(text: &str) -> Result<Vec<(std::ops::Range<usize>, String)>> {
    let bytes = text.as_bytes();
    let mut result = Vec::new();
    let mut i = 0;
    while i < bytes.len() {
        if matches!(bytes[i], b' ' | b'\t') {
            i += 1;
            continue;
        }
        let start = i;
        let mut quoted = false;
        let mut value = String::new();
        while i < bytes.len() && (quoted || !matches!(bytes[i], b' ' | b'\t')) {
            if bytes[i] == b'\\' {
                let begin = i;
                while i < bytes.len() && bytes[i] == b'\\' {
                    i += 1;
                }
                let count = i - begin;
                if i < bytes.len() && bytes[i] == b'"' {
                    value.extend(std::iter::repeat_n('\\', count / 2));
                    if count % 2 == 1 {
                        value.push('"');
                        i += 1;
                        continue;
                    }
                } else {
                    value.extend(std::iter::repeat_n('\\', count));
                    continue;
                }
            }
            if i < bytes.len() && bytes[i] == b'"' {
                if quoted && bytes.get(i + 1) == Some(&b'"') {
                    value.push('"');
                    i += 2;
                } else {
                    quoted = !quoted;
                    i += 1;
                }
            } else if i < bytes.len() {
                let c = text[i..].chars().next().unwrap();
                value.push(c);
                i += c.len_utf8();
            }
        }
        if quoted {
            bail!("Unclosed quote in Yandex launch arguments");
        }
        result.push((start..i, value));
    }
    Ok(result)
}

fn without_owned_arguments(text: &str, port: u16) -> Result<String> {
    let owned_port = format!("--remote-debugging-port={port}");
    let parsed = tokens(text)?;
    if !parsed.iter().any(|(_, value)| value == &owned_port)
        && parsed
            .iter()
            .any(|(_, value)| value.starts_with("--remote-debugging-port"))
    {
        return Ok(text.into());
    }
    let mut result = text.to_string();
    for (span, value) in parsed.into_iter().rev() {
        if value == owned_port || value == "--remote-debugging-address=127.0.0.1" {
            result.replace_range(span, "");
        }
    }
    Ok(result.trim_end().to_string())
}

fn restore_with(backend: &impl Backend, path: &Path) -> Result<()> {
    let Some(mut journal) = load(path)? else {
        return Ok(());
    };
    let mut errors = Vec::new();
    let mut index = 0;
    while index < journal.entries.len() {
        let entry = &journal.entries[index];
        let restored = (|| -> Result<()> {
            let Some((executable, current)) = backend.read(&entry.location)? else {
                return Ok(());
            };
            if !same_path(&executable, &entry.executable) {
                return Ok(());
            }
            let original = if current == entry.applied {
                entry.original.clone()
            } else {
                without_owned_arguments(&current, journal.port)?
            };
            if current != original {
                backend.write(entry, &current, &original)?;
            }
            Ok(())
        })();
        match restored {
            Ok(()) => {
                journal.entries.remove(index);
                save(path, &journal)?;
            }
            Err(error) => {
                errors.push(format!("{:?}: {error:#}", entry.location));
                index += 1;
            }
        }
    }
    if !errors.is_empty() {
        bail!(
            "Could not restore Yandex launch settings: {}",
            errors.join("; ")
        );
    }
    fs::remove_file(path)?;
    Ok(())
}

fn prepare_with(backend: &impl Backend, path: &Path, executable: &Path, port: u16) -> Result<()> {
    let mut journal = load(path)?.unwrap_or(Journal {
        port,
        entries: Vec::new(),
    });
    if journal.port != port
        || journal
            .entries
            .iter()
            .any(|e| !same_path(&e.executable, executable))
    {
        restore_with(backend, path)?;
        journal = Journal {
            port,
            entries: Vec::new(),
        };
    }
    let apply = (|| -> Result<()> {
        let candidates = backend.discover(executable)?;
        if candidates.is_empty() {
            bail!("No writable Yandex Music shortcuts or existing startup entry were found");
        }
        if candidates.len() > 512 {
            bail!("Too many Yandex launch entries");
        }
        for (location, current) in candidates {
            let previous = journal.entries.iter().position(|e| e.location == location);
            if previous.is_some_and(|i| journal.entries[i].applied == current) {
                continue;
            }
            let original = if previous.is_some() {
                without_owned_arguments(&current, port)?
            } else {
                current.clone()
            };
            if tokens(&original)?
                .iter()
                .any(|(_, value)| value.starts_with("--remote-debugging-"))
            {
                bail!(
                    "Yandex launch arguments already contain separately configured debugging flags"
                );
            }
            let applied = if original.is_empty() {
                debug_arguments(port)
            } else {
                format!("{original} {}", debug_arguments(port))
            };
            let entry = Entry {
                location,
                executable: executable.into(),
                original,
                applied,
            };
            if let Some(i) = previous {
                journal.entries[i] = entry.clone();
            } else {
                if journal.entries.len() >= 512 {
                    bail!("Too many backed-up Yandex launch entries");
                }
                journal.entries.push(entry.clone());
            }
            // Write-ahead backup makes a crash between shortcut/registry writes recoverable.
            save(path, &journal)?;
            backend.write(&entry, &current, &entry.applied)?;
        }
        Ok(())
    })();
    if let Err(error) = apply {
        if let Err(rollback) = restore_with(backend, path) {
            bail!("{error:#}; rollback incomplete: {rollback:#}");
        }
        return Err(error);
    }
    Ok(())
}

pub(super) fn plain_path(path: &Path) -> Result<()> {
    for ancestor in path.ancestors().filter(|p| !p.as_os_str().is_empty()) {
        let meta = fs::symlink_metadata(ancestor)?;
        #[cfg(windows)]
        {
            use std::os::windows::fs::MetadataExt;
            if meta.file_attributes() & 0x400 != 0 {
                bail!("Refusing a redirected Yandex launch path");
            }
        }
        if meta.file_type().is_symlink() {
            bail!("Refusing a linked Yandex launch path");
        }
    }
    Ok(())
}

pub fn prepare(executable: &Path, running_port: Option<u16>) -> Result<u16> {
    let path = journal_path()?;
    let previous = load(&path)?.map(|journal| journal.port);
    let port = choose_port(running_port, previous)?;
    #[cfg(windows)]
    prepare_with(&windows::WindowsBackend::new()?, &path, executable, port)?;
    #[cfg(not(windows))]
    bail!("Managed Yandex launch is only supported on Windows");
    #[allow(unreachable_code)]
    Ok(port)
}

fn choose_port(validated_running_port: Option<u16>, previous: Option<u16>) -> Result<u16> {
    Ok(match validated_running_port.or(previous) {
        Some(port)
            if (1024..u16::MAX).contains(&port)
                && (validated_running_port == Some(port)
                    || std::net::TcpListener::bind((std::net::Ipv4Addr::LOCALHOST, port))
                        .is_ok()) =>
        {
            port
        }
        _ => super::reserve_local_port()?,
    })
}

pub fn reconcile(enabled: bool) -> Result<()> {
    let path = journal_path()?;
    let Some(journal) = load(&path)? else {
        if enabled {
            if let Some(executable) = super::find_executable() {
                prepare(&executable, None)?;
            }
        }
        return Ok(());
    };
    #[cfg(windows)]
    {
        let backend = windows::WindowsBackend::new()?;
        if enabled {
            if let Some(executable) = super::find_executable() {
                prepare_with(&backend, &path, &executable, journal.port)?;
            }
        } else {
            restore_with(&backend, &path)?;
        }
    }
    #[cfg(not(windows))]
    {
        let _ = (journal, enabled);
    }
    Ok(())
}

#[cfg(test)]
mod tests;
