#!/bin/bash
# Healthcheck: verifies built app exists
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_PATH="$REPO_ROOT/build/Build/Products/Debug/Fluister.app"

if [ -d "$APP_PATH" ]; then
    echo "PASS: App bundle exists at $APP_PATH"
    exit 0
else
    echo "FAIL: App bundle not found at $APP_PATH"
    echo "Run 'make build' first."
    exit 1
fi
