#!/usr/bin/env bash
# Verifies check-graph-health.sh emits DOCTOR:GRAPH_HEALTH structured output.
set -eu

f="scripts/diagnostics/check-graph-health.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'DOCTOR:GRAPH_HEALTH' "$f" || { echo "FAIL: $f does not emit DOCTOR:GRAPH_HEALTH line"; exit 1; }
grep -q 'status=' "$f" || { echo "FAIL: $f does not emit status= in DOCTOR line"; exit 1; }
echo "PASS: check-graph-health.sh emits DOCTOR:GRAPH_HEALTH structured output"
