#!/usr/bin/env bash
# scripts/verify/m004-p07-recipe-sources.sh — Verify check-recipe.sh validates source types
set -eu
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PASS=0; FAIL=0

# The script should contain source type validation logic
script="$PROJECT_ROOT/scripts/diagnostics/check-recipe.sh"
if grep -q 'computed\|phase_summaries\|phase_plan\|task_plan\|template' "$script"; then
  echo "PASS: check-recipe.sh contains known source type references"
  PASS=$((PASS + 1))
else
  echo "FAIL: check-recipe.sh missing source type validation"
  FAIL=$((FAIL + 1))
fi

# Valid recipe should pass
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
if echo "$output" | grep -q 'status=ok'; then
  echo "PASS: default recipe passes source type validation"
  PASS=$((PASS + 1))
else
  echo "FAIL: default recipe failed source type validation"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
