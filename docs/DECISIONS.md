# DECISIONS.md — Architecture Decision Records

## ADR-001: Project Structure — Xcode Project
**Decision:** Use an Xcode project (.xcodeproj) created via `xcodebuild` compatible structure.
**Reason:** A macOS app bundle requires Info.plist, entitlements, and proper bundle structure. Swift Package Manager alone cannot produce a sandboxed .app bundle with proper AppKit lifecycle. Using xcodeproj allows `xcodebuild` CLI builds without opening Xcode UI.
**Alternative considered:** SPM executable — rejected because it produces a plain CLI binary, not an .app bundle with proper NSApplication lifecycle, MenuBarExtra, and NSPanel.

## ADR-002: No Dock Icon — Runtime + Info.plist
**Decision:** Set `NSApp.setActivationPolicy(.accessory)` at runtime in AppDelegate AND set LSUIElement=YES in Info.plist.
**Reason:** Both approaches combined for reliability. Info.plist for production, runtime for dev flexibility.

## ADR-003: Global Hotkey — Carbon RegisterEventHotKey
**Decision:** Use Carbon RegisterEventHotKey as specified.
**Reason:** Spec requirement. CGEventTap requires Accessibility permission and is more complex. Carbon hotkeys are deprecated but functional on current macOS and simpler to implement.

## ADR-004: whisper.cpp Build Approach
**Decision:** Build whisper.cpp using its **Makefile** (NOT cmake).
**Pinned binary path:** `vendor/whisper.cpp/build/bin/whisper-cli`
**Build script:** `scripts/build_whisper.sh` — runs `make` in vendor/whisper.cpp/, then normalizes the output binary to the pinned path.
**Reason:** cmake is not installed on the target machine and the spec says no cmake requirement. whisper.cpp supports plain Makefile builds. The build script handles output path normalization since whisper.cpp's Makefile may output to different locations depending on version.
**Pinned version:** Will use a specific release tag (e.g., v1.7.3 or latest stable) for reproducibility.

## ADR-005: Model Format — GGML
**Decision:** Use **GGML** format model files (ggml-small.bin, ggml-medium.bin).
**Reason:** The whisper.cpp project's primary Makefile-based builds and the `main`/`whisper-cli` binary have historically used GGML format. While newer versions support GGUF, GGML has broader compatibility with the Makefile build path and the HuggingFace-hosted pre-converted models at `ggerganov/whisper.cpp`. Using GGML avoids needing model conversion tools.
**Filenames:**
- Fast profile: `ggml-small.bin`
- Balanced profile: `ggml-medium.bin`
**Download source:** HuggingFace `ggerganov/whisper.cpp` repository.
**Note:** If the vendored whisper.cpp version requires GGUF, this decision will be updated and model constants adjusted. The app defines model info in a single `ModelSources.swift` file for easy updates.

## ADR-006: Path Strategy — DEV_MODE with Env Var
**Decision:** Dual path strategy controlled by environment variable `WHISPERFLOW_DEV_MODE`.
**DEV_MODE=1 (development/testing):**
- Preferences: `./.local/app_support/preferences.json`
- Models: `./.local/models/`
- Logs: `./.local/logs/app.log`
- Temp audio: `./.local/tmp/`
All paths are relative to the repo root. No writes outside the repo sandbox.

**DEV_MODE unset (production):**
- Preferences: `~/Library/Application Support/WhisperFlow/preferences.json`
- Models: `~/Library/Application Support/WhisperFlow/models/`
- Logs: `~/Library/Logs/WhisperFlow/app.log`
- Temp audio: System temp directory

**Reason:** Spec requires repo-local paths for development safety. Production paths follow macOS conventions. Single `PathManager` class abstracts this. `make run` sets DEV_MODE=1 by default.

## ADR-007: Audio Format — WAV (Linear PCM)
**Decision:** Record audio as WAV (Linear PCM, 16kHz, mono, 16-bit).
**Reason:** This is whisper.cpp's native input format. Avoids transcoding. AVFoundation supports WAV output directly.
