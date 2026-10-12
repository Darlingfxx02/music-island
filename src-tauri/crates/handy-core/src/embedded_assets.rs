//! Lossless portable payloads. Only missing or damaged files are decompressed.
use anyhow::{bail, Result};
use flate2::read::ZlibDecoder;
use sha2::{Digest, Sha256};
use std::{
    fs,
    io::{Read, Write},
    path::{Component, Path},
    sync::atomic::{AtomicU64, Ordering},
};

pub struct EmbeddedAsset {
    pub name: &'static str,
    pub size: u64,
    pub sha256: [u8; 32],
    pub packed: &'static [u8],
}

pub(crate) fn checked_directory(path: &Path) -> Result<()> {
    if let Some(parent) = path
        .parent()
        .filter(|p| !p.as_os_str().is_empty() && *p != path)
    {
        checked_directory(parent)?;
    }
    match fs::symlink_metadata(path) {
        Ok(meta) => {
            reject_link(&meta)?;
            if !meta.is_dir() {
                bail!("Runtime path is not a directory");
            }
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => fs::create_dir(path)?,
        Err(e) => return Err(e.into()),
    }
    Ok(())
}

fn reject_link(meta: &fs::Metadata) -> Result<()> {
    #[cfg(windows)]
    {
        use std::os::windows::fs::MetadataExt;
        if meta.file_attributes() & 0x400 != 0 {
            bail!("Resource must not be a reparse point");
        }
    }
    if meta.file_type().is_symlink() {
        bail!("Resource must not be a symbolic link");
    }
    Ok(())
}

fn check_file(path: &Path) -> Result<Option<fs::Metadata>> {
    match fs::symlink_metadata(path) {
        Ok(meta) => {
            reject_link(&meta)?;
            if !meta.is_file() {
                bail!("Invalid resource file");
            }
            Ok(Some(meta))
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(e.into()),
    }
}

pub fn atomic_write(path: &Path, bytes: &[u8]) -> Result<()> {
    checked_directory(
        path.parent()
            .ok_or_else(|| anyhow::anyhow!("Missing resource parent"))?,
    )?;
    check_file(path)?;
    static NEXT: AtomicU64 = AtomicU64::new(0);
    let stamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_nanos();
    let partial = path.with_extension(format!(
        "{}-{stamp}-{}.extracting",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    let result = (|| {
        let mut output = fs::OpenOptions::new()
            .create_new(true)
            .write(true)
            .open(&partial)?;
        output.write_all(bytes)?;
        output.sync_all()?;
        drop(output);
        fs::rename(&partial, path)?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(&partial);
    }
    result
}

pub fn extract_assets(assets: &[EmbeddedAsset], directory: &Path) -> Result<()> {
    checked_directory(directory)?;
    for asset in assets {
        if asset.name.is_empty()
            || asset.name.contains([':', '\\'])
            || Path::new(asset.name)
                .components()
                .any(|c| !matches!(c, Component::Normal(_)))
        {
            bail!("Invalid embedded resource name");
        }
        let path = directory.join(asset.name);
        checked_directory(path.parent().unwrap())?;
        if check_file(&path)?.is_some_and(|m| m.len() == asset.size) {
            let mut input = fs::File::open(&path)?;
            let mut hash = Sha256::new();
            let mut buffer = [0; 64 * 1024];
            loop {
                let count = input.read(&mut buffer)?;
                if count == 0 {
                    break;
                }
                hash.update(&buffer[..count]);
            }
            if <[u8; 32]>::from(hash.finalize()) == asset.sha256 {
                continue;
            }
        }
        let mut bytes = Vec::new();
        ZlibDecoder::new(asset.packed)
            .take(
                asset
                    .size
                    .checked_add(1)
                    .ok_or_else(|| anyhow::anyhow!("Invalid resource size"))?,
            )
            .read_to_end(&mut bytes)?;
        if bytes.len() as u64 != asset.size
            || <[u8; 32]>::from(Sha256::digest(&bytes)) != asset.sha256
        {
            bail!("Embedded resource integrity check failed: {}", asset.name);
        }
        atomic_write(&path, &bytes)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn asset(name: &'static str, data: &[u8]) -> EmbeddedAsset {
        let mut packed = flate2::write::ZlibEncoder::new(Vec::new(), flate2::Compression::best());
        packed.write_all(data).unwrap();
        EmbeddedAsset {
            name,
            size: data.len() as u64,
            sha256: Sha256::digest(data).into(),
            packed: Box::leak(packed.finish().unwrap().into_boxed_slice()),
        }
    }
    #[test]
    fn repairs_same_size_corruption_and_reuses_verified_cache_without_decoding() {
        let dir = tempfile::tempdir().unwrap();
        let mut item = asset("nested/engine.dll", b"valid DLL");
        extract_assets(std::slice::from_ref(&item), dir.path()).unwrap();
        fs::write(dir.path().join(item.name), b"bad   DLL").unwrap();
        extract_assets(std::slice::from_ref(&item), dir.path()).unwrap();
        assert_eq!(fs::read(dir.path().join(item.name)).unwrap(), b"valid DLL");
        let modified = fs::metadata(dir.path().join(item.name))
            .unwrap()
            .modified()
            .unwrap();
        item.packed = b"not compressed";
        extract_assets(&[item], dir.path()).unwrap();
        assert_eq!(
            fs::metadata(dir.path().join("nested/engine.dll"))
                .unwrap()
                .modified()
                .unwrap(),
            modified
        );
    }
    #[test]
    fn broken_or_oversized_payload_never_replaces_existing_file() {
        let dir = tempfile::tempdir().unwrap();
        let mut item = asset("engine.dll", b"valid DLL");
        fs::write(dir.path().join(item.name), b"old file").unwrap();
        item.size = 1;
        assert!(extract_assets(&[item], dir.path()).is_err());
        assert_eq!(
            fs::read(dir.path().join("engine.dll")).unwrap(),
            b"old file"
        );
        assert_eq!(fs::read_dir(dir.path()).unwrap().count(), 1);
    }
    #[test]
    fn traversal_and_non_file_targets_are_rejected() {
        let dir = tempfile::tempdir().unwrap();
        for name in ["../outside", "C:/outside", "file:stream", "nested\\outside"] {
            assert!(extract_assets(&[asset(name, b"payload")], dir.path()).is_err());
        }
        fs::create_dir(dir.path().join("engine.dll")).unwrap();
        assert!(atomic_write(&dir.path().join("engine.dll"), b"payload").is_err());
    }
    #[test]
    fn abandoned_pid_temporary_file_does_not_block_extraction() {
        let dir = tempfile::tempdir().unwrap();
        let target = dir.path().join("engine.dll");
        fs::write(
            target.with_extension(format!("{}.extracting", std::process::id())),
            b"partial",
        )
        .unwrap();
        atomic_write(&target, b"complete").unwrap();
        assert_eq!(fs::read(target).unwrap(), b"complete");
    }
    #[cfg(windows)]
    #[test]
    fn redirected_directory_cannot_extract_into_another_location() {
        use std::os::windows::process::CommandExt;
        let dir = tempfile::tempdir().unwrap();
        let outside = tempfile::tempdir().unwrap();
        let link = dir.path().join("redirected");
        let result = std::process::Command::new("cmd.exe")
            .args(["/C", "mklink", "/J"])
            .arg(&link)
            .arg(outside.path())
            .creation_flags(0x0800_0000)
            .output()
            .unwrap();
        assert!(
            result.status.success(),
            "{}",
            String::from_utf8_lossy(&result.stderr)
        );
        assert!(extract_assets(&[asset("engine.dll", b"payload")], &link).is_err());
        assert_eq!(fs::read_dir(outside.path()).unwrap().count(), 0);
    }
    #[cfg(windows)]
    #[test]
    fn failed_rename_keeps_original_bytes_and_removes_the_partial_file() {
        let dir = tempfile::tempdir().unwrap();
        let target = dir.path().join("engine.dll");
        fs::write(&target, b"original").unwrap();
        let mut permissions = fs::metadata(&target).unwrap().permissions();
        permissions.set_readonly(true);
        fs::set_permissions(&target, permissions.clone()).unwrap();
        let result = atomic_write(&target, b"replacement");
        permissions.set_readonly(false);
        fs::set_permissions(&target, permissions).unwrap();
        assert!(result.is_err());
        assert_eq!(fs::read(target).unwrap(), b"original");
        assert_eq!(fs::read_dir(dir.path()).unwrap().count(), 1);
    }
}
