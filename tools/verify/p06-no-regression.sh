#!/usr/bin/env bash
# tools/verify/p06-no-regression.sh — no-regression no-emission gate.
#
# Stages M999/execution-log.jsonl from no-regression.jsonl (60 records,
# 20 per class, per-class 4 fail / 16 pass → class_pass_rate=0.80,
# sample=20). Asserts:
#   - NO FLAGGED model_routing_regression line in stdout
#   - NO model_routing_regression record in anomalies.jsonl (file may
#     be absent — both states are PASS)
#   - the legacy "Anomaly Detection (Tier 1 baseline)" header IS present
#     (sanity-check the legacy block still emits)
#
# AD-19 single-script-file shape. Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p06/no-regression.jsonl"

pass=0
fail=0

tmp_root="$(mktemp -d -t p06-noreg.XXXXXX)"
mkdir -p "$tmp_root/milestones/M999"
cp "$FIXTURE" "$tmp_root/milestones/M999/execution-log.jsonl"

ANOMALIES_JSONL="$tmp_root/anomalies.jsonl"
ACTUAL="$(mktemp -t p06-noreg-actual.XXXXXX)"
trap 'rm -rf "$tmp_root"; rm -f "$ACTUAL"' EXIT

ORCHESTRATOR_ROOT="$tmp_root" \
  M030_ANOMALIES_JSONL_PATH="$ANOMALIES_JSONL" \
  bash "$PROJECT_ROOT/scripts/diagnostics/check-anomalies.sh" --milestone M999 \
  > "$ACTUAL" 2>/dev/null

if grep -qE 'FLAGGED model_routing_regression' "$ACTUAL"; then
  fail=$((fail + 1))
  echo "FAIL: FLAGGED model_routing_regression line UNEXPECTEDLY present"
  cat "$ACTUAL"
else
  pass=$((pass + 1))
  echo "OK: no FLAGGED model_routing_regression line"
fi

if [ -f "$ANOMALIES_JSONL" ] && grep -qE '"kind":"model_routing_regression"' "$ANOMALIES_JSONL"; then
  fail=$((fail + 1))
  echo "FAIL: anomalies.jsonl UNEXPECTEDLY contains model_routing_regression record"
  cat "$ANOMALIES_JSONL"
else
  pass=$((pass + 1))
  echo "OK: no model_routing_regression record in anomalies.jsonl"
fi

if grep -qE '^Anomaly Detection \(Tier 1 baseline\)' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: legacy Anomaly Detection block present"
else
  fail=$((fail + 1))
  echo "FAIL: legacy Anomaly Detection block missing"
fi

echo "SUMMARY: p06-no-regression.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
