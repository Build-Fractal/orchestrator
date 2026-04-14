#!/usr/bin/env bash
# scripts/verify/m004-p07-recipe-output.sh — Verify check-recipe.sh emits DOCTOR:RECIPE output
set -eu
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PASS=0; FAIL=0

output="$(bash "$PROJECT_ROOT/scripts/diagnostics/check-recipe.sh" --root "$PROJECT_ROOT" 2>&1)" || true

if echo "$output" | grep -q '^DOCTOR:RECIPE'; then
  echo "PASS: DOCTOR:RECIPE output present"
  PASS=$((PASS + 1))
else
  echo "FAIL: no DOCTOR:RECIPE output"
  FAIL=$((FAIL + 1))
fi

if echo "$output" | grep -q 'status='; then
  echo "PASS: status= field present"
  PASS=$((PASS + 1))
else
  echo "FAIL: status= field missing"
  FAIL=$((FAIL + 1))
fi

if echo "$output" | grep -q 'sections='; then
  echo "PASS: sections= field present"
  PASS=$((PASS + 1))
else
  echo "FAIL: sections= field missing"
  FAIL=$((FAIL + 1))
fi

if echo "$output" | grep -q 'invalid='; then
  echo "PASS: invalid= field present"
  PASS=$((PASS + 1))
else
  echo "FAIL: invalid= field missing"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
