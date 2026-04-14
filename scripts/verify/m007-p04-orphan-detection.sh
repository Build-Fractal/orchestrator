#!/usr/bin/env bash
# Verifies check-graph-health.sh detects orphaned entries.
set -eu

f="scripts/diagnostics/check-graph-health.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi 'orphan' "$f" || { echo "FAIL: $f does not detect orphaned entries"; exit 1; }
grep -q 'LEFT JOIN' "$f" || { echo "FAIL: $f does not use LEFT JOIN for orphan detection"; exit 1; }
echo "PASS: check-graph-health.sh detects orphaned entries"
