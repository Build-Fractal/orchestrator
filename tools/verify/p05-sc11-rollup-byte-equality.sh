#!/usr/bin/env bash
# tools/verify/p05-sc11-rollup-byte-equality.sh — M030/P05/T01 SC-11 gate.
#
# Asserts that the unflagged scripts/diagnostics/metrics-rollup.sh emission
# against the pre-M030 fixture (tests/fixtures/m030-p02/pre-m030-dispatch-
# usage.jsonl, 5 records, no model_routed field) is byte-identical to the
# committed pre-amendment golden baseline at tests/fixtures/m030-p05/
# rollup-pre-m030-baseline.txt.
#
# CON-2 / FR-19 / SC-11 contract: T02's --by-model amendment must remain
# strictly additive — pre-M030 inputs must round-trip byte-identically
# through the unflagged rollup invocation. This gate captures the
# pre-amendment HEAD output as the contract; any T02 change that breaks
# the unflagged path immediately fails this gate.
#
# Bash 3.2 compatible. AD-19 single-script-file shape (invoked via plain
# `bash <path>`; no compound chains, no eval).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BASELINE="$PROJECT_ROOT/tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"

pass=0
fail=0

if [ ! -f "$BASELINE" ]; then
  echo "FAIL: rollup pre-m030 baseline missing at $BASELINE"
  echo "SUMMARY: p05-sc11-rollup-byte-equality.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: pre-m030 dispatch_usage fixture missing at $FIXTURE"
  echo "SUMMARY: p05-sc11-rollup-byte-equality.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$ROLLUP" ]; then
  echo "FAIL: metrics-rollup.sh missing at $ROLLUP"
  echo "SUMMARY: p05-sc11-rollup-byte-equality.sh pass=0 fail=1"
  exit 1
fi

ACTUAL="$(mktemp -t p05-sc11-rollup-actual.XXXXXX)"
trap 'rm -f "$ACTUAL"' EXIT

bash "$ROLLUP" \
  --log "$FIXTURE" \
  --granularity milestone --milestone M001 \
  > "$ACTUAL" 2>/dev/null

if diff -u "$BASELINE" "$ACTUAL"; then
  pass=1
  echo "OK: unflagged metrics-rollup output byte-identical to pre-amendment baseline"
else
  fail=1
  echo "FAIL: unflagged metrics-rollup output differs from baseline (see diff above)"
fi

echo "SUMMARY: p05-sc11-rollup-byte-equality.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
