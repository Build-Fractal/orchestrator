#!/usr/bin/env bash
# Verifies knowledge.db is rebuilt atomically using the temp-file-then-mv
# pattern consistent with existing scripts.
set -eu

f="scripts/knowledge/rebuild-index.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'tmp' "$f" || { echo "FAIL: $f does not reference temp file for atomic rebuild"; exit 1; }
grep -q 'mv.*\.db' "$f" || grep -q 'mv.*db' "$f" || { echo "FAIL: $f does not mv temp DB to final path"; exit 1; }
echo "PASS: knowledge.db uses atomic temp-file-then-mv rebuild pattern"
