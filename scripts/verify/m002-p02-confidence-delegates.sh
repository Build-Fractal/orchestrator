#!/usr/bin/env bash
set -eu
f="scripts/knowledge/update-confidence.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'update-entry\.sh' "$f" || { echo "FAIL: does not delegate to update-entry.sh"; exit 1; }
echo "PASS: update-confidence.sh delegates to update-entry.sh"
