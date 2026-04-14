#!/usr/bin/env bash
# Verify CHANGELOG.md has [0.2.0] header and mentions "knowledge".
set -eu
f="CHANGELOG.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '## \[0\.2\.0\]' "$f" || { echo "FAIL: missing ## [0.2.0] header"; exit 1; }
grep -qi 'knowledge' "$f" || { echo "FAIL: missing 'knowledge' in CHANGELOG.md"; exit 1; }
echo "PASS: CHANGELOG.md has [0.2.0] header and mentions knowledge"
