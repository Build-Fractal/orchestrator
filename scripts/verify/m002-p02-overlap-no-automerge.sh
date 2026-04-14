#!/usr/bin/env bash
set -eu
f="scripts/knowledge/detect-overlap.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'OVERLAP' "$f" || { echo "FAIL: no OVERLAP output format"; exit 1; }
grep -q 'review' "$f" || { echo "FAIL: no review recommendation in output"; exit 1; }
grep -qiE 'auto.merge|auto_merge|performing merge' "$f" && { echo "FAIL: contains auto-merge logic"; exit 1; }
echo "PASS: detect-overlap.sh flags overlaps for review without auto-merging"
