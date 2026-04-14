#!/usr/bin/env bash
# scripts/verify/m004-p07-events-existing.sh — Verify check-events.sh exists and works
set -eu
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PASS=0; FAIL=0

script="$PROJECT_ROOT/scripts/diagnostics/check-events.sh"

if [ -f "$script" ]; then
  echo "PASS: check-events.sh exists"
  PASS=$((PASS + 1))
else
  echo "FAIL: check-events.sh does not exist"
  FAIL=$((FAIL + 1))
fi

output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
if echo "$output" | grep -q '^DOCTOR:EVENTS'; then
  echo "PASS: check-events.sh emits DOCTOR:EVENTS output"
  PASS=$((PASS + 1))
else
  echo "FAIL: check-events.sh does not emit DOCTOR:EVENTS output"
  FAIL=$((FAIL + 1))
fi

# Verify it's registered in run-doctor.sh
if grep -q 'check-events.sh' "$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh"; then
  echo "PASS: check-events.sh registered in run-doctor.sh"
  PASS=$((PASS + 1))
else
  echo "FAIL: check-events.sh not registered in run-doctor.sh"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
