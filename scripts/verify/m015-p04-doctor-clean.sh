#!/usr/bin/env bash
set -eu
# Verify: run-doctor.sh produces a clean report.
# T02 runs the doctor and captures output to evidence/doctor-report.txt.
# This verifier asserts (a) the report exists, (b) contains a clean
# marker, and (c) has no FAIL: lines outside explicit allow-listed
# advisory contexts.
REPORT=.orchestrator/milestones/M015/phases/P04/evidence/doctor-report.txt
test -f "$REPORT" || { echo "FAIL: doctor report missing at $REPORT"; exit 1; }
test -s "$REPORT" || { echo "FAIL: doctor report empty"; exit 1; }
if grep -q "^FAIL:" "$REPORT"; then
  echo "FAIL: doctor report contains FAIL: lines"
  exit 1
fi
# Require an explicit clean marker (T02 writes "DOCTOR_CLEAN")
if ! grep -q "DOCTOR_CLEAN" "$REPORT"; then
  echo "FAIL: doctor report missing DOCTOR_CLEAN marker"
  exit 1
fi
echo "PASS: doctor report clean + DOCTOR_CLEAN marker present"
