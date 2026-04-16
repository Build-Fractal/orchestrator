#!/usr/bin/env bash
# m016-p03-consolidate-clean.sh — Verify consolidate.md has no state=$(bash ...) pattern
# Bash 3.2 compatible. Standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/commands/consolidate.md"

if [ ! -f "$TARGET" ]; then
  echo "FAIL: commands/consolidate.md not found"
  exit 1
fi

# Check that the anti-pattern is NOT present
if grep -q 'state=\$(bash' "$TARGET"; then
  echo "FAIL: commands/consolidate.md contains state=\$(bash pattern"
  exit 1
else
  echo "PASS: commands/consolidate.md is clean of state=\$(bash pattern"
  exit 0
fi
