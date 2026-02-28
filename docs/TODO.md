# TODO.md — Ranked Task List

## Phase 0 — Skeleton
- [ ] Create Xcode project structure (Swift Package or xcodeproj)
- [ ] Implement minimal AppDelegate with .accessory activation policy
- [ ] Add SwiftUI MenuBarExtra with Quit
- [ ] Create Makefile with build/run targets
- [ ] Verify app launches as menu bar icon

## Phase 1 — Quality Rails
- [ ] Add unit test target
- [ ] Create make test / make lint / make format
- [ ] Create scripts/healthcheck.sh
- [ ] Create scripts/smoke.sh
- [ ] Create scripts/acceptance.sh
- [ ] Add first passing placeholder test
- [ ] Write docs/COMMANDS.md

## Phase 2 — Vendor whisper.cpp
- [ ] Clone/vendor whisper.cpp at specific commit
- [ ] Create scripts/build_whisper.sh (Makefile-based, no cmake)
- [ ] Build and verify whisper-cli binary works
- [ ] Test with a generated WAV file

## Phase 3 — Core Journey 1
- [ ] Implement PathManager (DEV_MODE + production paths)
- [ ] Implement PreferencesManager (JSON read/write)
- [ ] Implement HotkeyManager (Carbon RegisterEventHotKey)
- [ ] Implement AudioRecorder (AVFoundation → WAV)
- [ ] Implement PillWindow (NSPanel, non-activating)
- [ ] Implement PillView (SwiftUI: recording/transcribing/success/error states)
- [ ] Implement WaveformView (animated fake bars)
- [ ] Implement WhisperOutputParser (parse stdout)
- [ ] Implement TranscriptionEngine (subprocess invocation)
- [ ] Wire full flow: hotkey → record → transcribe → clipboard → toast
- [ ] Unit tests: PreferencesManager, WhisperOutputParser

## Phase 4 — Cancel + Long Dictation
- [ ] ESC cancellation (recording + transcription)
- [ ] Implement AudioChunker (AVAudioFile WAV splitting)
- [ ] Chunked transcription in TranscriptionEngine
- [ ] 10-min cap with 9:30 warning
- [ ] Chunk progress UI (Chunk i/N)
- [ ] Unit tests: AudioChunker boundaries, overlap, concatenation

## Phase 5 — Language + Model Download
- [ ] Language menu (en/nl/auto) with persistence
- [ ] ModelSources.swift constants
- [ ] ModelDownloader with progress + cancel
- [ ] SHA256 verification
- [ ] "Download Model" menu item with conditional visibility
- [ ] ModelManager: existence check, path resolution

## Phase 6 — Hotkey Rebind + Polish
- [ ] HotkeyCapture panel (captures next key combo)
- [ ] Recent transcripts submenu
- [ ] TranscriptHistory persistence
- [ ] Logger implementation
- [ ] "Open Logs" menu item
- [ ] Error handling review and hardening

## Phase 7 — Handoff
- [ ] Final README.md
- [ ] Update all docs
- [ ] Verify fresh-clone workflow
- [ ] docs/RELEASE.md finalized
