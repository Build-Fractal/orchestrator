#!/usr/bin/env bash
# Verifies scripts/lib/hash.sh exists with double-sourcing guard and
# compute_content_hash function.
set -eu
f="scripts/lib/hash.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '_HASH_SOURCED' "$f" || { echo "FAIL: $f missing double-sourcing guard"; exit 1; }
grep -q 'compute_content_hash' "$f" || { echo "FAIL: $f missing compute_content_hash function"; exit 1; }
grep -q 'compute_file_body_hash' "$f" || { echo "FAIL: $f missing compute_file_body_hash function"; exit 1; }
echo "PASS: hash.sh exists with guard and both functions"
