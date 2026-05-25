#!/usr/bin/env bash
# tools/verify/m041-p02-search-issues-mock.sh -- Verify search-issues.sh
# returns valid JSON with match scores when reading from GH_MOCK_DIR.
#
# Bash 3.2 compatible.
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
export GH_MOCK_DIR="$PROJECT_ROOT/tests/fixtures/detective/gh-mock"

output="$(bash "$PROJECT_ROOT/scripts/diagnostics/search-issues.sh" \
  --query "scaffold exits milestone" 2>/dev/null)"
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "FAIL: search-issues.sh exited $rc (expected 0)"
  exit 1
fi

# Verify output starts with [
first_char="$(printf '%s' "$output" | head -c1)"
if [ "$first_char" != "[" ]; then
  echo "FAIL: output does not start with '[' (got '${first_char}')"
  exit 1
fi

# Verify output contains "number"
case "$output" in
  *'"number"'*) : ;;
  *) echo "FAIL: output missing '\"number\"' field"; exit 1 ;;
esac

# Verify output contains "match_score"
case "$output" in
  *'"match_score"'*) : ;;
  *) echo "FAIL: output missing '\"match_score\"' field"; exit 1 ;;
esac

echo "PASS: search-issues.sh returns valid JSON with match scores from mock"
