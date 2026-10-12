# Production code review and build size audit

What this change does: Music Island is a portable Windows media controller with local dictation and microphone processing. This review covers the current production entry points, their connected code, dependencies, embedded files, and build scripts. The expected load is one desktop user, with several WebViews and audio workers in one app process.

Review method: [Ponytail Review](https://github.com/DietrichGebert/ponytail/blob/9b58c1ffb790c075ca32e70a89cf1d80588f4abf/skills/ponytail-review/SKILL.md), pinned to commit `9b58c1ffb790c075ca32e70a89cf1d80588f4abf`. Findings below were recorded before production edits. The user already authorized fixing confirmed findings.

## Must fix

1. **Voice accepts a damaged DLL** (`src-tauri/src/voice/assets.rs:40`).
   - **What this is:** The app extracts its noise removal library to AppData.
   - **Problem:** A damaged file with the right length is accepted. Unlike dictation, this path also follows Windows folder links and falls back to the current directory if AppData is missing.
   - **Fix:** Reuse verified extraction: compare SHA-256, reject redirected paths, and publish completed files with an atomic rename. Require AppData.
   - **If we skip it:** Better Voice can keep loading a damaged library after an interrupted write, or write outside its owned data folder.

2. **Saving settings can lose the whole file** (`src-tauri/src/config/mod.rs:277`).
   - **What this is:** Every settings change saves a complete JSON file.
   - **Problem:** The writer truncates the existing file before the new content is complete. Concurrent saves also write outside the state lock, so the disk and the in-memory snapshot can disagree.
   - **Fix:** Hold the write lock through the save. Flush a unique temporary file and atomically replace the old file before changing memory.
   - **If we skip it:** A power failure can reset preferences on the next launch. Two overlapping saves can leave the UI showing settings different from those on disk.

3. **A late initial read replaces newer settings** (`src/app/config/useAppConfig.ts:49`).
   - **What this is:** A WebView reads settings and subscribes to changes at startup.
   - **Problem:** A change event can arrive while the initial read is pending. The older read then overwrites that event. The dictation overlay already guards this exact case.
   - **Fix:** Subscribe before reading and ignore the initial response if a newer change has arrived. Keep cleanup and error recovery.
   - **If we skip it:** An opening window can show an old theme or old preferences until another change arrives.

4. **Fox transitions can wait forever** (`src/features/plugins/voice/VoiceFoxVideoMascot.tsx:67`).
   - **What this is:** Start and Stop finish the current video before changing the pose.
   - **Problem:** Unmount and playback errors leave waits unresolved. Rapid Stop/Start also cancels a chain while the replacement chain returns early: the live pack stays disabled, or wake/to-sleep never hands over to the next pose. Characterization tests reproduce these cases.
   - **Fix:** Cancel waits on unmount and settle media errors. Resume unfinished one-shot clips and restore idle cycle flags after a reversal; finish healthy clips before moving on.
   - **If we skip it:** Reopening settings can accumulate work, and a failed clip can freeze the mascot's state.

5. **An abandoned extraction file blocks dictation** (`src-tauri/crates/handy-core/src/runtime.rs:77`).
   - **What this is:** Runtime libraries are written to temporary files before being installed.
   - **Problem:** Temporary names contain only the process ID. If a write is interrupted and Windows later reuses that ID, `create_new` rejects the leftover file and initialization fails.
   - **Fix:** Use unique temporary names and clean up failed writes. Share this implementation with the other embedded resources.
   - **If we skip it:** A leftover file can prevent dictation from starting even though the embedded DLL is valid.

6. **The bundle can select the wrong native backend build** (`scripts/build-dictation-runtime.mjs:26`).
   - **What this is:** The packager finds the C++ DLLs produced by Cargo.
   - **Problem:** It chooses the directory with the newest Vulkan DLL timestamp. The target contains several build directories; touching an older file can pair that backend with a different adapter build.
   - **Fix:** Use Cargo's `build-script-executed` output for the active `transcribe-cpp-sys` build. The explicit skip-build path must use a recorded successful selection.
   - **If we skip it:** An incremental build can ship an incompatible or stale native backend.

7. **The updater exposes a partly copied executable** (`src-tauri/src/updater/mod.rs:327`).
   - **What this is:** Self-update replaces the running portable EXE.
   - **Problem:** The current EXE is renamed away before the new file is copied to its final name. An interrupted copy leaves that name pointing to an incomplete EXE.
   - **Fix:** First copy, flush, and verify the replacement in the same directory. Only then rename the old EXE and install the completed replacement; restore the old file if installation fails.
   - **If we skip it:** An interrupted update can leave a portable copy that cannot launch without manual recovery.

8. **An old startup reply replaces a newer track or health event** (`src/app/media/useMediaController.ts:93`).
   - **What this is:** The controller reads the initial media and SMTC health while receiving live events.
   - **Problem:** Both initial reads can finish after a newer event and overwrite it. Characterization tests reproduce track B becoming track A again and a degraded status becoming an older healthy status.
   - **Fix:** Subscribe before reading and discard initial results after a valid newer event. Preserve provider and generation checks, and dispose listeners on teardown.
   - **If we skip it:** A starting window can show the wrong track or a misleading connection status until another event arrives.

## Should fix

9. **Large native files are embedded without compression** (`src-tauri/crates/handy-core/build.rs:28`, `src-tauri/src/voice/assets.rs:7`).
   - **What this is:** The EXE contains the complete inference and noise removal libraries.
   - **Problem:** These DLLs take 98,493,808 bytes. A lossless zlib trial takes 37,845,970 bytes for the same files. The current release carries avoidable download weight.
   - **Fix:** Compress during packaging with the existing `flate2` dependency. Store original size and SHA-256; decompress only absent or damaged files, check the result, and drop the buffer after each file.
   - **If we skip it:** Every download includes about 60.6 MB of avoidable payload. Removing CPU variants or Vulkan instead would cut user features.

10. **An unchanged bundle invalidates the Rust build** (`scripts/build-dictation-runtime.mjs:40`).
   - **What this is:** The portable script caches native files under a content hash.
   - **Problem:** It recopies every DLL and rewrites the manifest on every call. Cargo watches that directory, so a cache hit changes timestamps and makes the host compile again.
   - **Fix:** Leave matching bytes untouched. Repair changed or damaged cache files and write generated source only when its content changes.
   - **If we skip it:** A small host change pays for another expensive compilation of the dictation integration.

11. **Dependency declarations still carry unused code** (`src-tauri/crates/handy-core/Cargo.toml`, `src-tauri/crates/handy-core/src/cli.rs`, `package.json`).
    - **What this is:** Music Island embeds Handy as a library and owns its command line and app plugins.
    - **Problem:** The old Handy CLI has no caller in a production entry point. Several declared plugins and type export tools also have no production references. Cargo still resolves and builds direct dependencies even when the final linker drops their code. The JavaScript autostart and log packages have no references in application code, stories or scripts either.
    - **Fix:** Remove the unused CLI, stale standalone entry points, and proven unused dependency declarations. Retain the event type system and all plugins the host actually calls.
    - **If we skip it:** Build time and the dependency graph stay larger than needed; unused CLI flags imply features this executable does not provide.

12. **The Windows host declares unused library output formats** (`src-tauri/Cargo.toml:21`).
    - **What this is:** The portable binary links `music_island_lib` as a Rust library.
    - **Problem:** The manifest also asks for a static C library and a shared library. No shipped entry point or script consumes either format; this project targets Windows desktop only.
    - **Fix:** Keep `rlib`, the format the EXE uses.
    - **If we skip it:** Cargo can produce unused native library outputs. This is a build-work reduction, not a promised EXE size reduction.

Verdict: fix 1–12 first.

Lean: -618 lines possible in obsolete entry and adapter files, plus disconnected handlers.

Not checked: exhaustive proof of every code path, all physical audio/GPU devices, Windows 10, interactive driver installation, and a real published self-update. This is a production build and connected-flow review, not a certification that no bugs remain.

## Baseline measurements

- Accepted input-fix EXE: 143,439,360 bytes (136.79 MiB), SHA-256 `8f906148dd6bbbc7a3678358b0982d4ed5930bd5e1b268d94396dec9865f39a0`.
- Largest raw DLLs: Vulkan 42,394,624 bytes; DeepFilter 24,782,336 bytes; ONNX Runtime 14,148,680 bytes.
- Seven shipped fox videos: 694,558 bytes. The two posters add 329,445 bytes. Re-encoding these small, already transparent VP9 clips is not justified by their share of the EXE.
- Production frontend: about 1.08 MB of JavaScript and 182 KB of CSS before Tauri's own asset compression. The largest code module is React DOM; motion, settings, markdown and shaders are used features.
- Vite's actual output contains the production fox pack and one preview background. It contains no Storybook films, landing-page entry point, tests, source maps, model downloads, or `.local` build tools.
- Local build caches and marketing media are development artifacts. They do not add weight to the portable EXE and are not deleted by this review.

## Fix and verification results

All 12 findings are fixed. Finding 4 includes playback errors, unmount cleanup,
rapid reversals during live/wake/to-sleep, and a clip ending while cancellation
settles. The new tests failed on the old behavior before the fixes.

- Final portable EXE: `release/v3.0.2-optimized/music-island.exe`, version 3.0.2,
  Windows x64 GUI, 76,248,064 bytes (72.72 MiB). The baseline is 143,439,360 bytes
  (136.79 MiB): 67,191,296 bytes saved, **46.84% smaller**.
- SHA-256: `6122d2a5b9e357efd37f9c319cf3c43cd891d13fc014fbb48c013b6271a02cc3`.
- The final EXE contains 52 verified compressed resources: 107,028,593 original
  bytes stored in 40,105,235 packed bytes. All 27 DLLs decompress to the original
  hashes. Vulkan goes from 42,394,624 to 13,206,787 bytes; DeepFilter from
  24,782,336 to 13,077,960; ONNX Runtime from 14,148,680 to 5,236,317. A 5.63 MB
  third-party notice file compresses to 222 KB; it remains included.
- Verified all 376 frozen source/config/resource hashes. Extracted HTML, JS and
  CSS from the EXE and compared their bytes with the final frontend. The old
  accepted input-fix EXE remains unchanged.
- `npm test`: 234 tests pass in 49 files. Production build, lint/boundaries,
  Storybook type check and static build pass. Both normal playback and rapid
  reversals are covered. No fox assets were re-encoded.
- Rust workspace library tests: 110 app tests and 277 Handy tests pass. Four
  existing interactive Windows checks remain ignored. `cargo check --locked`
  and Clippy's correctness check pass. Advisory style warnings remain; this is
  not a claim of a warning-free repository.
- Two build script tests pass. A real bundle cache hit leaves all 27 file
  timestamps unchanged. The final frontend refresh compiled only the host;
  unchanged native dependencies were reused.
- From an EXE-only folder and separate fresh AppData profiles, RU and EN Whisper
  Tiny CPU recognition, ABI 1, device enumeration, Silero VAD, model unloading
  and all 26 inference DLL hashes pass. Vulkan devices are enumerated; GPU
  inference is not exercised.
- A warm-cache run preserves DLL timestamps. A same-length damaged DLL in the
  isolated profile is repaired before loading. DeepFilter loaded from the bytes
  extracted from the final EXE and processed eight silent frames: 480 samples,
  48 kHz, mono, finite normalized output, without opening a microphone.

Extraction keeps the original uncompressed disk files in AppData. The download
is smaller; installed model sizes and DLL sizes are unchanged. There is no
decompression on a verified cache hit. Cold dictation initialization took about
1.7–1.9 seconds in these acceptance runs; these are functional checks, not a
controlled speed comparison.

Unused cleanup removes four old entry/adapter files (618 lines), disconnected
Handy host settings handlers, unused dependency declarations and unused host
library output formats. Storybook, marketing films and landing sources remain
development assets and do not enter the portable build. CPU/GPU backends,
recognition engines, audio calibration, notices and existing preferences remain.

Evidence is retained under `.local/optimization-baseline/`,
`.local/release-3.0.2-optimized-final-input/`,
`.local/release-3.0.2-optimized-embedded-frontend/`,
`.local/release-3.0.2-optimized-artifact.json` and
`.local/release-3.0.2-optimized-qa/`. No release was published. The candidate
packet includes checksums, notices and release notes and needs the user's final
GUI check before publication.

Verdict: Ship.

Lean: -618 lines removed from obsolete files, plus disconnected handlers and
duplicate extraction code replaced by a shared implementation.

Not checked: live microphone/device routing, GPU inference, Windows 10,
interactive driver installation, and a published self-update. Normal GUI and
hit-testing need a smoke test of the new candidate; the user accepted those
behaviors in the preserved input-fix build.
