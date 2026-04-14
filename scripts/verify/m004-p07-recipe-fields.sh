#!/usr/bin/env bash
# scripts/verify/m004-p07-recipe-fields.sh — Verify check-recipe.sh validates all 7 sections
set -eu
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PASS=0; FAIL=0

output="$(bash "$PROJECT_ROOT/scripts/diagnostics/check-recipe.sh" --root "$PROJECT_ROOT" 2>&1)" || true
doctor_line="$(echo "$output" | grep '^DOCTOR:RECIPE' | head -1)" || true

if [ -z "$doctor_line" ]; then
  echo "FAIL: no DOCTOR:RECIPE output"
  exit 1
fi

sections="$(echo "$doctor_line" | sed -n 's/.*sections=\([0-9]*\).*/\1/p')"
if [ "$sections" -ge 7 ] 2>/dev/null; then
  echo "PASS: check-recipe.sh validated $sections sections (>= 7)"
  PASS=$((PASS + 1))
else
  echo "FAIL: check-recipe.sh validated $sections sections (expected >= 7)"
  FAIL=$((FAIL + 1))
fi

invalid="$(echo "$doctor_line" | sed -n 's/.*invalid=\([0-9]*\).*/\1/p')"
if [ "$invalid" -eq 0 ] 2>/dev/null; then
  echo "PASS: no invalid sections in default recipe"
  PASS=$((PASS + 1))
else
  echo "FAIL: $invalid invalid sections in default recipe"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
