#!/usr/bin/env bash
# tools/verify/m036-p07-budget-at-least-one-chunk.sh — M036 P07 T02
# FR-8 at-least-one-chunk invariant behavioral verifier. AD-19.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/dispatch/lib/reference-budget.sh"
if [ ! -f "$LIB" ]; then
  echo "FAIL: $LIB not found"
  echo "SUMMARY: m036-p07-budget-at-least-one-chunk.sh pass=0 fail=1"
  exit 1
fi
# shellcheck disable=SC1090
. "$LIB"
WS="$(mktemp -d)"
trap 'rm -rf "$WS"' EXIT
IN="$WS/in.txt"
OUT="$WS/out.txt"
ERR="$WS/err.txt"
# Single chunk at 500 tokens; budget = 10. Smallest chunk exceeds
# budget, so FR-8 invariant fires: emit one chunk + stderr warning.
printf 'CHUNK-X|500|/path/X\n' > "$IN"
reference_apply_budget "$IN" 10 > "$OUT" 2> "$ERR"
pass=0
fail=0
emitted="$(wc -l < "$OUT" | tr -d ' ')"
if [ "$emitted" -eq 1 ]; then
  echo "PASS: exactly-one-chunk-emitted"
  pass=$((pass + 1))
else
  echo "FAIL: emitted=$emitted (expected 1)"
  fail=$((fail + 1))
fi
if grep -qF -e "WARNING: smallest chunk exceeds budget" "$ERR"; then
  echo "PASS: stderr-warning-emitted"
  pass=$((pass + 1))
else
  echo "FAIL: stderr-warning-missing"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p07-budget-at-least-one-chunk.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
