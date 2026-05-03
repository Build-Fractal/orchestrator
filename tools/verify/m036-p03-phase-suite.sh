#!/usr/bin/env bash
# tools/verify/m036-p03-phase-suite.sh -- M036 P03 phase-suite aggregator.
# Wires all 14 P03 sub-gates. Patterned after tools/verify/m036-p02-phase-suite.sh.
# Filename milestone-prefixed (m036-) per the post-M031 plan-phase contract.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
#
# 14 sub-gates (M036 P03):
#   T01: m036-p03-conversus-preset-shape.sh
#        m036-p03-m030-task-type-extraction.sh
#        m036-p03-fixture-corpus-shape.sh
#   T02: m036-p03-driver-tier-2-shape.sh
#        m036-p03-tier-2-llm-helper-shape.sh
#        m036-p03-unit-close-extraction-shape.sh
#   T03: m036-p03-gate-helper-shape.sh
#        m036-p03-tier-2-deferred-error-removed.sh
#        m036-p03-tier-2-pass-end-to-end.sh
#        m036-p03-tier-2-block-retention.sh
#        m036-p03-p02-regression-pass.sh
#   T04: m036-p03-fixture-canned-structured-shape.sh
#        m036-p03-test-harness.sh
#        m036-p03-acceptance-harness-passes.sh
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
pass=0
fail=0

run() {
  local gate="$1"
  if bash "$ROOT/tools/verify/$gate" >/dev/null 2>&1; then
    echo "PASS: $gate"
    pass=$((pass + 1))
  else
    echo "FAIL: $gate"
    fail=$((fail + 1))
  fi
}

run m036-p03-conversus-preset-shape.sh
run m036-p03-m030-task-type-extraction.sh
run m036-p03-fixture-corpus-shape.sh
run m036-p03-driver-tier-2-shape.sh
run m036-p03-tier-2-llm-helper-shape.sh
run m036-p03-unit-close-extraction-shape.sh
run m036-p03-gate-helper-shape.sh
run m036-p03-tier-2-deferred-error-removed.sh
run m036-p03-tier-2-pass-end-to-end.sh
run m036-p03-tier-2-block-retention.sh
run m036-p03-p02-regression-pass.sh
run m036-p03-fixture-canned-structured-shape.sh
run m036-p03-test-harness.sh
run m036-p03-acceptance-harness-passes.sh

echo "SUMMARY: m036-p03-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
