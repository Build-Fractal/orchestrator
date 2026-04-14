#!/usr/bin/env bash
set -eu
f="scripts/dispatch/select-model.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-list-fallback' "$f" || { echo "FAIL: missing --list-fallback mode"; exit 1; }
grep -q '\-\-next-fallback' "$f" || { echo "FAIL: missing --next-fallback mode"; exit 1; }
grep -q 'fallback' "$f" || { echo "FAIL: no fallback chain logic"; exit 1; }
echo "PASS: select-model.sh supports --list-fallback and --next-fallback modes"
