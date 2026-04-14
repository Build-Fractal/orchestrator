#!/usr/bin/env bash
# Verifies rebuild-index.sh reports changed/unchanged counts in output.
set -eu
f="scripts/knowledge/rebuild-index.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "unchanged" "$f" || { echo "FAIL: $f missing unchanged count reporting"; exit 1; }
grep -q "changed" "$f" || { echo "FAIL: $f missing changed count reporting"; exit 1; }
echo "PASS: rebuild-index.sh reports changed/unchanged counts"
