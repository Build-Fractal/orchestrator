#!/usr/bin/env bash
set -eu
f="scripts/telemetry/record-telemetry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'cost_source.*json\|json.*cost_source' "$f" || { echo "FAIL: cost_source not written to JSONL"; exit 1; }
echo "PASS: record-telemetry.sh writes cost_source to JSONL"
