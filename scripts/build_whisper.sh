#!/bin/bash
# Build whisper.cpp from vendored source (Makefile-based, no cmake)
# Idempotent: safe to re-run
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WHISPER_DIR="$REPO_ROOT/vendor/whisper.cpp"
TARGET_BIN="$WHISPER_DIR/build/bin/whisper-cli"

if [ ! -d "$WHISPER_DIR" ]; then
    echo "ERROR: whisper.cpp not found at $WHISPER_DIR"
    echo "Please vendor whisper.cpp first."
    exit 1
fi

# Skip rebuild if binary already exists and is executable
if [ -x "$TARGET_BIN" ]; then
    echo "whisper-cli already built: $TARGET_BIN"
    "$TARGET_BIN" --help 2>&1 | head -5 || true
    exit 0
fi

echo "Building whisper.cpp (v1.5.5, Makefile-based, no cmake)..."
make -C "$WHISPER_DIR" main -j$(sysctl -n hw.ncpu) 2>&1

# Normalize binary location
mkdir -p "$WHISPER_DIR/build/bin"
# whisper.cpp Makefile outputs to build/bin/ or main dir depending on version
# Find and copy to pinned path
if [ -f "$TARGET_BIN" ]; then
    echo "whisper-cli already at pinned path: $TARGET_BIN"
elif [ -f "$WHISPER_DIR/main" ]; then
    cp "$WHISPER_DIR/main" "$TARGET_BIN"
    echo "Copied main -> $TARGET_BIN"
elif [ -f "$WHISPER_DIR/whisper-cli" ]; then
    cp "$WHISPER_DIR/whisper-cli" "$TARGET_BIN"
    echo "Copied whisper-cli -> $TARGET_BIN"
else
    echo "ERROR: Could not find whisper-cli binary after build"
    echo "Contents of build directory:"
    ls -la "$WHISPER_DIR/build/" 2>/dev/null || echo "(no build dir)"
    ls -la "$WHISPER_DIR/" | grep -E 'main|whisper'
    exit 1
fi

echo "whisper.cpp built successfully: $TARGET_BIN"
"$TARGET_BIN" --help 2>&1 | head -5 || true
