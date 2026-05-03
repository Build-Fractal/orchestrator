#!/usr/bin/env bash
# tools/verify/m036-p07-p03-regression-pass.sh — M036 P07 T03 cross-
# phase regression. Re-runs the M036/P03 phase-suite aggregator and
# asserts pass=14 fail=0. Full pass-through (no semantics flips
# affecting P07). AD-19.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
AGG="$ROOT/tools/verify/m036-p03-phase-suite.sh"
pass=0
fail=0
if [ ! -f "$AGG" ]; then
  echo "FAIL: $AGG missing"
  echo "SUMMARY: m036-p07-p03-regression-pass.sh pass=0 fail=1"
  exit 1
fi
if ORCHESTRATOR_ROOT="$ROOT" bash "$AGG" >/dev/null 2>&1; then
  echo "PASS: m036-p03-phase-suite-passes"
  pass=$((pass + 1))
else
  echo "FAIL: m036-p03-phase-suite-failed"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p07-p03-regression-pass.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
