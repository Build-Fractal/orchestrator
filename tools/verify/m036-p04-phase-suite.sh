#!/usr/bin/env bash
# tools/verify/m036-p04-phase-suite.sh -- M036 P04 phase-suite aggregator.
# Wires all 13 P04 sub-gates. Patterned after m036-p03-phase-suite.sh:
# run helper inspects exit code only; SKIP-internal verifiers exit 0
# informationally so they report PASS at aggregator level.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
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

# T01 (4)
run m036-p04-classifier-shape.sh
run m036-p04-classifier-rejects-unknown.sh
run m036-p04-classifier-rejects-missing-required.sh
run m036-p04-fixture-corpus-shape.sh

# T02 (3)
run m036-p04-driver-shape.sh
run m036-p04-rebuild-index-recognizes-ref.sh
run m036-p04-idempotency.sh

# T03 (3)
run m036-p04-command-shape.sh
run m036-p04-tier-2-block-not-promoted.sh
run m036-p04-p05-regression-pass.sh

# T04 (3)
run m036-p04-test-harness.sh
run m036-p04-acceptance-harness-passes.sh
run m036-p04-p02-regression-pass.sh

echo "SUMMARY: m036-p04-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
