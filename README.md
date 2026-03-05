# Fluister

A macOS menu bar dictation app powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp). Press a hotkey, speak, release, and the transcript is automatically pasted at your cursor. Fully offline after a one-time model download.

> **Fluister** (Dutch) — *to whisper*

## Features

- **Hold-to-talk** — Hold the hotkey to record, release to transcribe
- **Fully offline** — Runs locally using whisper.cpp with Metal GPU acceleration
- **Auto-paste** — Transcript is automatically pasted at your cursor position
- **Menu bar app** — Lives in the menu bar, no dock icon, no windows to manage
- **Multi-language** — Supports English, Dutch, and auto-detection
- **Long dictation** — Records up to 10 minutes with automatic chunked transcription
- **Six models** — From Tiny (75 MB) to Turbo (1.6 GB), choose your speed/accuracy tradeoff
- **Live waveform** — Scrolling waveform visualization while recording
- **Clipboard history** — Recent transcriptions and clipboard entries accessible from the menu

## Quick Start

### Prerequisites

- macOS 14.0+ (Sonoma or later)
- Xcode 16+ with Command Line Tools

### Build & Run

```bash
# 1. Clone with submodule
git clone --recursive https://github.com/AnthonyJCampbell/Fluister.git
cd Fluister

# 2. Build whisper.cpp (one-time, ~1 min)
scripts/build_whisper.sh

# 3. Build and launch the app
./dev
```

### First Launch

1. The app appears as a waveform icon in the menu bar
2. Click the icon — the default model (Turbo) will be available for download
3. Grant **microphone permission** when prompted
4. Hold **Control+Space** to record, release to transcribe
5. The transcript is automatically pasted at your cursor

## Usage

| Action | How |
|---|---|
| Record | Hold **Control+Space** |
| Cancel | Press **Escape** while recording or transcribing |
| Change language | Menu bar icon > Language > English / Dutch / Auto |
| Change model | Menu bar icon > Model > select a model |
| Toggle formatting | Menu bar icon > Settings > Text Formatting |
| View logs | Menu bar icon > Settings > Open Logs |

### Models

| Profile | Model | Size | Notes |
|---|---|---|---|
| Tiny | `ggml-tiny.bin` | 75 MB | Fastest, least accurate |
| Base | `ggml-base.bin` | 142 MB | Good for short dictation |
| Small | `ggml-small.bin` | 466 MB | Better multilingual support |
| Medium | `ggml-medium.bin` | 1.5 GB | High accuracy |
| Large | `ggml-large-v3.bin` | 3.1 GB | Highest accuracy |
| **Turbo** | `ggml-large-v3-turbo.bin` | **1.6 GB** | **Default** — best speed/accuracy balance |

Models are downloaded from [HuggingFace](https://huggingface.co/ggerganov/whisper.cpp) on first use. After download, the app works entirely offline.

## Development

```bash
./dev                # Build + launch (recommended)
```

The `./dev` script:
1. Builds via `xcodebuild`
2. Configures dev mode paths (models, logs, preferences stored in `.local/`)
3. Kills any running instance
4. Launches the app with proper macOS permission tracking

You can also build manually:
```bash
xcodebuild -project Fluister.xcodeproj -scheme Fluister -configuration Debug build
```

### Scripts

| Script | Purpose |
|---|---|
| `./dev` | Build and launch for development |
| `scripts/build_whisper.sh` | Build the vendored whisper.cpp binary |
| `scripts/healthcheck.sh` | Verify the built app exists |
| `scripts/smoke.sh` | Launch and check the app process |
| `scripts/acceptance.sh` | Run unit tests |

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
          (subprocess + Metal GPU)
```

### Tech Stack

- **Language:** Swift 5 / SwiftUI + AppKit
- **Transcription:** whisper.cpp (vendored, Metal GPU acceleration)
- **Audio:** AVAudioEngine with per-buffer format conversion (native > 16kHz Int16 mono)
- **Hotkeys:** Carbon RegisterEventHotKey
- **Pill UI:** NSPanel (borderless, non-activating, floating) with scrolling waveform
- **Storage:** JSON files for preferences, transcript history, and clipboard history

### How Transcription Works

1. Audio is recorded via AVAudioEngine in the mic's native format
2. Each buffer is converted in-process to 16kHz mono Int16 WAV via AVAudioConverter
3. For recordings >60s, the audio is split into 30s chunks with 2s overlap
4. Each chunk is transcribed by the vendored `whisper-cli` binary (Metal GPU accelerated)
5. Chunk transcripts are concatenated and auto-pasted at the cursor

## Project Structure

```
Fluister/
├── WhisperFlow/Sources/
│   ├── App/              # Entry point, app delegate, menu bar, model config
│   ├── Audio/            # Recording (AVAudioEngine) and WAV chunking
│   ├── Transcription/    # whisper-cli invocation, output parsing, text formatting
│   ├── Hotkey/           # Global hotkey registration (Carbon API)
│   ├── UI/               # Floating pill window and waveform animation
│   ├── Storage/          # Path management, preferences, transcript/clipboard history
│   ├── Network/          # Model download with progress and SHA256 verification
│   └── Logging/          # File-based logging
├── WhisperFlowTests/     # Unit tests
├── vendor/whisper.cpp/   # Vendored whisper.cpp (git submodule)
├── scripts/              # Build and test scripts
├── docs/                 # Specification and architecture docs
└── Fluister.xcodeproj    # Xcode project
```

## Troubleshooting

### "No model downloaded"
Download a model via the menu bar icon > Model, or manually:
```bash
mkdir -p .local/models
curl -L -o .local/models/ggml-large-v3-turbo.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
```

### Microphone permission denied
Go to **System Settings > Privacy & Security > Microphone** and enable access for Fluister.

### Hotkey not working
Another app may have registered the same shortcut. The default is **Control+Space**.

### Build fails
Make sure whisper.cpp is built first:
```bash
scripts/build_whisper.sh
./dev
```
