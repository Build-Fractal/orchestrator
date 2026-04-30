#!/usr/bin/env bash
# tools/verify/p05-model-mix-footer-line.sh -- M030/P05/T02 FR-16 gate.
#
# Asserts that scripts/diagnostics/efficiency-footer.sh emits a
# `model_mix: fast=<N> balanced=<M> smart=<K>` line (with the standard
# 2-space indent the rest of the footer uses) when the active milestone's
# execution-log carries shadow-on dispatch_usage records (records bearing
# the `model_routed` field).
#
# Strategy A: stage an ORCHESTRATOR_ROOT carve-out so the footer's
# internal milestone-log resolver picks up the live-routed-corpus fixture
# as if it were the active milestone's execution-log.jsonl. Same pattern
# the SC-11 footer byte-equality gate uses; same pattern P02 round-trip
# established.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p05/live-routed-corpus.jsonl"
FOOTER="$PROJECT_ROOT/scripts/diagnostics/efficiency-footer.sh"

pass=0
fail=0

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: live-routed-corpus.jsonl missing at $FIXTURE"
  echo "SUMMARY: p05-model-mix-footer-line.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$FOOTER" ]; then
  echo "FAIL: efficiency-footer.sh missing at $FOOTER"
  echo "SUMMARY: p05-model-mix-footer-line.sh pass=0 fail=1"
  exit 1
fi

# Stage the carve-out: <tmp_root>/milestones/M999/execution-log.jsonl
# IS the live-routed-corpus fixture. M999 is a synthetic milestone ID so
# the footer's --milestone resolution short-circuits cleanly.
TMP_ROOT="$(mktemp -d -t p05-model-mix-footer-root.XXXXXX)"
ACTUAL="$(mktemp -t p05-model-mix-footer-actual.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"; rm -f "$ACTUAL"' EXIT

mkdir -p "$TMP_ROOT/milestones/M999"
cp "$FIXTURE" "$TMP_ROOT/milestones/M999/execution-log.jsonl"

ORCHESTRATOR_ROOT="$TMP_ROOT" bash "$FOOTER" --milestone M999 > "$ACTUAL" 2>/dev/null
rc=$?

if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: efficiency-footer exit 0"
else
  fail=$((fail + 1))
  echo "FAIL: efficiency-footer exited $rc"
fi

# model_mix: line present with the standard 2-space indent.
if grep -qE '^  model_mix: fast=[0-9]+ balanced=[0-9]+ smart=[0-9]+' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: model_mix: line present with 2-space indent (FR-16 shape)"
else
  fail=$((fail + 1))
  echo "FAIL: model_mix: line missing or wrong indent"
  echo "Actual stdout:"
  cat "$ACTUAL"
fi

# Exact-count gate: 14 fast / 7 balanced / 2 smart matches the corpus.
if grep -qE '^  model_mix: fast=14 balanced=7 smart=2' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: model_mix counts match expected (14/7/2)"
else
  fail=$((fail + 1))
  echo "FAIL: model_mix counts diverge from expected (14/7/2)"
  echo "Actual stdout:"
  cat "$ACTUAL"
fi

echo "SUMMARY: p05-model-mix-footer-line.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
