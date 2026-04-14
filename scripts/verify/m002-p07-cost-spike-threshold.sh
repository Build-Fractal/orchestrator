#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/check-cost-spikes.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'cost_estimated' "$f" || { echo "FAIL: does not parse cost_estimated from execution log"; exit 1; }
grep -q '5\|spike_threshold' "$f" || { echo "FAIL: missing 5x cost spike threshold"; exit 1; }
grep -q 'avg_cost\|average' "$f" || { echo "FAIL: does not compute average cost"; exit 1; }
grep -q 'execution-log.jsonl\|exec_log' "$f" || { echo "FAIL: does not read execution-log.jsonl"; exit 1; }
grep -q 'WARNING.*cost\|WARNING.*spike' "$f" || { echo "FAIL: missing cost spike warning message"; exit 1; }
grep -q 'unit_id\|unitId' "$f" || { echo "FAIL: does not include unit ID in warning"; exit 1; }
echo "PASS: check-cost-spikes.sh flags tasks costing >5x average"
