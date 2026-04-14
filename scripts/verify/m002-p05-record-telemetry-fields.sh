#!/usr/bin/env bash
set -eu
f="scripts/telemetry/record-telemetry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'type.*telemetry' "$f" || { echo "FAIL: does not produce type:telemetry entries"; exit 1; }
grep -q 'unitId\|unit.id\|unit_id\|UNIT_ID' "$f" || { echo "FAIL: missing unitId field"; exit 1; }
grep -q 'model_used\|MODEL_USED' "$f" || { echo "FAIL: missing model_used field handling"; exit 1; }
grep -q 'tokens_input\|TOKENS_INPUT' "$f" || { echo "FAIL: missing tokens_input field handling"; exit 1; }
grep -q 'tokens_output\|TOKENS_OUTPUT' "$f" || { echo "FAIL: missing tokens_output field handling"; exit 1; }
grep -q 'tokens_cache_read\|TOKENS_CACHE_READ' "$f" || { echo "FAIL: missing tokens_cache_read field handling"; exit 1; }
grep -q 'cost_estimated\|COST_ESTIMATED' "$f" || { echo "FAIL: missing cost_estimated field handling"; exit 1; }
grep -q 'cache_hit_rate\|CACHE_HIT_RATE' "$f" || { echo "FAIL: missing cache_hit_rate field handling"; exit 1; }
grep -q 'payload_bytes\|PAYLOAD_BYTES' "$f" || { echo "FAIL: missing payload_bytes field handling"; exit 1; }
echo "PASS: record-telemetry.sh handles all required telemetry fields"
