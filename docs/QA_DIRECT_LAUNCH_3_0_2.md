# Direct launch persistence · 3.0.2 · 2026-10-12

Candidate: `release/v3.0.2-direct-launch/music-island.exe`, Windows x64 GUI.
76,391,936 bytes (72.85 MiB), 46.74% smaller than the accepted 137 MiB baseline.
SHA-256: `d801d5b05b0ad61a843cc909818bd6c13813dcaabcd2244227bbfb73c550cc84`.
Earlier input-fix and optimized packets are preserved unchanged and superseded.
The user confirmed that the candidate works and authorized the 3.0.2 patch
release on 2026-10-12. Publication reuses these exact tested bytes.

## Implemented

Consented Direct mode configures existing per-user Desktop, Start menu, Startup
and pinned taskbar shortcuts, plus supported existing HKCU Run commands. Original
arguments are backed up before edits. Client executable, shortcut target, icon,
description, working directory and autostart enablement are preserved. Standard
Windows COM APIs are used; no client patch, injected launcher, IFEO debugger,
service, scheduled task or Defender/firewall exclusion is installed.

Startup migrates already consented Direct settings and reconciles existing launch
entries. Bounded passive recovery repairs updater-rewritten entries without
restarting the client. Explicit connect can reuse a validated endpoint, or choose
a free loopback port accepted by Electron (excluding 65535). Returning to SMTC
restores owned arguments before changing source; only a running validated debug
client is restarted. Full data cleanup restores launch settings and disables
Direct in configuration before shutdown, preventing queued recovery from
reapplying the flags after the backup is removed.

## Verified

- 127 native app tests passed; four pre-existing interactive tests ignored.
  Real Windows COM fixtures cover Desktop/Start/Startup/taskbar links and an
  isolated registry key. They preserve descriptions and original commands,
  tolerate a stale temporary link from a reused PID and run on an existing MTA
  worker. No real Yandex shortcuts or startup commands were changed during QA.
- Fixtures cover idempotence, occupied/invalid ports, updater-rewritten/new
  shortcuts, a crash before a pending write, partial rollback, retry after failed
  restoration, removed/changed targets, user argument edits, Unicode/quotes and
  foreign debugging settings. Native media edits preserve other settings.
- 236 frontend tests passed; build, lint/boundaries, Storybook typecheck and static
  build passed. Existing advisory lint/native warnings remain. Dialog Russian,
  English and 320 px states were reviewed in the browser; the updated button
  interaction completed without errors. The initial visibility assertion during
  entrance animation was replaced with the intended text-presence assertion.
- Final portable build passed. All 380 frozen input hashes matched; embedded
  HTML/JS/CSS matched the frozen frontend and include the updated consent copy.
  All 52 compressed payloads and 27 DLLs matched original hashes; raw/packed
  payloads remain 107,028,593 / 40,105,235 bytes. Fox assets were not changed.
- EXE-only isolated Russian/English CPU recognition, ABI 1, VAD, unload and all
  26 extracted inference DLL hashes passed. No microphone or real user profile
  was involved.
- Local Microsoft Defender custom scan completed for this exact executable:
  scan ID `{37697E07-2302-44A4-B14D-E679C9CA54D4}`, events 1000/1001, definition
  version `1.459.682.0`, engine/product `4.18.26090.9`. No matching detections;
  no matching configured path/EXE-extension exclusions. No protection settings
  were modified. This is one local static scan, not a multi-vendor or behavioral
  compatibility guarantee. The executable remains unsigned.

Evidence: `.local/direct-launch-qa`, frozen
`.local/release-3.0.2-direct-launch-input/manifest.json`, artifact
`.local/release-3.0.2-direct-launch-artifact.json`, embedded frontend
`.local/release-3.0.2-direct-launch-embedded-frontend/manifest.json`, isolated
`.local/release-3.0.2-direct-launch-qa/probes.json`.

## Release source verification

The staged release contains all 380 frozen source/configuration inputs, with
identical contents after Git line-ending normalization. Only unrelated landing
development scripts are omitted from `package.json`; versions and dependencies
match. Unfinished landing and promotional media files remain outside this patch.

An isolated export of the staged source passed the production frontend build
and Storybook type check. After restoring frozen source line endings, compiled
JavaScript matches the candidate apart from filenames for two otherwise identical
SVG assets whose hashes change with Git CRLF checkout. CSS and media are byte-identical.
Evidence: `.local/release-3.0.2-publish-source-check.json` and the publish build logs.
The native EXE is unchanged and is not rebuilt for publication.

## Manual checks before publishing

1. Quit the old Music Island through the tray, then open the new candidate. With
   saved Direct consent, existing supported launch entries are configured. If
   Yandex Music is already open normally, use one explicit restart to establish
   the debug endpoint.
2. Close Yandex Music and reopen from Start, Desktop and the pinned taskbar button.
   Verify connection and playback controls. Existing custom launchers and directly
   opening the client EXE are outside the managed scope.
3. Reboot Windows with Yandex autostart enabled; repeat with it disabled. Check
   that existing enablement is preserved and normal supported launches reconnect.
4. Select SMTC, then close/reopen Yandex from the same entries. Owned debug flags
   must be absent. If Yandex was closed, switching source must not open it.
5. Confirm an updater-rewritten shortcut is repaired during reconnect. A client
   already running without flags needs one explicit restart; passive repair must
   not restart it automatically.

The user's Windows acceptance was received on 2026-10-12. Their confirmation
does not identify individual checks; real reboot, Windows 10, physical microphone
routing, GPU inference and other antivirus engines have no separate recorded
results. Use this same EXE without rebuilding unless compiled inputs change.
