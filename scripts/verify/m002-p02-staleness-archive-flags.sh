#!/usr/bin/env bash
set -eu
f="scripts/knowledge/compute-staleness.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-archive-below' "$f" || { echo "FAIL: missing --archive-below flag"; exit 1; }
grep -q '\-\-min-hits' "$f" || { echo "FAIL: missing --min-hits flag"; exit 1; }
grep -q '\-\-dry-run' "$f" || { echo "FAIL: missing --dry-run flag"; exit 1; }
echo "PASS: compute-staleness.sh supports --archive-below, --min-hits, and --dry-run flags"
