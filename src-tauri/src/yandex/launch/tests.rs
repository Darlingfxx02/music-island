use super::*;
use std::cell::{Cell, RefCell};

#[test]
fn occupied_saved_port_is_replaced_and_only_a_validated_running_port_is_reused() {
    let listener = std::net::TcpListener::bind((std::net::Ipv4Addr::LOCALHOST, 0)).unwrap();
    let occupied = listener.local_addr().unwrap().port();
    assert_ne!(choose_port(None, Some(occupied)).unwrap(), occupied);
    assert_eq!(choose_port(Some(occupied), None).unwrap(), occupied);
    assert!(choose_port(None, Some(0)).unwrap() >= 1024);
    assert!(choose_port(None, Some(u16::MAX)).unwrap() < u16::MAX);
}

#[test]
fn removing_our_port_manually_does_not_leave_our_address_after_disconnect() {
    assert_eq!(
        without_owned_arguments("--original --remote-debugging-address=127.0.0.1", 49200).unwrap(),
        "--original"
    );
    let foreign = "--remote-debugging-port=9222 --remote-debugging-address=127.0.0.1";
    assert_eq!(without_owned_arguments(foreign, 49200).unwrap(), foreign);
}

struct Fake {
    items: RefCell<Vec<(Location, PathBuf, String)>>,
    writes: Cell<usize>,
    fail: Cell<Option<usize>>,
    journal: PathBuf,
}
impl Fake {
    fn new(path: &Path) -> Self {
        Self {
            items: RefCell::new(vec![
                (
                    Location::Shortcut("Desktop/music.lnk".into()),
                    "Yandex Music.exe".into(),
                    "--original".into(),
                ),
                (
                    Location::Run("Yandex".into()),
                    "Yandex Music.exe".into(),
                    "\"Yandex Music.exe\" --autostart".into(),
                ),
            ]),
            writes: Cell::new(0),
            fail: Cell::new(None),
            journal: path.into(),
        }
    }
}
impl Backend for Fake {
    fn discover(&self, executable: &Path) -> Result<Vec<(Location, String)>> {
        Ok(self
            .items
            .borrow()
            .iter()
            .filter(|(_, e, _)| same_path(e, executable))
            .map(|(location, _, args)| (location.clone(), args.clone()))
            .collect())
    }
    fn read(&self, location: &Location) -> Result<Option<(PathBuf, String)>> {
        Ok(self
            .items
            .borrow()
            .iter()
            .find(|(l, _, _)| l == location)
            .map(|(_, e, a)| (e.clone(), a.clone())))
    }
    fn write(&self, entry: &Entry, expected: &str, value: &str) -> Result<()> {
        assert!(
            load(&self.journal)?
                .unwrap()
                .entries
                .iter()
                .any(|e| e.location == entry.location),
            "backup precedes mutation"
        );
        let next = self.writes.get() + 1;
        self.writes.set(next);
        if self.fail.get() == Some(next) {
            bail!("simulated write failure");
        }
        let mut items = self.items.borrow_mut();
        let item = items
            .iter_mut()
            .find(|(l, _, _)| l == &entry.location)
            .unwrap();
        assert_eq!(item.2, expected);
        item.2 = value.into();
        Ok(())
    }
}

#[test]
fn configuration_is_idempotent_and_restore_keeps_original_startup_command() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("launch.json");
    let backend = Fake::new(&path);
    let originals = backend.items.borrow().clone();
    prepare_with(&backend, &path, Path::new("Yandex Music.exe"), 49200).unwrap();
    assert_eq!(backend.writes.get(), 2);
    prepare_with(&backend, &path, Path::new("Yandex Music.exe"), 49200).unwrap();
    assert_eq!(backend.writes.get(), 2);
    restore_with(&backend, &path).unwrap();
    assert_eq!(*backend.items.borrow(), originals);
    assert!(!path.exists());
    restore_with(&backend, &path).unwrap();
}

#[test]
fn partial_enable_failure_rolls_back_every_completed_write() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("launch.json");
    let backend = Fake::new(&path);
    let originals = backend.items.borrow().clone();
    backend.fail.set(Some(2));
    assert!(prepare_with(&backend, &path, Path::new("Yandex Music.exe"), 49200).is_err());
    assert_eq!(*backend.items.borrow(), originals);
    assert!(!path.exists());
}

#[test]
fn failed_restoration_retains_backup_for_retry() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("launch.json");
    let backend = Fake::new(&path);
    let originals = backend.items.borrow().clone();
    prepare_with(&backend, &path, Path::new("Yandex Music.exe"), 49200).unwrap();
    backend.fail.set(Some(3));
    assert!(restore_with(&backend, &path).is_err());
    assert_eq!(load(&path).unwrap().unwrap().entries.len(), 1);
    restore_with(&backend, &path).unwrap();
    assert_eq!(*backend.items.borrow(), originals);
}

#[test]
fn recovery_after_a_crash_before_a_pending_write_does_not_overwrite_originals() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("launch.json");
    let backend = Fake::new(&path);
    let items = backend.items.borrow();
    let (location, executable, original) = &items[0];
    save(
        &path,
        &Journal {
            port: 49200,
            entries: vec![Entry {
                location: location.clone(),
                executable: executable.clone(),
                original: original.clone(),
                applied: format!("{original} {}", debug_arguments(49200)),
            }],
        },
    )
    .unwrap();
    drop(items);
    restore_with(&backend, &path).unwrap();
    assert_eq!(backend.writes.get(), 0);
}

#[test]
fn restoration_preserves_arguments_added_after_configuration() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("launch.json");
    let backend = Fake::new(&path);
    prepare_with(&backend, &path, Path::new("Yandex Music.exe"), 49200).unwrap();
    backend.items.borrow_mut()[0]
        .2
        .push_str(" --new=\"Русский текст\"");
    restore_with(&backend, &path).unwrap();
    let args = backend.items.borrow()[0].2.clone();
    assert_eq!(
        tokens(&args)
            .unwrap()
            .iter()
            .map(|(_, t)| t.as_str())
            .collect::<Vec<_>>(),
        ["--original", "--new=Русский текст"]
    );
}

#[test]
fn a_replaced_shortcut_target_and_deleted_startup_entry_are_left_alone() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("launch.json");
    let backend = Fake::new(&path);
    prepare_with(&backend, &path, Path::new("Yandex Music.exe"), 49200).unwrap();
    backend.items.borrow_mut()[0].1 = "Another App.exe".into();
    backend.items.borrow_mut().remove(1);
    let before = backend.items.borrow().clone();
    restore_with(&backend, &path).unwrap();
    assert_eq!(*backend.items.borrow(), before);
}

#[test]
fn newly_created_and_updater_rewritten_shortcuts_are_reconciled_without_duplicates() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("launch.json");
    let backend = Fake::new(&path);
    prepare_with(&backend, &path, Path::new("Yandex Music.exe"), 49200).unwrap();
    backend.items.borrow_mut()[0].2 = "--after-update".into();
    backend.items.borrow_mut().push((
        Location::Shortcut("TaskBar/music.lnk".into()),
        "Yandex Music.exe".into(),
        String::new(),
    ));
    prepare_with(&backend, &path, Path::new("Yandex Music.exe"), 49200).unwrap();
    assert_eq!(load(&path).unwrap().unwrap().entries.len(), 3);
    restore_with(&backend, &path).unwrap();
    assert_eq!(backend.items.borrow()[0].2, "--after-update");
    assert_eq!(backend.items.borrow()[2].2, "");
}

#[test]
fn changing_port_does_not_accumulate_debugging_arguments() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("launch.json");
    let backend = Fake::new(&path);
    let originals = backend.items.borrow().clone();
    prepare_with(&backend, &path, Path::new("Yandex Music.exe"), 49200).unwrap();
    prepare_with(&backend, &path, Path::new("Yandex Music.exe"), 49300).unwrap();
    assert!(!backend.items.borrow()[0].2.contains("49200"));
    restore_with(&backend, &path).unwrap();
    assert_eq!(*backend.items.borrow(), originals);
}

#[test]
fn foreign_debugging_configuration_is_never_claimed_or_replaced() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("launch.json");
    let backend = Fake::new(&path);
    backend.items.borrow_mut()[1]
        .2
        .push_str(" --remote-debugging-port=9222");
    let before = backend.items.borrow().clone();
    assert!(prepare_with(&backend, &path, Path::new("Yandex Music.exe"), 49200).is_err());
    assert_eq!(*backend.items.borrow(), before);
    assert!(!path.exists());
}

#[test]
fn parser_preserves_unicode_quotes_escaped_quotes_and_unrelated_flag_values() {
    let args = r#""C:\Музыка\Yandex Music.exe" --name="say \"hi\"" "--remote-debugging-port=49200" --remote-debugging-address=127.0.0.1 --url="keep --remote-debugging-port=49200""#;
    let restored = without_owned_arguments(args, 49200).unwrap();
    let parsed = tokens(&restored).unwrap();
    assert_eq!(
        parsed.iter().map(|(_, t)| t.as_str()).collect::<Vec<_>>(),
        [
            r"C:\Музыка\Yandex Music.exe",
            "--name=say \"hi\"",
            "--url=keep --remote-debugging-port=49200"
        ]
    );
    assert!(tokens("\"broken").is_err());
}
