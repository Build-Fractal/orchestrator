#!/usr/bin/env bash
# tools/verify/p06-standard-regression.sh — standard-class regression detection gate.
#
# Stages M999/execution-log.jsonl from regression-standard.jsonl (20 records,
# character=standard, 12 fail / 8 pass → class_pass_rate=0.40, sample=20).
# Asserts FLAGGED line + JSONL record carry class=standard.
#
# AD-19 single-script-file shape. Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p06/regression-standard.jsonl"

pass=0
fail=0

tmp_root="$(mktemp -d -t p06-std.XXXXXX)"
mkdir -p "$tmp_root/milestones/M999"
cp "$FIXTURE" "$tmp_root/milestones/M999/execution-log.jsonl"

ANOMALIES_JSONL="$tmp_root/anomalies.jsonl"
ACTUAL="$(mktemp -t p06-std-actual.XXXXXX)"
trap 'rm -rf "$tmp_root"; rm -f "$ACTUAL"' EXIT

ORCHESTRATOR_ROOT="$tmp_root" \
  M030_ANOMALIES_JSONL_PATH="$ANOMALIES_JSONL" \
  bash "$PROJECT_ROOT/scripts/diagnostics/check-anomalies.sh" --milestone M999 \
  > "$ACTUAL" 2>/dev/null

if grep -qE '^FLAGGED model_routing_regression class=standard class_pass_rate=0\.40 sample=20 threshold=0\.50' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: FLAGGED model_routing_regression class=standard line present"
else
  fail=$((fail + 1))
  echo "FAIL: FLAGGED model_routing_regression class=standard line missing"
  echo "Actual stdout:"
  cat "$ACTUAL"
fi

if [ -f "$ANOMALIES_JSONL" ] && grep -qE '"kind":"model_routing_regression".*"class":"standard"' "$ANOMALIES_JSONL"; then
  pass=$((pass + 1))
  echo "OK: anomalies.jsonl record class=standard present"
else
  fail=$((fail + 1))
  echo "FAIL: anomalies.jsonl record class=standard missing"
  if [ -f "$ANOMALIES_JSONL" ]; then
    echo "anomalies.jsonl content:"
    cat "$ANOMALIES_JSONL"
  else
    echo "anomalies.jsonl does not exist at $ANOMALIES_JSONL"
  fi
fi

echo "SUMMARY: p06-standard-regression.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
