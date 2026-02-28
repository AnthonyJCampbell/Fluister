# STATE.md — Current Project State

## Status: BUILD COMPLETE — All core features implemented

## What exists
- Full Swift macOS menu bar app (WhisperFlow)
- 17 Swift source files across 8 modules (App, Audio, Transcription, Hotkey, UI, Storage, Network, Logging)
- 3 test files with 26 passing unit tests
- whisper.cpp v1.5.5 vendored and built (arm64, Metal acceleration)
- Xcode project generated, builds via `make build`
- Makefile with build/run/test/lint/format targets
- Scripts: healthcheck, smoke, acceptance, build_whisper
- Full docs suite (13 docs)

## What works
- `make build` — compiles WhisperFlow.app (BUILD SUCCEEDED)
- `make test` — 26 tests pass (0 failures)
- `make lint` / `make format` — exit 0
- `scripts/healthcheck.sh` — PASS
- `scripts/acceptance.sh` — PASS
- `scripts/build_whisper.sh` — builds whisper-cli binary
- App launches as menu bar icon (no dock icon)
- Menu bar menu with: Model, Language, Set Hotkey, Recent, Open Logs, Quit
- DEV_MODE auto-detected from build directory location
- PathManager correctly resolves repo root from app bundle path
- Carbon global hotkey registration (Control+Option+Space)
- AVFoundation audio recording to 16kHz mono WAV
- whisper-cli subprocess invocation + stdout parsing
- Audio chunking for recordings >60s (30s chunks, 2s overlap)
- Clipboard copy + success toast via pill UI
- ESC cancellation of recording/transcription
- 10-minute hard cap with 9:30 warning
- Language selection (English/Dutch/Auto) with persistence
- Model download with progress from HuggingFace
- SHA256 verification on downloaded models
- JSON preferences persistence
- Transcript history (last 10)
- Floating pill NSPanel (non-activating, near cursor)
- Pill states: Recording (waveform), Transcribing (spinner + chunk progress), Success, Error
- Logging to file

## What's broken / limitations
- Model SHA256 hashes not pinned (empty strings) — downloads work but no integrity check
- Hotkey rebind is placeholder (shows info dialog, doesn't capture new combo)
- `open` command doesn't pass env vars — DEV_MODE detected from bundle path instead
- Launch at login not implemented (noted in RELEASE.md as deferred)

## Key commands
```
make build              # Build the app
make run                # Build + launch
make test               # Run 26 unit tests
scripts/build_whisper.sh  # Build whisper.cpp (one-time)
scripts/healthcheck.sh   # Verify app bundle exists
scripts/acceptance.sh    # Run tests, exit 0 if all pass
```
