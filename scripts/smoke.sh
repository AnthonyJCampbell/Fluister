#!/bin/bash
# Smoke test: launches app and checks process is running
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_PATH="$REPO_ROOT/build/Build/Products/Debug/Fluister.app"

if [ ! -d "$APP_PATH" ]; then
    echo "FAIL: App not built. Run 'make build' first."
    exit 1
fi

echo "Launching app..."
WHISPERFLOW_DEV_MODE=1 open "$APP_PATH" &
sleep 3

if pgrep -f "Fluister" > /dev/null; then
    echo "PASS: Fluister process is running"
    # Clean up
    pkill -f "Fluister" 2>/dev/null || true
    exit 0
else
    echo "FAIL: Fluister process not found after launch"
    exit 1
fi
