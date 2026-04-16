#!/usr/bin/env bash
set -euo pipefail
# Verify run-suite.sh passes bash -n (syntax check) for Bash 3.2 compatibility
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/scripts/verify/run-suite.sh"

if ! [ -f "$TARGET" ]; then
  echo "FAIL: run-suite.sh not found"
  exit 1
fi

if bash -n "$TARGET" 2>/dev/null; then
  echo "PASS: run-suite.sh passes bash -n syntax check"
  exit 0
fi

echo "FAIL: run-suite.sh has syntax errors"
bash -n "$TARGET"
exit 1
