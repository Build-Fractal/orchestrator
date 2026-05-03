#!/usr/bin/env bash
# tools/verify/m036-p07-budget-lib-shape.sh — M036 P07 T02 budget-lib
# token-presence verifier. Asserts reference-budget.sh defines
# reference_apply_budget with chunk-level granularity and at-least-
# one-chunk invariant. AD-19 single-script-file shape.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F="$ROOT/scripts/dispatch/lib/reference-budget.sh"
pass=0
fail=0
check() {
  local label="$1" pat="$2"
  if grep -qF -e "$pat" "$F"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (missing: $pat)"
    fail=$((fail + 1))
  fi
}
if [ ! -f "$F" ]; then
  echo "FAIL: $F not found"
  echo "SUMMARY: m036-p07-budget-lib-shape.sh pass=0 fail=1"
  exit 1
fi
check "fn-defn"               "reference_apply_budget()"
check "chunk-level-comment"   "chunk-level granularity"
check "at-least-one-comment"  "at-least-one-chunk invariant"
check "stderr-warning"        "WARNING: smallest chunk exceeds budget"
check "MEM004-pure-lib"       "Pure-lib MEM004"
echo "SUMMARY: m036-p07-budget-lib-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
