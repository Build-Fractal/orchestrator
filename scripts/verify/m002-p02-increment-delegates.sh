#!/usr/bin/env bash
set -eu
f="scripts/knowledge/increment-hits.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'update-entry\.sh' "$f" || { echo "FAIL: does not delegate to update-entry.sh"; exit 1; }
grep -q '\-\-increment-hits' "$f" || { echo "FAIL: does not pass --increment-hits flag"; exit 1; }
echo "PASS: increment-hits.sh delegates to update-entry.sh --increment-hits"
