#!/usr/bin/env bash
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'cost_source' "$f" || { echo "FAIL: file-formats.md missing cost_source documentation"; exit 1; }
echo "PASS: file-formats.md documents cost_source schema"
