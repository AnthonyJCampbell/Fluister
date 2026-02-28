# COMMANDS.md — Exact Build/Run/Test Commands

## Prerequisites
- Xcode 16+ with Command Line Tools
- No other global tools required

## One-Time Setup
```bash
# Build whisper.cpp (clones + builds, ~2 min first time)
scripts/build_whisper.sh
```

## Daily Commands

### Build app
```bash
make build
```
Runs `xcodebuild` to produce WhisperFlow.app in build/.

### Run app (DEV_MODE)
```bash
make run
```
Builds + launches the app with `WHISPERFLOW_DEV_MODE=1`. All data stays in `.local/` inside repo.

### Run tests
```bash
make test
```
Runs `xcodebuild test` on the unit test target.

### Lint
```bash
make lint
```
Exit 0 (no-op; no Swift linter configured in v1).

### Format
```bash
make format
```
Exit 0 (no-op; no Swift formatter configured in v1).

## Scripts

### Health check
```bash
scripts/healthcheck.sh
```
Verifies the built .app bundle exists. Exit 0 = pass.

### Smoke test
```bash
scripts/smoke.sh
```
Launches app, checks process is running after 3s, then kills it. Exit 0 = pass.

### Acceptance tests
```bash
scripts/acceptance.sh
```
Runs `make test`. Exit 0 only if all unit tests pass.

### Build whisper.cpp
```bash
scripts/build_whisper.sh
```
Builds whisper.cpp via Makefile inside vendor/whisper.cpp/. Places binary at `vendor/whisper.cpp/build/bin/whisper-cli`. Idempotent.
