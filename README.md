# Fluister

A macOS menu bar dictation app powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp). Press a hotkey, speak, release, and the transcript is automatically copied to your clipboard. Fully offline after a one-time model download.

> **Fluister** (Dutch) — *to whisper*

## Features

- **Hold-to-talk** — Hold the hotkey to record, release to transcribe
- **Fully offline** — Runs locally using whisper.cpp with Metal GPU acceleration
- **Zero friction** — Transcript is automatically copied to your clipboard
- **Menu bar app** — Lives in the menu bar, no dock icon, no windows to manage
- **Multi-language** — Supports English, Dutch, and auto-detection
- **Long dictation** — Records up to 10 minutes with automatic chunked transcription
- **Customizable** — Rebindable hotkey, model selection (fast vs. balanced), language preference

## Quick Start

### Prerequisites

- macOS 14.0+ (Sonoma or later)
- Xcode 16+ with Command Line Tools

### Build & Run

```bash
# 1. Build whisper.cpp (one-time, ~1 min)
scripts/build_whisper.sh

# 2. Build and launch the app
make run
```

### First Launch

1. The app appears as a waveform icon in the menu bar
2. Click the icon and select **"Download Model (Recommended)"** to download the speech model (~142–466 MB depending on model)
3. Grant **microphone permission** when prompted
4. Hold **Control+Option+Space** to record, release to transcribe
5. **Cmd+V** to paste the transcript anywhere

## Usage

| Action | How |
|---|---|
| Record | Hold **Control+Option+Space** |
| Cancel | Press **Escape** while recording or transcribing |
| Paste | **Cmd+V** anywhere after the "Copied" toast |
| Change language | Menu bar icon → Language → English / Dutch / Auto |
| Change model | Menu bar icon → Model → Fast / Balanced |
| Rebind hotkey | Menu bar icon → Set Hotkey… |
| View logs | Menu bar icon → Open Logs |

### Models

| Profile | Model | Size | Speed | Accuracy |
|---|---|---|---|---|
| **Fast** | `ggml-base` | ~142 MB | Faster | Good for short dictation |
| **Balanced** | `ggml-small` | ~466 MB | Slower | Better for longer or multilingual dictation |

Models are downloaded from [HuggingFace](https://huggingface.co/ggerganov/whisper.cpp) on first use. After download, the app works entirely offline.

### Manual Model Download

If the in-app download doesn't work, you can download manually:

```bash
# Create models directory
mkdir -p .local/models

# Fast model (~142 MB)
curl -L -o .local/models/ggml-base.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin

# Balanced model (~466 MB)
curl -L -o .local/models/ggml-small.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin
```

## Development

```bash
make build          # Build the app
make run            # Build + launch
make test           # Run unit tests
make clean          # Clean build artifacts
make build-verbose  # Full xcodebuild output for debugging
```

The app automatically detects when running from the repo and uses local paths (`.local/`) for models, logs, and preferences — keeping development artifacts inside the repo.

You can also explicitly set dev mode via environment variables:

```bash
export WHISPERFLOW_DEV_MODE=1
export WHISPERFLOW_REPO_ROOT=/path/to/repo   # optional override
```

### Scripts

| Script | Purpose |
|---|---|
| `scripts/build_whisper.sh` | Build the vendored whisper.cpp binary |
| `scripts/healthcheck.sh` | Verify the built app exists |
| `scripts/smoke.sh` | Launch and check the app process |
| `scripts/acceptance.sh` | Run unit tests, exit 0 only if all pass |

## Architecture

```
┌─────────────────────────────────────┐
│          macOS Menu Bar             │
│       (SwiftUI MenuBarExtra)        │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│           AppDelegate               │
│  Coordinates all managers           │
└──┬────────┬────────┬────────┬───────┘
   │        │        │        │
   ▼        ▼        ▼        ▼
Hotkey   Audio   Transcr.  Pill UI
 Mgr    Recorder  Engine  (NSPanel)
                    │
                    ▼
              whisper-cli
              (subprocess)
```

### Tech Stack

- **Language:** Swift 5 / SwiftUI + AppKit
- **Transcription:** whisper.cpp v1.5.5 (vendored, Metal GPU acceleration)
- **Audio:** AVFoundation (16kHz mono WAV)
- **Hotkeys:** Carbon RegisterEventHotKey
- **Pill UI:** NSPanel (non-activating, floating, no focus stealing)
- **Storage:** JSON files for preferences and transcript history

### How Transcription Works

1. Audio is recorded as a 16kHz mono WAV file
2. For recordings >60s, the audio is split into 30s chunks with 2s overlap
3. Each chunk is transcribed by the vendored `whisper-cli` binary (subprocess)
4. Chunk transcripts are concatenated and copied to the clipboard

## Project Structure

```
Fluister/
├── WhisperFlow/Sources/
│   ├── App/              # Entry point, app delegate, menu bar, model config
│   ├── Audio/            # Recording and WAV chunking
│   ├── Transcription/    # whisper-cli invocation, output parsing, formatting
│   ├── Hotkey/           # Global hotkey registration (Carbon API)
│   ├── UI/               # Floating pill window and waveform animation
│   ├── Storage/          # Path management, preferences, transcript history
│   ├── Network/          # Model download with progress
│   └── Logging/          # File-based logging
├── WhisperFlowTests/     # Unit tests
├── vendor/whisper.cpp/   # Vendored whisper.cpp v1.5.5
├── scripts/              # Build, health check, smoke test, acceptance scripts
├── docs/                 # Specification, architecture, decisions, and more
├── Makefile              # Build targets
└── Fluister.xcodeproj    # Xcode project
```

## Documentation

| Document | Description |
|---|---|
| [SPEC.md](docs/SPEC.md) | Full product specification |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design and module responsibilities |
| [PLAN.md](docs/PLAN.md) | Build plan and milestones |
| [COMMANDS.md](docs/COMMANDS.md) | Exact build/run/test commands |
| [DECISIONS.md](docs/DECISIONS.md) | Architecture decision records |
| [STATE.md](docs/STATE.md) | Current project state |
| [TESTING.md](docs/TESTING.md) | Testing strategy |
| [RELEASE.md](docs/RELEASE.md) | Release notes and deferred items |

## Troubleshooting

### "No model downloaded"
Download a model via the menu bar, or manually:
```bash
mkdir -p .local/models
curl -L -o .local/models/ggml-base.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
```

### Microphone permission denied
Go to **System Settings → Privacy & Security → Microphone** and enable access for Fluister.

### Hotkey not working
Another app may have registered the same shortcut. Use **Menu bar icon → Set Hotkey…** to rebind to a different key combination.

### Build fails
Make sure whisper.cpp is built first:
```bash
scripts/build_whisper.sh
make clean
make build-verbose
```
