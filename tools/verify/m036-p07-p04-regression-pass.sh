#!/usr/bin/env bash
# tools/verify/m036-p07-p04-regression-pass.sh — M036 P07 T03 cross-
# phase regression. Full pass-through of M036/P04 phase-suite. AD-19.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
AGG="$ROOT/tools/verify/m036-p04-phase-suite.sh"
pass=0
fail=0
if [ ! -f "$AGG" ]; then
  echo "FAIL: $AGG missing"
  echo "SUMMARY: m036-p07-p04-regression-pass.sh pass=0 fail=1"
  exit 1
fi
if ORCHESTRATOR_ROOT="$ROOT" bash "$AGG" >/dev/null 2>&1; then
  echo "PASS: m036-p04-phase-suite-passes"
  pass=$((pass + 1))
else
  echo "FAIL: m036-p04-phase-suite-failed"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p07-p04-regression-pass.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
