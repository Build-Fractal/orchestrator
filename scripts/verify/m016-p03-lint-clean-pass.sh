#!/usr/bin/env bash
# m016-p03-lint-clean-pass.sh — Verify full-scan linter passes on the codebase
# Bash 3.2 compatible. Standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

# Run linter in full-scan mode (no args)
_output="$(bash "$LINTER" 2>&1)"
_exit_code=$?

if [ "$_exit_code" -ne 0 ]; then
  echo "FAIL: full-scan linter did not pass"
  echo "$_output"
  exit 1
fi

case "$_output" in
  *"LINT PASS"*)
    echo "PASS: full-scan linter reports LINT PASS"
    exit 0
    ;;
  *)
    echo "FAIL: linter output does not contain LINT PASS"
    echo "$_output"
    exit 1
    ;;
esac
