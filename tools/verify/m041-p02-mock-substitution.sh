#!/usr/bin/env bash
# tools/verify/m041-p02-mock-substitution.sh -- Verify search-issues.sh
# reads from GH_MOCK_DIR when set (proving mock substitution works).
#
# Bash 3.2 compatible.
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
export GH_MOCK_DIR="$PROJECT_ROOT/tests/fixtures/detective/gh-mock"

output="$(bash "$PROJECT_ROOT/scripts/diagnostics/search-issues.sh" \
  --query "test" 2>/dev/null)"
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "FAIL: search-issues.sh exited $rc (expected 0)"
  exit 1
fi

# Verify output is valid JSON array shape (contains [ and ])
case "$output" in
  *"["*) : ;;
  *) echo "FAIL: output missing '[' (not a JSON array)"; exit 1 ;;
esac
case "$output" in
  *"]"*) : ;;
  *) echo "FAIL: output missing ']' (not a JSON array)"; exit 1 ;;
esac

# Verify output contains "number" (proves mock data was read)
case "$output" in
  *'"number"'*) : ;;
  *) echo "FAIL: output missing '\"number\"' (mock data not read)"; exit 1 ;;
esac

echo "PASS: search-issues.sh reads from GH_MOCK_DIR when set"
