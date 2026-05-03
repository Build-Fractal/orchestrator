#!/usr/bin/env bash
# tools/verify/m036-p07-budget-chunk-level-granularity.sh — M036 P07 T02
# FR-3 + FR-7 chunk-level granularity behavioral verifier. AD-19.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/dispatch/lib/reference-budget.sh"
if [ ! -f "$LIB" ]; then
  echo "FAIL: $LIB not found"
  echo "SUMMARY: m036-p07-budget-chunk-level-granularity.sh pass=0 fail=1"
  exit 1
fi
# shellcheck disable=SC1090
. "$LIB"
WS="$(mktemp -d)"
trap 'rm -rf "$WS"' EXIT
IN="$WS/in.txt"
OUT="$WS/out.txt"
# Six chunks at 2000 tokens each = 12000 tokens; budget = 4000.
# Expected: first two chunks survive (4000 total); last four dropped.
{
  printf 'CHUNK-A|2000|/path/A\n'
  printf 'CHUNK-B|2000|/path/B\n'
  printf 'CHUNK-C|2000|/path/C\n'
  printf 'CHUNK-D|2000|/path/D\n'
  printf 'CHUNK-E|2000|/path/E\n'
  printf 'CHUNK-F|2000|/path/F\n'
} > "$IN"
reference_apply_budget "$IN" 4000 > "$OUT"
pass=0
fail=0
# Assertion 1: total tokens ≤ budget.
total="$(awk -F'|' '{ s += $2 } END { print s+0 }' "$OUT")"
if [ "$total" -le 4000 ]; then
  echo "PASS: total-tokens-le-budget (total=$total budget=4000)"
  pass=$((pass + 1))
else
  echo "FAIL: total-tokens-exceed-budget (total=$total budget=4000)"
  fail=$((fail + 1))
fi
# Assertion 2: every emitted line has the full token-count of its source
# (no mid-chunk truncation — chunk-level granularity).
if awk -F'|' '$2 != 2000 { exit 1 }' "$OUT"; then
  echo "PASS: no-mid-chunk-truncation"
  pass=$((pass + 1))
else
  echo "FAIL: mid-chunk-truncation-detected"
  fail=$((fail + 1))
fi
# Assertion 3: at least one chunk emitted.
emitted="$(wc -l < "$OUT" | tr -d ' ')"
if [ "$emitted" -ge 1 ]; then
  echo "PASS: at-least-one-chunk-emitted (emitted=$emitted)"
  pass=$((pass + 1))
else
  echo "FAIL: zero-chunks-emitted"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p07-budget-chunk-level-granularity.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
