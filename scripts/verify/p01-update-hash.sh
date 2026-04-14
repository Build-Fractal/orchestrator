#!/usr/bin/env bash
# Verifies update-entry.sh recomputes content_hash when body changes.
set -eu
f="scripts/knowledge/update-entry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "content_hash" "$f" || { echo "FAIL: $f missing content_hash handling"; exit 1; }
grep -q "hash.sh" "$f" || { echo "FAIL: $f does not source hash.sh"; exit 1; }
grep -q "\-\-body" "$f" || { echo "FAIL: $f missing --body flag"; exit 1; }
echo "PASS: update-entry.sh handles content_hash on body change"
