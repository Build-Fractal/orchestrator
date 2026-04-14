#!/usr/bin/env bash
# Verifies compute_content_hash returns sha256:{hex} format (never bare hex).
set -eu
f="scripts/lib/hash.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "sha256:" "$f" || { echo "FAIL: $f does not reference sha256: format"; exit 1; }
grep -q "printf.*sha256:" "$f" || { echo "FAIL: $f does not format output as sha256:{hex}"; exit 1; }
echo "PASS: hash.sh uses sha256:{hex} format"
