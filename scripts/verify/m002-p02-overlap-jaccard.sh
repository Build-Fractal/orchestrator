#!/usr/bin/env bash
set -eu
f="scripts/knowledge/detect-overlap.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qiE 'jaccard|similarity' "$f" || { echo "FAIL: no Jaccard/similarity logic"; exit 1; }
grep -q '0\.70\|70%\|threshold' "$f" || { echo "FAIL: no 70% threshold reference"; exit 1; }
echo "PASS: detect-overlap.sh uses Jaccard similarity with threshold"
