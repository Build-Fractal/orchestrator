#!/usr/bin/env bash
# m016-p03-lint-bash32.sh — Verify anti-pattern-lint.sh passes bash -n syntax check
# Bash 3.2 compatible. Standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

if [ ! -f "$LINTER" ]; then
  echo "FAIL: anti-pattern-lint.sh not found"
  exit 1
fi

# bash -n performs a syntax check without execution
if bash -n "$LINTER" 2>/dev/null; then
  echo "PASS: anti-pattern-lint.sh passes bash -n syntax check"
  exit 0
else
  echo "FAIL: anti-pattern-lint.sh has syntax errors"
  bash -n "$LINTER"
  exit 1
fi
