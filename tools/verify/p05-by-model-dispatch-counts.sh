#!/usr/bin/env bash
# tools/verify/p05-by-model-dispatch-counts.sh -- M030/P05/T02 SC-8 gate (sentence 1).
#
# Asserts that `bash scripts/diagnostics/metrics-rollup.sh --by-model
# --log tests/fixtures/m030-p05/live-routed-corpus.jsonl` emits a per-tier
# dispatch-count line shaped as
#
#   <N> dispatches: <fast> fast / <balanced> balanced / <smart> smart
#
# with the fixture-known integer counts (14 fast / 7 balanced / 2 smart
# over 23 total). FR-15 first sentence; SC-8 first sentence.
#
# Bash 3.2 compatible. AD-19 single-script-file shape (the verifier itself
# is invoked via plain `bash <path>`; awk / pipes / $(...) inside the body
# are MEM004 emitter-internal carve-out per script-file convention).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p05/live-routed-corpus.jsonl"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"

pass=0
fail=0

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: live-routed-corpus.jsonl missing at $FIXTURE"
  echo "SUMMARY: p05-by-model-dispatch-counts.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$ROLLUP" ]; then
  echo "FAIL: metrics-rollup.sh missing at $ROLLUP"
  echo "SUMMARY: p05-by-model-dispatch-counts.sh pass=0 fail=1"
  exit 1
fi

ACTUAL="$(mktemp -t p05-by-model-disp.XXXXXX)"
trap 'rm -f "$ACTUAL"' EXIT

bash "$ROLLUP" --by-model --log "$FIXTURE" > "$ACTUAL" 2>/dev/null
rc=$?

if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: --by-model exit 0"
else
  fail=$((fail + 1))
  echo "FAIL: --by-model exited $rc (expected 0)"
fi

# Shape gate: dispatch-count line present.
if grep -qE '^[0-9]+ dispatches: [0-9]+ fast / [0-9]+ balanced / [0-9]+ smart' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: dispatch-count line present (FR-15 sentence 1 shape)"
else
  fail=$((fail + 1))
  echo "FAIL: dispatch-count line missing or malformed"
  echo "Actual stdout:"
  cat "$ACTUAL"
fi

# Exact-count gate: 14 fast / 7 balanced / 2 smart over 23 total.
if grep -qE '^23 dispatches: 14 fast / 7 balanced / 2 smart' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: counts match expected (14/7/2 over 23)"
else
  fail=$((fail + 1))
  echo "FAIL: counts diverge from expected (14/7/2 over 23)"
  echo "Actual stdout:"
  cat "$ACTUAL"
fi

echo "SUMMARY: p05-by-model-dispatch-counts.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
