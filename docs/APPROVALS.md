# APPROVALS.md — Commands Requiring Manual Approval

## Actions That Touch Network / Global State / Outside Repo

### 1. Git clone whisper.cpp into vendor/
- **Exact command:** `git clone --depth 1 --branch <tag> https://github.com/ggerganov/whisper.cpp.git vendor/whisper.cpp`
- **Why needed:** Spec requires vendoring whisper.cpp source to build the transcription CLI binary.
- **What it changes:** Downloads ~60MB of source code into vendor/whisper.cpp/ (inside repo). Network access required once.
- **Safer alternative:** User could manually download and place source. But git clone is standard and confined to repo.
- **Status:** APPROVED (network fetch into repo sandbox; no system changes)

### 2. Model file download at runtime (user-initiated)
- **Exact command:** HTTP GET from HuggingFace URLs (e.g., `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin`)
- **Why needed:** whisper.cpp requires model files to transcribe. Spec requires in-app download UI.
- **What it changes:** Downloads model files (~500MB-1.5GB) into .local/models/ (DEV_MODE) or ~/Library/Application Support/WhisperFlow/models/ (production).
- **Safer alternative:** User could manually download and place model files. App will detect them.
- **Status:** User-initiated only (triggered from app menu, never automatic)

### 3. Microphone access (runtime permission)
- **Exact command:** AVCaptureDevice.requestAccess(for: .audio) — macOS system prompt
- **Why needed:** Core functionality requires recording audio.
- **What it changes:** Grants app microphone permission via macOS system dialog.
- **Safer alternative:** None — microphone access is essential. macOS enforces user consent via system dialog.
- **Status:** OS-managed consent flow

## Actions NOT Required
- No brew installs
- No global pip/npm installs
- No sudo commands
- No system file modifications
- No cmake install (using Makefile build)
- No writes outside repo during development (DEV_MODE)
