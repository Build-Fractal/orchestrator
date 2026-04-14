#!/usr/bin/env bash
set -eu
f="scripts/knowledge/consolidate-artifacts.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'compute-staleness' "$f" || { echo "FAIL: consolidate-artifacts.sh does not invoke compute-staleness.sh"; exit 1; }
echo "PASS: consolidate-artifacts.sh integrates compute-staleness.sh"
