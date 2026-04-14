#!/usr/bin/env bash
# scripts/verify/m004-p07-constitution-existing.sh — Verify check-constitution.sh exists and works
set -eu
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PASS=0; FAIL=0

script="$PROJECT_ROOT/scripts/diagnostics/check-constitution.sh"

if [ -f "$script" ]; then
  echo "PASS: check-constitution.sh exists"
  PASS=$((PASS + 1))
else
  echo "FAIL: check-constitution.sh does not exist"
  FAIL=$((FAIL + 1))
fi

output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
if echo "$output" | grep -q '^DOCTOR:CONSTITUTION'; then
  echo "PASS: check-constitution.sh emits DOCTOR:CONSTITUTION output"
  PASS=$((PASS + 1))
else
  echo "FAIL: check-constitution.sh does not emit DOCTOR:CONSTITUTION output"
  FAIL=$((FAIL + 1))
fi

# Verify it's registered in run-doctor.sh
if grep -q 'check-constitution.sh' "$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh"; then
  echo "PASS: check-constitution.sh registered in run-doctor.sh"
  PASS=$((PASS + 1))
else
  echo "FAIL: check-constitution.sh not registered in run-doctor.sh"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
