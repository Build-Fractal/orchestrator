#!/usr/bin/env bash
# Verifies check-graph-health.sh reports graph statistics.
set -eu

f="scripts/diagnostics/check-graph-health.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'entries' "$f" || { echo "FAIL: $f does not query entries"; exit 1; }
grep -q 'edges' "$f" || { echo "FAIL: $f does not query edges"; exit 1; }
grep -q 'scope_tags' "$f" || { echo "FAIL: $f does not query scope_tags"; exit 1; }
grep -q 'avg.*degree\|degree\|avg_degree' "$f" || { echo "FAIL: $f does not compute avg degree"; exit 1; }
grep -q 'Statistics' "$f" || { echo "FAIL: $f does not output statistics line"; exit 1; }
echo "PASS: check-graph-health.sh reports graph statistics"
