#!/bin/bash
# Acceptance: runs unit tests, exits 0 only if they pass
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"
echo "Running unit tests..."
make test

echo "PASS: All acceptance tests passed"
