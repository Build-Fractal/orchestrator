#!/usr/bin/env bash
# Verify CLAUDE.md contains current version and M006 reference.
set -eu
f="CLAUDE.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qiE 'v0\.[2-9]|0\.[2-9]\.[0-9]' "$f" || { echo "FAIL: CLAUDE.md missing current version reference"; exit 1; }
grep -q 'M006' "$f" || { echo "FAIL: CLAUDE.md missing M006 reference"; exit 1; }
echo "PASS: CLAUDE.md contains current version and M006 reference"
