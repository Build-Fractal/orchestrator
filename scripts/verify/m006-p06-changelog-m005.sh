#!/usr/bin/env bash
# Verify CHANGELOG.md has [0.5.0] header and mentions "hardening" or "safety".
set -eu
f="CHANGELOG.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '## \[0\.5\.0\]' "$f" || { echo "FAIL: missing ## [0.5.0] header"; exit 1; }
grep -qiE 'hardening|safety' "$f" || { echo "FAIL: missing 'hardening' or 'safety' in CHANGELOG.md"; exit 1; }
echo "PASS: CHANGELOG.md has [0.5.0] header and mentions hardening/safety"
