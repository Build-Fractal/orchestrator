#!/usr/bin/env bash
# scripts/verify/m004-p07-recipe-priorities.sh — Verify check-recipe.sh validates priorities
set -eu
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PASS=0; FAIL=0

# The script should contain priority validation logic
script="$PROJECT_ROOT/scripts/diagnostics/check-recipe.sh"
if grep -q 'required\|compressible\|optional' "$script"; then
  echo "PASS: check-recipe.sh contains priority validation references"
  PASS=$((PASS + 1))
else
  echo "FAIL: check-recipe.sh missing priority validation"
  FAIL=$((FAIL + 1))
fi

# Valid recipe should pass
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
if echo "$output" | grep -q 'status=ok'; then
  echo "PASS: default recipe passes priority validation"
  PASS=$((PASS + 1))
else
  echo "FAIL: default recipe failed priority validation"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
