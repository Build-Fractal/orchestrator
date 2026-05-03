#!/usr/bin/env bash
# tools/verify/m036-p07-recipe-shape.sh — M036 P07 T01 recipe-shape
# verifier. Asserts templates/context-recipe.yaml declares the new
# reference: section block + default_token_budget per the M036/P07
# plan. Single-script-file shape (AD-19). Bash 3.2 / POSIX-sh.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F="$ROOT/templates/context-recipe.yaml"
pass=0
fail=0

check() {
  local label="$1" pattern="$2"
  if grep -qF -e "$pattern" "$F"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (missing token: $pattern)"
    fail=$((fail + 1))
  fi
}

if [ ! -f "$F" ]; then
  echo "FAIL: $F not found"
  echo "SUMMARY: m036-p07-recipe-shape.sh pass=0 fail=1"
  exit 1
fi

check "reference-section-key"       "reference:"
check "reference-section-source"    "source: reference"
check "reference-section-priority"  "priority: optional"
check "reference-section-order"     "order: 45"
check "reference-block-budget"      "default_token_budget: 4000"

echo "SUMMARY: m036-p07-recipe-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
