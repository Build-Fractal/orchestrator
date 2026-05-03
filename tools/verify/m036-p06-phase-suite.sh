#!/usr/bin/env bash
# tools/verify/m036-p06-phase-suite.sh -- M036 P06 T04 16-gate
# phase-suite aggregator. Wires all P06 sub-gates:
#   T01 (3): extract-supersede-shape + helper-shape + supersede-end-to-end
#   T02 (4): ingest-review-shape + helper-shape + review-emission-end-to-end + removed-detection-end-to-end
#   T03 (2): fixture-corpus-shape + extract-manifest-shape
#   T04 (7): test-harness + acceptance-harness-passes + p02-regression + p03-regression + p04-regression + p05-regression + p07-regression
# Total: 16 sub-gates.
#
# Patterned after m036-p07-phase-suite.sh (17 gates) and
# m036-p04-phase-suite.sh (13 gates). Run helper inspects exit
# code only; SKIP-emitting sub-gates exit 0 informationally and
# report PASS at aggregator level.
#
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
VDIR="$ROOT/tools/verify"
pass=0
fail=0
run() {
  local g="$1"
  if [ ! -f "$VDIR/$g" ]; then
    echo "FAIL: $g missing"
    fail=$((fail + 1))
    return
  fi
  if ORCHESTRATOR_ROOT="$ROOT" bash "$VDIR/$g" >/dev/null 2>&1; then
    echo "PASS: $g"
    pass=$((pass + 1))
  else
    echo "FAIL: $g"
    fail=$((fail + 1))
  fi
}
# T01 (3)
run m036-p06-extract-supersede-shape.sh
run m036-p06-extract-supersede-helper-shape.sh
run m036-p06-supersede-chain-end-to-end.sh
# T02 (4)
run m036-p06-ingest-review-shape.sh
run m036-p06-ingest-review-helper-shape.sh
run m036-p06-review-emission-end-to-end.sh
run m036-p06-removed-detection-end-to-end.sh
# T03 (2)
run m036-p06-fixture-corpus-shape.sh
run m036-p06-extract-manifest-shape.sh
# T04 (7)
run m036-p06-test-harness.sh
run m036-p06-acceptance-harness-passes.sh
run m036-p06-p02-regression-pass.sh
run m036-p06-p03-regression-pass.sh
run m036-p06-p04-regression-pass.sh
run m036-p06-p05-regression-pass.sh
run m036-p06-p07-regression-pass.sh
echo "SUMMARY: m036-p06-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
