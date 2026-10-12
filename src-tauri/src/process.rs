//! Child-process launch policy for the desktop app.

use std::{ffi::OsStr, process::Command};

/// Suppress Windows console creation before the child starts (no console flash).
/// GUI windows and the caller's stdin/stdout/stderr configuration are preserved.
/// Use this for every app-owned child, including relaunches and background probes.
pub(crate) fn command(program: impl AsRef<OsStr>) -> Command {
    #[allow(unused_mut)]
    let mut command = Command::new(program);
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        // Do not combine with CREATE_NEW_CONSOLE or DETACHED_PROCESS: Windows
        // ignores CREATE_NO_WINDOW in those combinations.
        command.creation_flags(0x0800_0000);
    }
    command
}

#[cfg(all(test, windows))]
mod tests {
    use super::*;
    use std::{io::Write, process::Stdio};

    const CONSOLE_PROBE: &str = r#"
Add-Type -Namespace MusicIsland -Name ConsoleProbe -MemberDefinition '[System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();';
[Console]::Out.WriteLine([MusicIsland.ConsoleProbe]::GetConsoleWindow().ToInt64());
"#;

    #[test]
    fn background_output_has_no_console_and_preserves_exit_status() {
        let output = command("powershell.exe")
            .args([
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                &format!("{CONSOLE_PROBE} exit 7"),
            ])
            .output()
            .expect("launch console probe");
        assert_eq!(output.status.code(), Some(7));
        assert_eq!(String::from_utf8_lossy(&output.stdout).trim(), "0");
        assert!(output.stderr.is_empty(), "{:?}", output.stderr);
    }

    #[test]
    fn background_spawn_has_no_console_and_preserves_ipc_pipes() {
        let mut child = command("powershell.exe")
            .args([
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                &format!(
                    "{CONSOLE_PROBE} [Console]::Out.WriteLine([Console]::In.ReadLine()); \
                     [Console]::Error.WriteLine('stderr-ok')"
                ),
            ])
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .expect("launch IPC probe");
        writeln!(child.stdin.take().unwrap(), "stdin-ok").expect("write IPC input");
        let output = child.wait_with_output().expect("wait for IPC probe");
        assert!(output.status.success());
        assert_eq!(
            String::from_utf8_lossy(&output.stdout)
                .lines()
                .collect::<Vec<_>>(),
            ["0", "stdin-ok"]
        );
        assert_eq!(String::from_utf8_lossy(&output.stderr).trim(), "stderr-ok");
    }
}
