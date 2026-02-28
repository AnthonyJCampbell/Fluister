# ARCHITECTURE.md — WhisperFlow Clone

## High-Level Architecture

```
┌─────────────────────────────────────────────────┐
│                  macOS Menu Bar                   │
│              (SwiftUI MenuBarExtra)               │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│                   AppDelegate                     │
│  - NSApplication.ActivationPolicy.accessory       │
│  - Carbon global hotkey registration              │
│  - Coordinates all managers                       │
└──┬──────────┬──────────┬──────────┬─────────────┘
   │          │          │          │
   ▼          ▼          ▼          ▼
┌──────┐ ┌────────┐ ┌────────┐ ┌──────────┐
│Hotkey│ │ Audio  │ │Transcr.│ │  Pill UI │
│Mgr   │ │Recorder│ │Engine  │ │ (NSPanel)│
└──────┘ └────────┘ └────────┘ └──────────┘
                        │
                        ▼
              ┌──────────────────┐
              │  whisper-cli     │
              │  (subprocess)    │
              └──────────────────┘
```

## Module Responsibilities

### AppDelegate / App Entry
- Sets activation policy to `.accessory` (no dock icon)
- Creates and owns the SwiftUI menu bar
- Initializes all managers
- Handles app lifecycle

### HotkeyManager
- Registers/unregisters Carbon global hotkeys (RegisterEventHotKey)
- Notifies on key-down (start recording) and key-up (stop recording)
- Handles ESC for cancellation
- Supports rebinding via capture panel

### AudioRecorder
- Uses AVFoundation (AVAudioEngine or AVAudioRecorder) to record to WAV
- Manages microphone permission request
- Enforces 10-minute hard cap with 9:30 warning
- Provides duration timer updates

### TranscriptionEngine
- Determines if chunking is needed (>60s)
- Splits WAV into chunks using AVAudioFile + AVAudioPCMBuffer
- Invokes whisper-cli as Process (subprocess) per chunk
- Parses stdout for transcript text
- Concatenates chunk results
- Enforces per-chunk (60s) and overall (15min) timeouts
- Cancellable

### PillWindow (NSPanel)
- Non-activating, floating, no focus stealing
- States: Recording (timer + waveform), Transcribing (spinner + chunk progress), Success, Error
- Appears near cursor (fallback: near menu bar)
- Fake waveform animation (random bar heights on timer)

### PreferencesManager
- Reads/writes JSON file
- DEV_MODE vs production path selection via PathManager
- Keys: hotkey, model_profile, language, launch_at_login, ui_position

### PathManager
- If WHISPERFLOW_DEV_MODE=1: all paths under ./.local/
- Otherwise: ~/Library/Application Support/WhisperFlow/ and ~/Library/Logs/WhisperFlow/
- Provides: preferencesFile, modelsDirectory, logFile, tempDirectory

### ModelManager
- Checks if required model file exists
- Downloads from pinned URL with progress
- SHA256 verification
- Cancellable downloads

### Logger
- Writes to log file (path from PathManager)
- Logs: hotkey events, recording, transcription, downloads, errors

## Data Flow — Core Journey (Hold-to-Talk)

1. User presses global hotkey → HotkeyManager fires keyDown
2. AppDelegate → AudioRecorder.startRecording() + PillWindow.show(.recording)
3. User releases hotkey → HotkeyManager fires keyUp
4. AppDelegate → AudioRecorder.stopRecording() → returns WAV path
5. AppDelegate → PillWindow.show(.transcribing) → TranscriptionEngine.transcribe(wavPath)
6. TranscriptionEngine → splits if needed → runs whisper-cli subprocess(es) → parses stdout
7. TranscriptionEngine returns transcript text
8. AppDelegate → NSPasteboard.general.setString(text) → PillWindow.show(.success)
9. After delay → PillWindow.hide()

## File Layout

```
WhisperFlow/
├── Sources/
│   └── WhisperFlow/
│       ├── App/
│       │   ├── WhisperFlowApp.swift        # @main, MenuBarExtra
│       │   ├── AppDelegate.swift           # Coordinator
│       │   └── ModelSources.swift          # Pinned URLs + SHA256
│       ├── Audio/
│       │   ├── AudioRecorder.swift
│       │   └── AudioChunker.swift          # WAV splitting
│       ├── Transcription/
│       │   ├── TranscriptionEngine.swift
│       │   └── WhisperOutputParser.swift   # Parse CLI stdout
│       ├── Hotkey/
│       │   └── HotkeyManager.swift         # Carbon API
│       ├── UI/
│       │   ├── PillWindow.swift            # NSPanel
│       │   ├── PillView.swift              # SwiftUI pill content
│       │   ├── WaveformView.swift          # Animated bars
│       │   └── HotkeyCapture.swift         # Rebind panel
│       ├── Storage/
│       │   ├── PathManager.swift
│       │   ├── PreferencesManager.swift
│       │   └── TranscriptHistory.swift
│       ├── Network/
│       │   └── ModelDownloader.swift
│       └── Logging/
│           └── Logger.swift
├── Tests/
│   └── WhisperFlowTests/
│       ├── AudioChunkerTests.swift
│       ├── WhisperOutputParserTests.swift
│       ├── PreferencesManagerTests.swift
│       └── TranscriptionEngineTests.swift
├── vendor/
│   └── whisper.cpp/                        # Git submodule or vendored source
├── scripts/
│   ├── build_whisper.sh
│   ├── healthcheck.sh
│   ├── smoke.sh
│   └── acceptance.sh
├── docs/
├── .local/                                 # DEV_MODE artifacts (gitignored)
├── Makefile
└── README.md
```

## Contracts / Interfaces

### whisper-cli invocation
```
vendor/whisper.cpp/build/bin/whisper-cli -m <model_path> -f <wav_path> -l <lang> --no-timestamps
```
Output: transcript text on stdout, one or more lines.

### Preferences JSON
```json
{
  "hotkey": "Control+Option+Space",
  "model_profile": "fast",
  "language": "en",
  "launch_at_login": false,
  "ui_position": "cursor"
}
```
