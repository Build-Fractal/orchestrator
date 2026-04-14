#!/usr/bin/env bash
# scripts/verify/m004-p07-doctor-recipe.sh — Verify run-doctor.sh includes recipe conformance check
set -eu
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PASS=0; FAIL=0

doctor="$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh"

if grep -q 'check-recipe.sh' "$doctor"; then
  echo "PASS: run-doctor.sh references check-recipe.sh"
  PASS=$((PASS + 1))
else
  echo "FAIL: run-doctor.sh does not reference check-recipe.sh"
  FAIL=$((FAIL + 1))
fi

if grep -q 'Recipe Conformance' "$doctor"; then
  echo "PASS: run-doctor.sh has Recipe Conformance check name"
  PASS=$((PASS + 1))
else
  echo "FAIL: run-doctor.sh missing Recipe Conformance check name"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
