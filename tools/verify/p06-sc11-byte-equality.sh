#!/usr/bin/env bash
# tools/verify/p06-sc11-byte-equality.sh — SC-11 byte-equality gate.
#
# Asserts that scripts/diagnostics/check-anomalies.sh stdout against the
# pre-M030 fixture (tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl,
# 5 records, no model_used / character field) is byte-identical to the
# committed golden baseline at tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt.
#
# Captured pre-T02 amendment (T01 deliverable). The gate ships byte-strict
# from the start: at T01 close it passes because the golden was just captured
# from HEAD; the moment T02's amendment lands, IF it accidentally changes
# unflagged stdout, the verifier fails — surfacing the regression mechanically.
#
# Mirrors P05's p05-sc11-rollup-byte-equality.sh shape (stage carve-out + invoke
# check-anomalies + diff against committed golden). AD-19 single-script-file shape.
# Bash 3.2 compatible.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BASELINE="$PROJECT_ROOT/tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl"

pass=0
fail=0

if [ ! -f "$BASELINE" ]; then
  echo "FAIL: baseline missing at $BASELINE"
  echo "SUMMARY: p06-sc11-byte-equality.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: fixture missing at $FIXTURE"
  echo "SUMMARY: p06-sc11-byte-equality.sh pass=0 fail=1"
  exit 1
fi

tmp_root="$(mktemp -d -t p06-sc11.XXXXXX)"
mkdir -p "$tmp_root/milestones/M001"
cp "$FIXTURE" "$tmp_root/milestones/M001/execution-log.jsonl"
printf '%s\n' '---' 'type: milestone-context' 'milestone: "M001"' 'status: open' '---' \
  > "$tmp_root/milestones/M001/M001-CONTEXT.md"

ACTUAL="$(mktemp -t p06-sc11-actual.XXXXXX)"
trap 'rm -rf "$tmp_root"; rm -f "$ACTUAL"' EXIT

ORCHESTRATOR_ROOT="$tmp_root" PROJECT_ROOT="$PROJECT_ROOT" \
  bash "$PROJECT_ROOT/scripts/diagnostics/check-anomalies.sh" \
  --milestone M001 \
  > "$ACTUAL" 2>/dev/null

if diff -u "$BASELINE" "$ACTUAL"; then
  pass=1
  echo "OK: check-anomalies stdout byte-identical to baseline"
else
  fail=1
  echo "FAIL: check-anomalies stdout differs from baseline (see diff above)"
fi

echo "SUMMARY: p06-sc11-byte-equality.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
