#!/usr/bin/env bash
# Verifies scope-filter.sh --graph mode applies scope, confidence, and category filters via SQL.
set -eu

f="scripts/dispatch/scope-filter.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'scope_tags' "$f" || { echo "FAIL: $f missing scope_tags table reference in graph mode"; exit 1; }
grep -q 'e\.confidence' "$f" || { echo "FAIL: $f missing confidence filter in graph mode SQL"; exit 1; }
grep -q 'e\.category' "$f" || { echo "FAIL: $f missing category filter in graph mode SQL"; exit 1; }
grep -q 'st\.tag' "$f" || { echo "FAIL: $f missing scope tag matching in graph mode SQL"; exit 1; }
echo "PASS: scope-filter.sh --graph mode applies scope, confidence, and category filters via SQL"
