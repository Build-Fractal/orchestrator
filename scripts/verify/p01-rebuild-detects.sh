#!/usr/bin/env bash
# Verifies rebuild-index.sh uses content_hash to detect changes.
set -eu
f="scripts/knowledge/rebuild-index.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "content_hash" "$f" || { echo "FAIL: $f missing content_hash comparison"; exit 1; }
grep -q "hash.sh" "$f" || { echo "FAIL: $f does not source hash.sh"; exit 1; }
echo "PASS: rebuild-index.sh detects changes via content_hash"
