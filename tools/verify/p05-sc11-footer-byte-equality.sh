#!/usr/bin/env bash
# tools/verify/p05-sc11-footer-byte-equality.sh — M030/P05/T01 SC-11 gate.
#
# Asserts that the scripts/diagnostics/efficiency-footer.sh emission
# against the pre-M030 fixture (tests/fixtures/m030-p02/pre-m030-dispatch-
# usage.jsonl, 5 records, no model_routed field) is byte-identical to the
# committed pre-amendment golden baseline at tests/fixtures/m030-p05/
# footer-pre-m030-baseline.txt.
#
# CON-2 / FR-19 / SC-11 contract: T02's footer model_mix: line must be
# suppressed entirely when no shadow-on records present in the underlying
# corpus. Pre-M030 fixtures (no model_routed field) must emit zero new
# bytes through efficiency-footer.sh post-amendment.
#
# Strategy A: stage an ORCHESTRATOR_ROOT carve-out so the footer's
# internal milestone-log resolver picks up the pre-M030 fixture as if
# it were the active milestone's execution-log.jsonl. Same pattern P02
# round-trip + the T01 baseline-capture script use.
#
# Bash 3.2 compatible. AD-19 single-script-file shape (invoked via plain
# `bash <path>`; no compound chains in the verifier's Check command).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BASELINE="$PROJECT_ROOT/tests/fixtures/m030-p05/footer-pre-m030-baseline.txt"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl"
FOOTER="$PROJECT_ROOT/scripts/diagnostics/efficiency-footer.sh"

pass=0
fail=0

if [ ! -f "$BASELINE" ]; then
  echo "FAIL: footer pre-m030 baseline missing at $BASELINE"
  echo "SUMMARY: p05-sc11-footer-byte-equality.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: pre-m030 dispatch_usage fixture missing at $FIXTURE"
  echo "SUMMARY: p05-sc11-footer-byte-equality.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$FOOTER" ]; then
  echo "FAIL: efficiency-footer.sh missing at $FOOTER"
  echo "SUMMARY: p05-sc11-footer-byte-equality.sh pass=0 fail=1"
  exit 1
fi

# Stage the ORCHESTRATOR_ROOT carve-out per-invocation. The carve-out is
# the same shape T01 captured the baseline against:
#   <tmp_root>/milestones/M001/execution-log.jsonl  IS  the pre-M030 fixture.
TMP_ROOT="$(mktemp -d -t p05-sc11-footer-root.XXXXXX)"
ACTUAL="$(mktemp -t p05-sc11-footer-actual.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"; rm -f "$ACTUAL"' EXIT

mkdir -p "$TMP_ROOT/milestones/M001"
cp "$FIXTURE" "$TMP_ROOT/milestones/M001/execution-log.jsonl"

ORCHESTRATOR_ROOT="$TMP_ROOT" bash "$FOOTER" \
  --milestone M001 \
  > "$ACTUAL" 2>/dev/null

if diff -u "$BASELINE" "$ACTUAL"; then
  pass=1
  echo "OK: efficiency-footer output byte-identical to pre-amendment baseline"
else
  fail=1
  echo "FAIL: efficiency-footer output differs from baseline (see diff above)"
fi

echo "SUMMARY: p05-sc11-footer-byte-equality.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
