#!/usr/bin/env bash
# tools/verify/m036-p02-phase-suite.sh -- M036 P02 phase-suite aggregator.
# Wires all 15 P02 sub-gates. Patterned after tools/verify/m036-p01-phase-suite.sh.
# Filename milestone-prefixed (m036-) per the "milestone slug REQUIRED"
# rule. Single-script-file shape per AD-19; the `run` helper is a single
# function invocation per gate.
#
# 15 sub-gates (M036 P02):
#   T01: m036-p02-manifest-contract-shape.sh
#        m036-p02-fixture-manifest-shape.sh
#        m036-p02-fixture-corpus-shape.sh
#   T02: m036-p02-extract-driver-shape.sh
#        m036-p02-binary-preservation.sh
#        m036-p02-content-hash.sh
#        m036-p02-size-cap-external-pointer.sh
#   T03: m036-p02-extract-md.sh
#        m036-p02-extract-pdf-host-aware.sh
#        m036-p02-extract-docx-host-aware.sh
#        m036-p02-extract-command-shape.sh
#        m036-p02-summary-mode-stub-vs-operator.sh
#        m036-p02-tier-2-deferred-error.sh
#   T04: m036-p02-idempotency.sh
#        m036-p02-test-harness.sh
#
# Per-format verifiers (PDF, DOCX) emit SKIP exit 0 on host-tool absence,
# so on bare hosts those sub-gates still report PASS at the aggregator
# level (the SKIP semantic is handled inside the verifier; the aggregator
# only inspects exit code).
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

run m036-p02-manifest-contract-shape.sh
run m036-p02-fixture-manifest-shape.sh
run m036-p02-fixture-corpus-shape.sh
run m036-p02-extract-driver-shape.sh
run m036-p02-binary-preservation.sh
run m036-p02-content-hash.sh
run m036-p02-size-cap-external-pointer.sh
run m036-p02-extract-md.sh
run m036-p02-extract-pdf-host-aware.sh
run m036-p02-extract-docx-host-aware.sh
run m036-p02-extract-command-shape.sh
run m036-p02-summary-mode-stub-vs-operator.sh
run m036-p02-tier-2-deferred-error.sh
run m036-p02-idempotency.sh
run m036-p02-test-harness.sh

echo "SUMMARY: m036-p02-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
