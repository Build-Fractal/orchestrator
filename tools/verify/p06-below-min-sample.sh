#!/usr/bin/env bash
# tools/verify/p06-below-min-sample.sh — below-min-sample no-emission gate.
#
# Stages M999/execution-log.jsonl from below-min-sample.jsonl (5 mechanical
# records, 3 fail / 2 pass → class_pass_rate=0.40 BUT sample=5 < 10
# min_class_sample floor). Asserts NO regression line + NO JSONL record:
# the per-class sample-floor short-circuit fires before threshold compare.
#
# AD-19 single-script-file shape. Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p06/below-min-sample.jsonl"

pass=0
fail=0

tmp_root="$(mktemp -d -t p06-bms.XXXXXX)"
mkdir -p "$tmp_root/milestones/M999"
cp "$FIXTURE" "$tmp_root/milestones/M999/execution-log.jsonl"

ANOMALIES_JSONL="$tmp_root/anomalies.jsonl"
ACTUAL="$(mktemp -t p06-bms-actual.XXXXXX)"
trap 'rm -rf "$tmp_root"; rm -f "$ACTUAL"' EXIT

ORCHESTRATOR_ROOT="$tmp_root" \
  M030_ANOMALIES_JSONL_PATH="$ANOMALIES_JSONL" \
  bash "$PROJECT_ROOT/scripts/diagnostics/check-anomalies.sh" --milestone M999 \
  > "$ACTUAL" 2>/dev/null

if grep -qE 'FLAGGED model_routing_regression' "$ACTUAL"; then
  fail=$((fail + 1))
  echo "FAIL: FLAGGED model_routing_regression line UNEXPECTEDLY present (below-min-sample should suppress)"
  cat "$ACTUAL"
else
  pass=$((pass + 1))
  echo "OK: below-min-sample suppresses FLAGGED line"
fi

if [ -f "$ANOMALIES_JSONL" ] && grep -qE '"kind":"model_routing_regression"' "$ANOMALIES_JSONL"; then
  fail=$((fail + 1))
  echo "FAIL: anomalies.jsonl UNEXPECTEDLY contains model_routing_regression record"
  cat "$ANOMALIES_JSONL"
else
  pass=$((pass + 1))
  echo "OK: below-min-sample suppresses anomaly JSONL record"
fi

echo "SUMMARY: p06-below-min-sample.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
