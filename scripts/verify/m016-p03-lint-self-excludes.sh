#!/usr/bin/env bash
# m016-p03-lint-self-excludes.sh — Verify linter self-excludes its own source
# Bash 3.2 compatible. Standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

# Run linter on itself — should pass (self-exclusion)
_output="$(bash "$LINTER" --fixture "$LINTER" 2>&1)"
_exit_code=$?

if [ "$_exit_code" -eq 0 ]; then
  echo "PASS: linter self-excludes its own source"
  exit 0
else
  echo "FAIL: linter flagged itself (expected self-exclusion)"
  echo "$_output"
  exit 1
fi
