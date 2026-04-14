#!/usr/bin/env bash
# Verify CHANGELOG.md has [0.6.0] header and mentions "documentation".
set -eu
f="CHANGELOG.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '## \[0\.6\.0\]' "$f" || { echo "FAIL: missing ## [0.6.0] header"; exit 1; }
grep -qi 'documentation' "$f" || { echo "FAIL: missing 'documentation' in CHANGELOG.md"; exit 1; }
echo "PASS: CHANGELOG.md has [0.6.0] header and mentions documentation"
