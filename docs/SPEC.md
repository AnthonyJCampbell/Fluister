# WhisperFlow Clone (macOS) — SPEC v1.1 (One-Shot Optimized, Safe-by-Default, Offline)

## 0) Execution safety & environment assumptions (added)

### Safety boundary (must)
* The build agent must treat the repo root as a sandbox and must not read/write/delete outside it.
* For development/testing, all generated artifacts (logs/models/temp audio) must be able to live inside the repo under ./.local/ to avoid touching ~/Library/... during one-shot runs.

### Environment assumption (explicit)
* Assume the user has Xcode + Command Line Tools installed (required to build Swift/AppKit).
* Avoid requiring global installs. If a tool is missing and a global install would help (e.g., brew install), record it in docs/APPROVALS.md and proceed with alternatives.

### Runtime dependency policy (clarified)
* No brew runtime deps is preferred but not strict.
* Strong preference: vendor / build locally inside repo.
* If a global tool is needed for development convenience, it must be manual-approval-only, with explanation.

## 1) One-page overview

### What it is
A macOS menu bar dictation app that is always available. When the user triggers a global hotkey:
* a small floating pill appears near the cursor,
* audio is recorded (hold-to-talk by default),
* when recording stops, the app transcribes locally/offline,
* the final transcript is automatically copied to the clipboard,
* a brief toast confirms "Copied".

Primary goal: "Speak → stop → paste anywhere" with near-zero friction.

### Who it's for
Power users dictating short to medium bursts (1s to 10 minutes) into any app.

### Constraints (must)
* Free to use and offline by default (no cloud APIs, no API keys).
* macOS menu bar app (no dock icon by default).
* Minimal setup: after building the repo, the app runs and can self-manage model files.
* Must remain responsive during transcription (no UI hangs).

### Non-goals (explicit)
* No diarization / multi-speaker separation.
* No cloud fallback.
* No long-form beyond 10 minutes.
* No advanced mic device picker UI in v1.
* No notarization/signing/DMG packaging in v1.

## 2) Prescriptive tech choices (do not bikeshed)

### App language/frameworks (required)
* Language: Swift
* UI: SwiftUI for menu + lightweight AppKit for:
   * global hotkeys
   * floating pill window (non-activating NSPanel)
* Audio: AVFoundation
* Persistence: JSON (single file) for v1.

### Dock icon behavior (required)
* App must not show a dock icon by default.
* Implement using activation policy and/or LSUIElement as appropriate.
* If a choice is needed:
   * Prefer setting the activation policy at runtime for dev; record any Info.plist changes in docs/DECISIONS.md.

### Global hotkeys (required)
Use Carbon RegisterEventHotKey (not CGEventTap).
* If registration fails, show a clear error and allow user to rebind hotkey.

### Pill UI (required)
Use an NSPanel configured as a non-activating floating "pill":
* does not steal focus,
* appears near cursor by default (fallback: near menu bar),
* shows simple waveform animation (fake bars OK; no DSP required).

### Transcription engine (required)
Use whisper.cpp as the local transcription backend.
* Vendor whisper.cpp source under: vendor/whisper.cpp/
* Build whisper.cpp locally (inside repo) using system toolchain.

#### Build method (pinned)
* Use whisper.cpp's Makefile build (no cmake requirement).
* Produce a CLI binary at a pinned path:
   * vendor/whisper.cpp/build/bin/whisper-cli (or if whisper.cpp outputs differently, normalize by copying to this path)
* Provide a script scripts/build_whisper.sh that:
   * builds whisper.cpp
   * places the final binary at the pinned path above
   * is idempotent (safe to re-run)

#### Invocation model
* App records audio to temp WAV file(s)
* App runs the vendored whisper-cli binary as a subprocess
* App parses stdout into final text

### Model formats
* Use whisper.cpp compatible GGUF (preferred) or GGML depending on the vendored whisper.cpp version.
* The repo must define one model format in code (do not support both in v1).

## 3) Allowed network usage (clarified)
* Network is allowed only for user-initiated model download from the app menu UI.
* No network calls for transcription.
* The app must be fully usable offline after models exist.

## 4) User journeys (keep tight)

### Journey 1 — Hold-to-talk → auto copy (core)
**Story:** I press and hold a global hotkey, speak, release, and immediately paste the transcript.

**Acceptance criteria:**
* First use requests microphone permission; if denied, show error + "Open System Settings".
* While recording: pill shows "Recording…" + timer + animated waveform.
* On release: recording stops instantly; pill shows "Transcribing…".
* On success: transcript copied to clipboard automatically + toast "Copied".
* On failure: show error; clipboard unchanged.

### Journey 2 — Cancel instantly
**Story:** I can cancel mid-recording or transcription and nothing is copied.

**Acceptance criteria:**
* ESC cancels recording or ongoing transcription.
* Cancelling never changes clipboard.

### Journey 3 — Long dictation up to 10 minutes (reliable)
**Story:** I dictate 2–10 minutes and it still works.

**Acceptance criteria:**
* Hard cap at 10 minutes.
* Show warning at 9:30 and auto-stop at 10:00.
* App remains responsive during transcription.
* Progress UI requirement is chunk-level only:
   * show Chunk i/N (no within-chunk percent required)

**Implementation constraint:**
* For recordings > 60s: MUST use chunked transcription (see below).

### Journey 4 — Language control (simple)
**Story:** I can force English or Dutch.

**Acceptance criteria:**
* Language menu: English / Dutch / Auto.
* Default = English.
* Persist across restarts.

### Journey 5 — One-time model download (minimal friction)
**Story:** If models are missing, the app guides me.

**Acceptance criteria:**
* If model missing: menu item "Download Model (Recommended)" appears.
* Download shows progress; can cancel.
* If download fails: show error and keep app usable (but dictation disabled until model exists).
* Verify SHA256 after download; on mismatch delete file and show error.

### Journey 6 — Rebind hotkey (minimal)
**Story:** If hotkey registration fails or I want to change it, I can rebind.

**Acceptance criteria:**
* Menu item: "Set Hotkey…"
* Selecting it opens a small panel that captures the next key combo.
* Saves preference, attempts register, shows success toast or clear error.

## 5) Chunking & WAV splitting (pinned, no external tools)

### Chunking (required)
If recorded duration > 60 seconds:
* Split into 30s chunks with 2s overlap
* Transcribe each chunk independently
* Concatenate chunk transcripts with a single space
* Per-chunk timeout: 60s
* Overall transcription timeout: 15 minutes (hard stop; error + clipboard unchanged)

No fancy alignment/timestamps in v1.

### WAV splitting method (required; no ffmpeg)
* Implement chunk export in Swift using AVAudioFile + AVAudioPCMBuffer:
   * Load the recorded WAV into an AVAudioFile
   * Write chunk WAV files to a temp directory
   * Ensure deterministic naming: chunk_000.wav, chunk_001.wav, …

### Silence detection
Out of scope for v1.

## 6) Data model (JSON) — safe paths for one-shot

### Dev/testing paths (repo-local; required)
To comply with strict project confinement, the app must support a DEV_MODE path strategy:
* Preferences + models + logs stored under:
   * ./.local/app_support/
   * ./.local/models/
   * ./.local/logs/app.log
* Default behavior:
   * If environment variable WHISPERFLOW_DEV_MODE=1 is set, use repo-local paths.
   * Otherwise, use standard macOS Application Support + Logs directories (below).

### Production paths (macOS standard; required)
* Preferences + models:
   * ~/Library/Application Support/<AppName>/
* Logs:
   * ~/Library/Logs/<AppName>/app.log

### Preferences (same keys)
* hotkey (string)
* model_profile (fast | balanced)
* language (en | nl | auto)
* launch_at_login (bool)
* ui_position (cursor | menu_bar)

### Recent transcripts (optional)
Keep last 10:
* created_at (iso8601)
* text (string)
* duration_ms (int)
* language_used (string)
* model_used (string)
* error (nullable string)

## 7) Key UI surfaces

### Menu bar menu
* Start Dictation (optional; primarily hotkey-driven)
* Download Model (Recommended) (if missing)
* Model: Fast / Balanced
* Language: English / Dutch / Auto
* Set Hotkey…
* Recent (last 10) -> click copies to clipboard (optional)
* Launch at login (toggle) (can be stubbed if time sinks; record in RELEASE.md)
* Open Logs
* Quit

### Pill UI states
* Recording (timer + waveform)
* Transcribing (spinner + Chunk i/N)
* Success ("Copied")
* Error (short message)

## 8) Model assets (pinned; minimal + update-friendly)

### Storage location
* In DEV_MODE: ./.local/models/
* Otherwise: ~/Library/Application Support/<AppName>/models/

### Profiles → filenames (format pinned)
Choose ONE format based on vendored whisper.cpp:
* Preferred: GGUF
   * Fast: gguf-small.bin (example; final name must match the pinned source)
   * Balanced: gguf-medium.bin
OR (if whisper.cpp requires GGML):
   * Fast: ggml-small.bin
   * Balanced: ggml-medium.bin

### Download sources (must be fully pinned)
**Implementation requirement:**
* Create a single constants file, e.g. Sources/App/ModelSources.swift, containing:
   * exact URLs
   * expected filenames
   * expected SHA256
* Verify SHA256 after download; if mismatch, delete file and show error.
* Allow easy updates by editing this one constants file.

**NOTE (explicit):**
If exact model URLs/SHA256 cannot be reliably pinned during the run, the build must still succeed,
and the app must show a UI message prompting the user to set/update model source constants.
(Record this in docs/RELEASE.md as a deferred "pinning completion" step.)

## 9) Logging & diagnostics (required)
* In DEV_MODE: ./.local/logs/app.log
* Otherwise: ~/Library/Logs/<AppName>/app.log
* Menu item "Open Logs" reveals the log file in Finder.
* Log: hotkey register, recording start/stop, model download, transcription start/end, errors, timeouts.

## 10) Build/run/test requirements (Claude-friendly, safe)

### Commands (must be documented in docs/COMMANDS.md)
* Run: make run (build + launch)
* Test: make test
* Lint: make lint (allowed to be no-op exit 0; prefer stable)
* Format: make format (no-op OK; must exit 0)

### Build details (pinned)
* Build using xcodebuild via Makefile targets (no reliance on opening Xcode UI).

### Testing policy (minimal but real; non-brittle)
Unit tests for pure logic only:
* chunking boundaries and overlap
* transcript concatenation normalization
* preference persistence read/write
* parsing whisper.cpp stdout into transcript text (pure parser)

Avoid:
* UI automation tests
* timing-sensitive tests
* network-dependent tests

### Scripts (must exist; repo-only)
* scripts/healthcheck.sh: verifies built app exists
* scripts/smoke.sh: launches app and checks process running (best effort, timeout-protected)
* scripts/acceptance.sh: runs unit tests and exits 0 only if they pass

## 11) Out of scope / deferred (explicit)
* Silence-to-stop mode
* Clipboard restore/history beyond OS clipboard
* Accurate/large model profile
* Advanced preferences window
* Notarization/signing/DMG packaging
* Perfect model URL pinning if upstream sources are unclear (must degrade gracefully with instruction)
