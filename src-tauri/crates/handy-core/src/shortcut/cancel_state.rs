use std::sync::Mutex;

/// Reconcile a queued lifecycle request against the latest desired binding.
/// The closure is evaluated under the same lock as registration, so a delayed
/// start task cannot restore Escape after a newer stop task removed it.
pub(super) struct CancelState<K>(Mutex<Option<K>>);
impl<K: PartialEq> CancelState<K> {
    pub const fn new() -> Self {
        Self(Mutex::new(None))
    }
    pub fn reconcile(
        &self,
        desired: impl FnOnce() -> Option<K>,
        remove: impl FnOnce(&K) -> Result<(), String>,
        register: impl FnOnce(&K) -> Result<(), String>,
    ) -> Result<(), String> {
        let mut registered = self.0.lock().unwrap_or_else(|e| e.into_inner());
        let next = desired();
        if *registered != next {
            if let Some(old) = registered.as_ref() {
                remove(old)?;
            }
            *registered = None;
            if let Some(next) = next.as_ref() {
                register(next)?;
            }
            *registered = next;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicBool, Ordering};

    #[test]
    fn delayed_start_after_stop_reads_latest_request() {
        let state = CancelState::new();
        let requested = AtomicBool::new(true);
        let reconcile = || {
            state.reconcile(
                || requested.load(Ordering::SeqCst).then_some("escape"),
                |_| panic!("nothing was registered"),
                |_| panic!("a stopped recording must not acquire Escape"),
            )
        };
        requested.store(false, Ordering::SeqCst);
        reconcile().unwrap(); // queued stop
        reconcile().unwrap(); // older queued start runs last
    }

    #[test]
    fn removes_registered_binding_and_supports_backend_changes() {
        let state = CancelState::new();
        let calls = std::cell::RefCell::new(Vec::new());
        for desired in [
            Some("tauri:escape"),
            Some("tauri:escape"),
            None,
            None,
            Some("handy:escape"),
            Some("tauri:escape"),
        ] {
            state
                .reconcile(
                    || desired,
                    |old| {
                        calls.borrow_mut().push((false, *old));
                        Ok(())
                    },
                    |next| {
                        calls.borrow_mut().push((true, *next));
                        Ok(())
                    },
                )
                .unwrap();
        }
        assert_eq!(
            calls.into_inner(),
            vec![
                (true, "tauri:escape"),
                (false, "tauri:escape"),
                (true, "handy:escape"),
                (false, "handy:escape"),
                (true, "tauri:escape")
            ]
        );
    }

    #[test]
    fn failed_registration_remains_retryable() {
        let state = CancelState::new();
        assert!(state
            .reconcile(|| Some("escape"), |_| Ok(()), |_| Err("busy".into()))
            .is_err());
        state
            .reconcile(
                || Some("escape"),
                |_| panic!("failed registration must be retryable"),
                |_| Ok(()),
            )
            .unwrap();
        assert!(state
            .reconcile(|| Some("new-backend"), |_| Ok(()), |_| Err("busy".into()))
            .is_err());
        state
            .reconcile(
                || Some("new-backend"),
                |_| panic!("the old binding was already removed"),
                |_| Ok(()),
            )
            .unwrap();
    }
}
