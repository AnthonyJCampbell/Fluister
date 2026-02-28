# PLAN.md — WhisperFlow Clone Build Plan

## Environment (verified)
- macOS 14.5 (Sonoma), Apple Silicon (arm64)
- Xcode 16.2, Swift 6.0.3, Apple Clang 16
- GNU Make 3.81, git, curl, shasum available
- **cmake NOT installed** — whisper.cpp must be built via Makefile only
- Empty project directory — fresh start

## Architecture Summary
Swift/SwiftUI menu bar app with AppKit NSPanel for pill overlay. whisper.cpp vendored and built as CLI binary, invoked as subprocess. JSON file for preferences. See ARCHITECTURE.md for details.

## Build Strategy

### Phase 0 — Skeleton & Vertical Slice (target: app launches as menu bar item)
1. Create Xcode project structure via Swift Package Manager or xcodebuild-compatible layout
2. Implement minimal AppDelegate with NSApplication.ActivationPolicy.accessory (no dock icon)
3. Add SwiftUI menu bar extra with Quit item
4. Makefile with `make build` and `make run`
5. Verify: app launches, shows menu bar icon, Quit works

**Decision: Project structure approach**
- Use an Xcode project generated via `xcodebuild` compatible structure
- Swift Package Manager for the app target with AppKit lifecycle
- The app is a macOS app bundle (not a plain CLI)

### Phase 1 — Quality Rails
1. Add unit test target
2. Create `make test`, `make lint`, `make format` (lint/format as no-op initially)
3. Create scripts/healthcheck.sh, scripts/smoke.sh, scripts/acceptance.sh
4. First test: placeholder passing test
5. docs/COMMANDS.md with exact commands

### Phase 2 — Vendor whisper.cpp
1. Git clone whisper.cpp into vendor/whisper.cpp/ (specific commit/tag)
2. Create scripts/build_whisper.sh — Makefile-based build
3. Verify whisper-cli binary produced at pinned path
4. Test invocation with a dummy WAV

### Phase 3 — Core Journey 1 (Hold-to-Talk → Copy)
1. Implement DEV_MODE path strategy (PathManager)
2. Implement preferences JSON persistence
3. Implement Carbon global hotkey registration
4. Implement AVFoundation audio recording to WAV
5. Implement NSPanel pill window (non-activating)
6. Implement whisper-cli subprocess invocation + stdout parsing
7. Implement clipboard copy + toast
8. Wire it all together: hotkey → record → transcribe → copy
9. Unit tests for: preferences, stdout parser, chunking logic

### Phase 4 — Journey 2 (Cancel) & Journey 3 (Long Dictation)
1. ESC to cancel recording/transcription
2. WAV chunking in Swift (AVAudioFile + AVAudioPCMBuffer)
3. Chunked transcription with progress UI (Chunk i/N)
4. 10-minute hard cap, 9:30 warning
5. Unit tests for chunking boundaries and overlap

### Phase 5 — Journey 4 (Language) & Journey 5 (Model Download)
1. Language menu (English/Dutch/Auto) with persistence
2. ModelSources.swift constants file
3. Model download with progress, cancellation, SHA256 verification
4. "Download Model (Recommended)" menu item

### Phase 6 — Journey 6 (Rebind Hotkey) & Polish
1. Hotkey rebind panel
2. Recent transcripts submenu
3. Open Logs menu item
4. Logging system
5. Error handling hardening

### Phase 7 — Handoff
1. Final README.md
2. All docs up to date
3. `make run` / `make test` / `make lint` all work from fresh clone
4. docs/RELEASE.md with shipped vs deferred

## Milestones
| # | Milestone | Validates |
|---|-----------|-----------|
| M0 | App launches as menu bar icon, Quit works | Build pipeline, no-dock |
| M1 | Tests pass, scripts exit 0 | Quality rails |
| M2 | whisper-cli builds and runs in repo | Vendor strategy |
| M3 | Hold-to-talk records + transcribes + copies | Core UX |
| M4 | ESC cancels, long recordings chunk correctly | Robustness |
| M5 | Language selection + model download works | Completeness |
| M6 | Hotkey rebind + logging + polish | Ship quality |

## Key Risks (see RISKS.md)
- whisper.cpp Makefile build may need adjustments for arm64/no-cmake
- Carbon hotkey API is deprecated but still functional
- Audio permission flow on first launch
- Model URLs may change upstream
