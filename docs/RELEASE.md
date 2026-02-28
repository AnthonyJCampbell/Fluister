# RELEASE.md — Shipped vs Deferred

## Shipped (v1)
- Menu bar app (no dock icon) with SwiftUI menu
- Hold-to-talk via global hotkey (Control+Option+Space)
- Floating pill UI near cursor (NSPanel, non-activating)
- Pill states: Recording (waveform + timer), Transcribing (spinner + chunk progress), Success ("Copied"), Error
- ESC cancellation of recording and transcription
- Audio recording via AVFoundation (16kHz mono WAV)
- whisper.cpp v1.5.5 vendored + built locally (Metal acceleration on Apple Silicon)
- Single-file and chunked transcription (>60s splits into 30s chunks with 2s overlap)
- 10-minute hard cap with 9:30 warning
- Per-chunk timeout (60s) and overall timeout (15min)
- Clipboard auto-copy on success
- Language selection: English / Dutch / Auto (persisted)
- Model profiles: Fast (small) / Balanced (medium)
- Model download from HuggingFace with progress + cancellation
- JSON preferences persistence
- Transcript history (last 10, click to re-copy)
- DEV_MODE auto-detection (repo-local paths for development)
- Logging to file + "Open Logs" menu item
- 26 unit tests (parser, chunker, preferences)
- Makefile with build/run/test/lint/format
- Scripts: healthcheck, smoke, acceptance, build_whisper
- Full documentation suite

## Deferred
- **Hotkey rebind capture** — Set Hotkey menu item exists but shows placeholder dialog instead of live key capture
- **Model SHA256 pinning** — download URLs work but SHA256 hashes are empty strings (no integrity verification). User should update `ModelSources.swift` after first successful download
- **Launch at login** — not implemented
- Notarization / signing / DMG packaging
- Silence-to-stop mode
- Accurate/Large model profile
- Advanced preferences window
- Clipboard restore/history
- Multi-speaker diarization
- Cloud fallback
- Advanced mic device picker
