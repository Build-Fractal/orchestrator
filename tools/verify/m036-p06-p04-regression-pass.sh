#!/usr/bin/env bash
# tools/verify/m036-p06-p04-regression-pass.sh -- M036 P06 T04
# cross-phase regression. Full pass-through of M036/P04 phase-suite.
# Load-bearing: P06 modifies ingest-reference.sh; this regression
# confirms the existing P04 contracts (CREATED/SKIPPED/REJECTED/
# BLOCKED/SUMMARY emission, partial-success ingest, FR-18 BLOCK
# detection) survive byte-equivalent. AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
AGG="$ROOT/tools/verify/m036-p04-phase-suite.sh"
pass=0
fail=0
if [ ! -f "$AGG" ]; then
  echo "FAIL: $AGG missing"
  echo "SUMMARY: m036-p06-p04-regression-pass.sh pass=0 fail=1"
  exit 1
fi
if ORCHESTRATOR_ROOT="$ROOT" bash "$AGG" >/dev/null 2>&1; then
  echo "PASS: m036-p04-phase-suite-passes"
  pass=$((pass + 1))
else
  echo "FAIL: m036-p04-phase-suite-failed"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p06-p04-regression-pass.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
