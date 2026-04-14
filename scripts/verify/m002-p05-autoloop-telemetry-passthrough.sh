#!/usr/bin/env bash
set -eu
f="scripts/lifecycle/auto-loop.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'record-result\|RECORD_RESULT' "$f" || { echo "FAIL: auto-loop.sh does not reference record-result.sh"; exit 1; }
grep -qE '\-\-model=|\-\-model ' "$f" || { echo "FAIL: auto-loop.sh Step G does not pass --model to record-result.sh"; exit 1; }
grep -qE '\-\-tokens-input=|\-\-tokens.input' "$f" || { echo "FAIL: auto-loop.sh Step G does not pass --tokens-input to record-result.sh"; exit 1; }
grep -qE '\-\-cost=|\-\-cost ' "$f" || { echo "FAIL: auto-loop.sh Step G does not pass --cost to record-result.sh"; exit 1; }
echo "PASS: auto-loop.sh Step G passes telemetry fields to record-result.sh"
