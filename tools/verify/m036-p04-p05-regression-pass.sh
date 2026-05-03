#!/usr/bin/env bash
# tools/verify/m036-p04-p05-regression-pass.sh -- M036 P04 T03.
# Regression guard: re-runs the P05 phase-suite aggregator and asserts
# its SUMMARY line still reports pass=8 fail=0. Confirms P04's edits to
# rebuild-index.sh (basename-filter widening + *.text|*.structured
# exclusion) do not perturb P05's 8 edge-insertion verifiers.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
P05_AGG="$ROOT/tools/verify/m036-p05-phase-suite.sh"
fail=0
if [ ! -f "$P05_AGG" ]; then
  echo "FAIL: P05 phase-suite missing $P05_AGG"
  echo "SUMMARY: m036-p04-p05-regression-pass.sh fail=1"
  exit 1
fi
OUT="$(mktemp "${TMPDIR:-/tmp}/m036-p04-p05-regression.XXXXXX.txt")"
ORCHESTRATOR_ROOT="$ROOT" bash "$P05_AGG" > "$OUT" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "PASS: P05 aggregator exit 0"
else
  echo "FAIL: P05 aggregator exit $rc"
  fail=$((fail + 1))
fi
if grep -qE 'SUMMARY: m036-p05-phase-suite\.sh pass=[0-9]+ fail=0' "$OUT"; then
  echo "PASS: P05 SUMMARY reports fail=0"
else
  echo "FAIL: P05 SUMMARY does not report fail=0 (regression detected)"
  cat "$OUT" >&2
  fail=$((fail + 1))
fi
rm -f "$OUT"
echo "SUMMARY: m036-p04-p05-regression-pass.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
