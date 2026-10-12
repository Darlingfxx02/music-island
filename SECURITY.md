# Security and privacy

## Local data and optional services

Music Island has no telemetry. Media-provider arbitration, Better Voice and local
speech recognition run on the computer. Direct Yandex, assistant quotas and cloud
text processing are explicit opt-ins; onboarding and Handy import do not enable
cloud processing. Model downloads contact the pinned catalog's servers without
uploading recordings. See [Privacy](docs/PRIVACY.md).

Settings, models, history and recordings are stored under owned Music Island
AppData folders. History and audio are not encrypted at rest. External service
keys are protected with current-user Windows DPAPI and are omitted from interface
snapshots and diagnostics. DPAPI is not protection against another process running
as the same signed-in user. Logs and support bundles should not contain tokens or
transcription text; inspect diagnostic logs before sharing them.

Model import copies selected files and leaves Handy unchanged. Cleanup uses fixed
application roots after shutdown and does not traverse reparse points. History
filenames are checked at the native manager boundary before audio access/deletion.
These checks are covered by fixtures; they are not a claim of an independent audit.

## Direct Yandex launch settings

Consented Direct mode persists loopback debug arguments in supported per-user
Yandex Music shortcuts and existing HKCU Run values. It does not patch executable
code, replace the shortcut target, register a debugger, enable autostart, or install
a background service/task. A write-ahead backup under Music Island AppData allows
restoration on SMTC selection or full data cleanup; failed restoration retains
the backup. Reparse paths and foreign shortcut targets are rejected. Restart
commands target process IDs belonging to the known installation path.

The debug endpoint extends local renderer access while the client is running,
including launches when Music Island is closed. Loopback limits network exposure;
it does not authenticate other local processes. No antivirus/firewall exceptions
are requested. Unsigned builds and security heuristics can still produce warnings;
these tests are not a guarantee against false positives. See
[launch scope and recovery](docs/YANDEX_MUSIC_API.md#persistent-direct-launches).

## Portable update integrity and executable signing

The custom GitHub Releases updater requires both `music-island.exe` and
`SHA256.txt`. It verifies SHA-256 and basic Windows PE structure before replacing
the executable. A missing or mismatched checksum rejects the update. Downloads
use HTTPS. The release build writes the checksum for the final portable artifact.

**Current local builds are not Authenticode-signed.** SHA-256 detects corruption
and disagreement between the two release assets; it does not authenticate a
publisher independently of the GitHub release account. Windows may show
SmartScreen. No signing certificate or private signing key is included in the
repository. The unused standard Tauri updater plugin has been removed; updates
continue through the existing portable updater.

The embedded dictation runtime has a separate manifest of DLL sizes and hashes.
The host verifies extracted files and loads absolute paths with restricted Windows
DLL search flags. ASR model weights are downloaded separately and retain their
own licenses and upstream integrity mechanisms.

## Shutdown

Tray exit, updater replacement and full cleanup share one shutdown path. Audio,
recording/download work and the loaded recognition model are stopped outside the
Windows event loop. A worker deadline is 8 seconds, followed by a 2-second final
exit fallback if the event loop cannot close. The fallback terminates only Music
Island; it does not kill Handy or other applications. Interrupted operations may
remain incomplete, so shutdown is not a promise to finish a download or transcription.

## Reporting issues

Open a private security advisory on GitHub, or contact the maintainer on Telegram:
[@redheadesign](https://t.me/redheadesign) (Russian & English).

Include the app version, Windows version, reproduction steps and affected media
player/model when relevant. Do not include private recordings, transcription text,
account tokens or service keys.
