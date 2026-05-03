#!/usr/bin/env bash
# tools/verify/m036-p07-phase-suite.sh — M036 P07 phase-suite aggregator.
# Wires all 17 P07 sub-gates: T01 (2) + T02 (5) + T03 (8) + T04 (2).
# Patterned verbatim after tools/verify/m036-p04-phase-suite.sh + m036-p05.
# Filename milestone-prefixed (m036-p07-) per Plan-Time Discipline rule 6.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
#
# Sub-gate exit code is the only signal; SUB-FAIL diagnostics are routed
# to stderr while stdout is reserved for the canonical SUMMARY line that
# check-must-haves.sh consumes.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
VDIR="$ROOT/tools/verify"
pass=0
fail=0

run() {
  local v="$1"
  if [ ! -f "$VDIR/$v" ]; then
    echo "FAIL: $v missing"
    fail=$((fail + 1))
    return
  fi
  if ORCHESTRATOR_ROOT="$ROOT" bash "$VDIR/$v" >/dev/null 2>&1; then
    echo "PASS: $v"
    pass=$((pass + 1))
  else
    echo "FAIL: $v"
    fail=$((fail + 1))
  fi
}

# T01 (2)
run m036-p07-recipe-shape.sh
run m036-p07-handler-shape.sh

# T02 (5)
run m036-p07-budget-lib-shape.sh
run m036-p07-relevance-lib-shape.sh
run m036-p07-budget-chunk-level-granularity.sh
run m036-p07-budget-at-least-one-chunk.sh
run m036-p07-relevance-deterministic.sh

# T03 (8)
run m036-p07-dispatcher-routes-reference.sh
run m036-p07-omit-empty-section.sh
run m036-p07-fixture-task-plans-shape.sh
run m036-p07-baseline-captured.sh
run m036-p07-p02-regression-pass.sh
run m036-p07-p03-regression-pass.sh
run m036-p07-p04-regression-pass.sh
run m036-p07-p05-regression-pass.sh

# T04 (2)
run m036-p07-test-harness.sh
run m036-p07-acceptance-harness-passes.sh

echo "SUMMARY: m036-p07-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
