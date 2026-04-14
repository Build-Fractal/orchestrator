#!/usr/bin/env bash
# Verifies create-entry.sh includes content_hash in frontmatter output.
set -eu
f="scripts/knowledge/create-entry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "content_hash" "$f" || { echo "FAIL: $f missing content_hash field"; exit 1; }
grep -q "hash.sh" "$f" || { echo "FAIL: $f does not source hash.sh"; exit 1; }
echo "PASS: create-entry.sh writes content_hash"
