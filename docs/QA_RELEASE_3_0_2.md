# Release 3.0.2 QA

Prepared on 12 October 2026. Publication is pending the user's Windows testing.

## Current candidate: reviewed and optimized portable build

The user confirmed the input-fix build works, then requested Ponytail Review and
build-size optimization. That accepted copy remains unchanged. The new candidate
is `release/v3.0.2-optimized/music-island.exe`, Windows x64 GUI, version 3.0.2.

- 76,248,064 bytes (72.72 MiB), down from 143,439,360 (136.79 MiB): **46.84% smaller**.
- SHA-256: `6122d2a5b9e357efd37f9c319cf3c43cd891d13fc014fbb48c013b6271a02cc3`.
- All 12 review findings fixed; report: [production review](REVIEW_BUILD_3_0_2.md).
- Frontend: 234 tests in 49 files; production build, lint/boundaries, Storybook
  type check and build pass. Real Storybook fox playback inspected.
- Native: 110 app tests and 277 Handy tests pass; four existing interactive
  tests ignored. Cargo check --locked and Clippy correctness pass.
- Two build-script tests pass; real bundle cache preserves all 27 file timestamps.
- 376 frozen source/config/resource hashes verified. HTML/JS/CSS recovered from
  the final EXE match the final frozen frontend. No compiled input changed.
- 52 compressed resources checked inside the EXE; all 27 DLLs decompress to the
  original size/hash. CPU variants, Vulkan, model families and notices preserved.
- EXE-only isolated fresh profiles: RU/EN Whisper Tiny CPU recognition, ABI 1,
  VAD/reset, unloading, device enumeration and all 26 inference DLL hashes pass.
- Warm run keeps DLL timestamps; same-length corruption is repaired before load.
- DeepFilter bytes recovered from the EXE load and process eight silent 480-sample
  mono frames at 48 kHz with finite normalized output, without a microphone.
- Fox source videos/posters unchanged; no alpha conversion or re-encoding.

Evidence: `.local/optimization-baseline/`,
`.local/release-3.0.2-optimized-final-input/manifest.json`,
`.local/release-3.0.2-optimized-artifact.json`,
`.local/release-3.0.2-optimized-embedded-frontend/manifest.json`,
`.local/release-3.0.2-optimized-qa/{probes,cache-probes,voice-probe}.json`.

First compression build took 22m58s. Additional rapid Start/Stop tests found a
fox state freeze; the final frontend refresh took 10m02s and reused unchanged
native dependencies. Intermediate EXE stays under `.local/` and is not a candidate.

Publication remains pending the user's new GUI smoke test. Live microphone/device
routing, GPU inference, Windows 10, driver interaction and a published self-update
were not exercised. No user profile changes, release, tag or app restart.

## Previous accepted candidate: expanded-island input fix

The original candidate below is superseded by
`release/v3.0.2-input-fix/music-island.exe` after the user reported right-side
clicks and hover passing through. This remains version 3.0.2.

- Size: 143,439,360 bytes; Windows x64 GUI; built 12 October, 14:23:52 Moscow.
- SHA-256: `8f906148dd6bbbc7a3678358b0982d4ed5930bd5e1b268d94396dec9865f39a0`.
- Native compilation passed in 12m 35s. Native check passed in 57.18s;
  all 107 root tests passed with four existing interactive probes ignored.
- The two new regression cases failed before the fix and pass afterward:
  initial opacity of an already-layered parent, and recovery from zero alpha
  plus a color key when input-style bits have not changed.

Read-only inspection of the running original candidate confirmed that the main
HWND and WebView had matching full-monitor bounds; the layered parent had no
initialized opacity attributes. The correction sets parent opacity 255 with
`LWA_ALPHA` only, keeping `WS_EX_LAYERED` stable and using `WS_EX_TRANSPARENT`
for cursor input. Duplicate style/opacity updates remain suppressed. A separate
hidden-window fixture confirmed that setting opacity succeeds both with and
without Tao's `CS_OWNDC` class style.

Only `src-tauri/src/window/clickthrough.rs` changed among compiled inputs since
the previous candidate. All 428 input hashes match the new manifest; embedded
HTML/JS/CSS match the previous frozen frontend byte for byte. All 26 embedded
inference DLLs, the executable copy, checksum and packet notices/notes passed.
Inference code is unchanged; the preceding isolated RU/EN checks still cover
that identical bundle, and were not repeated for this mouse-input-only change.

The running original EXE/profile were not changed or stopped. Computer Use
did not expose the click-through overlay as a targetable window, so actual
GPU composition and left/right click behavior after restart still require
the user's Windows check. Native attribute tests do not establish that result.

Evidence: `.local/overlay-input-*-2026-10-12.log`,
`.local/overlay-input-before-2026-10-12.json`,
`.local/release-3.0.2-input-fix-artifact.json` and
`.local/release-3.0.2-input-fix-embedded-frontend/manifest.json`.

The project website is published in README and GitHub About; only that README
link was committed/pushed in `8445a60`. Application changes and release
publication remain pending user acceptance.

## Original candidate identity (superseded)

The candidate uses final version 3.0.2 so that the tested executable can be
published unchanged. Final portable compilation passed in 8m 59s.

- File: `release/v3.0.2/music-island.exe`.
- File/product version: 3.0.2; Windows x64, GUI subsystem.
- Size: 143,438,848 bytes; built 12 October 2026, 13:43:42 Moscow.
- SHA-256: `48244c2819da46f253a80a8c6a3f0caadac92a9c1bf867fe99c52fa0ea1c4011`.
- Packet: executable, one-entry `SHA256.txt`, `THIRD_PARTY_NOTICES.md`,
  `RELEASE_NOTES.md` and a short Russian testing README.

The packet matches the native build output. The old root `release/music-island.exe`
was preserved with hash `52ace063eed66ffe6f479c8216eb4b8ffde99b47d63fc02a835f0deb40f9b38c`.
No publication, tag, commit or normal GUI launch was performed.

## Verification

The preceding UI iteration passed 218 frontend tests across 45 files,
production build, lint and import boundaries, Storybook type checking and
static build. Lint reported eight existing warnings in fox/media code.
Live Storybook review covered Russian/English, dark/light, narrow model cards,
language filtering with search, Space/Escape and recovery-button busy state.

Final versioned frontend checks passed: 220 tests across 46 files, production
build, lint/import boundaries (271 source files), Storybook type checking and
static build. Native `cargo check` passed in 3m 05s; the Handy adapter retained
its existing unused-code warnings. Full workspace Rust unit tests passed:
105 Music Island tests and 271 Handy core tests, with zero failures. Four
explicit interactive/consent probes remain ignored. Compilation took 14m 08s.
The fresh root tests include all three Windows click-through checks and both
background-console/IPC checks; the earlier interrupted root test run is resolved.

The production frontend was frozen under `.local/release-3.0.2-input/dist`
before native compilation. Its assets are `index-C6EJpOth.js` and
`index-BEFlvkBH.css`. A local build-config override points Tauri at that
snapshot, preventing another frontend build from replacing it during native
compilation. The input manifest records 428 source/config/asset hashes and
the base commit `470e8e31d9a2b344560156a2b167c78e94d6a23b`.

The first native packaging attempt was rejected before delivery: a Windows
absolute `frontendDist` in the local override was parsed as a URL, producing
an EXE without embedded frontend assets. The missing-assets verification
caught it. The override now uses `../.local/release-3.0.2-input/dist` relative
to `src-tauri`; the rejected packet is archived locally and is not a candidate.
Frontend source and tests are unchanged; corrected native packaging completed
successfully. Extracted HTML, JS and CSS inside the final EXE match the frozen
inputs byte for byte, including version 3.0.2 and the transparent initial HTML.
All 26 inference DLL payloads match the bundle manifest. All 428 frozen input
hashes still match the working tree after compilation.

## Isolated executable checks

The final executable was copied by itself into a clean directory and launched
with `--dictation-runtime-check` using separate temporary AppData profiles.
Both Russian and English Whisper Tiny CPU fixtures produced the expected speech
text. ABI 1, device enumeration, Silero VAD/reset, unloading and all 26 extracted
DLL hashes passed for each profile. No adjacent runtime DLLs, installed Handy,
microphone capture or changes to the user's profile were needed.

Russian recognition took 4053ms for 8.075s of recorded audio; English took
7278ms for 6.035s. These are functional packaging checks, not a performance
comparison. Live microphone capture, GPU inference and streaming models remain
outside this probe.

Local evidence: `.local/release-3.0.2-artifact.json`,
`.local/release-3.0.2-embedded-frontend/manifest.json`,
`.local/release-3.0.2-qa/probes.json` and `.local/release-3.0.2-*.log`.
No build or test process remains running. User Windows acceptance is pending.

## Windows acceptance checks

- Cold start and first hover: verify no white flash. Repeat after sleep/wake.
- Hold-to-dictate: verify no Stop/Cancel button in Classic, Waves and Fox.
- Toggle dictation: verify one Finish button, transcription and insertion;
  check Escape after a very short recording and changing/resetting shortcuts.
- Theme switching: verify preview motion, White, Waves blur and Fox ears.
- Models: verify English/Russian filters, search, language recommendations,
  download progress and the selected model remaining accessible.
- Direct Yandex Music: verify the unavailable notice and consented restart.
- Verify tray exit/relaunch, media controls and preservation of existing settings.

Browser previews cannot verify Windows hit-testing, hardware composition,
microphone capture, global shortcuts or insertion into another application.

## Attribution

The project maintainer confirmed on 12 October 2026 that the No Type author
has given permission for reuse and publication of the adapted material in
Music Island under GPL. Attribution and scope are recorded in
`THIRD_PARTY_NOTICES.md`.
