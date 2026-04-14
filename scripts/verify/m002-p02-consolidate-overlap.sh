#!/usr/bin/env bash
set -eu
f="scripts/knowledge/consolidate-artifacts.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'detect-overlap' "$f" || { echo "FAIL: consolidate-artifacts.sh does not invoke detect-overlap.sh"; exit 1; }
echo "PASS: consolidate-artifacts.sh integrates detect-overlap.sh"
