#!/usr/bin/env bash
# Verify CHANGELOG.md has [0.3.0] header and mentions "migration".
set -eu
f="CHANGELOG.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '## \[0\.3\.0\]' "$f" || { echo "FAIL: missing ## [0.3.0] header"; exit 1; }
grep -qi 'migration' "$f" || { echo "FAIL: missing 'migration' in CHANGELOG.md"; exit 1; }
echo "PASS: CHANGELOG.md has [0.3.0] header and mentions migration"
