#!/usr/bin/env bash
# `grep -E` (ERE) is required for the `|` alternations below: BSD grep on macOS
# treats `\|` in BRE as literal characters, so the legacy `grep -q 'A\|B'` form
# silently failed every check on macOS — the script was a no-op outside Linux CI.
set -eu
f="scripts/telemetry/record-telemetry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'type.*telemetry' "$f" || { echo "FAIL: does not produce type:telemetry entries"; exit 1; }
grep -qE 'unitId|unit.id|unit_id|UNIT_ID' "$f" || { echo "FAIL: missing unitId field"; exit 1; }
grep -qE 'model_used|MODEL_USED' "$f" || { echo "FAIL: missing model_used field handling"; exit 1; }
grep -qE 'tokens_input|TOKENS_INPUT' "$f" || { echo "FAIL: missing tokens_input field handling"; exit 1; }
grep -qE 'tokens_output|TOKENS_OUTPUT' "$f" || { echo "FAIL: missing tokens_output field handling"; exit 1; }
grep -qE 'tokens_cache_read|TOKENS_CACHE_READ' "$f" || { echo "FAIL: missing tokens_cache_read field handling"; exit 1; }
grep -qE 'cost_estimated|COST_ESTIMATED' "$f" || { echo "FAIL: missing cost_estimated field handling"; exit 1; }
grep -qE 'cache_hit_rate|CACHE_HIT_RATE' "$f" || { echo "FAIL: missing cache_hit_rate field handling"; exit 1; }
grep -qE 'payload_bytes|PAYLOAD_BYTES' "$f" || { echo "FAIL: missing payload_bytes field handling"; exit 1; }
echo "PASS: record-telemetry.sh handles all required telemetry fields"
