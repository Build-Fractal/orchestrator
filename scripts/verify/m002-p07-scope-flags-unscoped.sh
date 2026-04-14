#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/check-scope.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'scope_tag' "$f" || { echo "FAIL: does not extract scope tag from index"; exit 1; }
grep -q 'WARNING.*no scope tag\|WARNING.*unscoped\|WARNING.*ALL dispatches' "$f" || { echo "FAIL: missing warning for unscoped entries"; exit 1; }
grep -q 'index-utils.sh' "$f" || { echo "FAIL: does not source index-utils.sh"; exit 1; }
echo "PASS: check-scope.sh flags entries with no scope tags"
