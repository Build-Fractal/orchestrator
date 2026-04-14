#!/usr/bin/env bash
# Verifies check-graph-health.sh checks supersession integrity and dangling edges.
set -eu

f="scripts/diagnostics/check-graph-health.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'supersedes' "$f" || { echo "FAIL: $f does not check supersession chains"; exit 1; }
grep -qi 'dangling' "$f" || { echo "FAIL: $f does not check for dangling edges"; exit 1; }
grep -q 'NOT EXISTS' "$f" || { echo "FAIL: $f does not use NOT EXISTS for integrity checks"; exit 1; }
echo "PASS: check-graph-health.sh checks supersession integrity and dangling edges"
