#!/usr/bin/env bash
# tools/verify/m036-p01-phase-suite.sh -- M036 P01 phase-suite aggregator.
# Invokes the eight P01 sub-gates in order. Exits 0 iff every sub-gate
# passes. Single-script-file shape per AD-19 -- the `run` helper is a
# single function invocation per gate, no compound chains at the
# invocation layer.
#
# Filename milestone-prefixed (m036-) per the phase-suite naming
# convention (commands/plan-phase.md "milestone slug REQUIRED for
# per-phase verifiers"). Patterned after tools/verify/m036-p00-phase-suite.sh.
#
# Eight sub-gates (M036 P01):
#   T01: m036-p01-fixture-corpus-shape.sh
#        m036-p01-probe-shape.sh
#   T02: m036-p01-markdown-adapter.sh
#        m036-p01-pdf-adapter.sh
#   T03: m036-p01-docx-adapter.sh
#        m036-p01-xlsx-adapter.sh
#   T04: m036-p01-registry-all-live.sh
#        m036-p01-test-harness.sh
#
# Per-adapter verifiers (pdf/docx/xlsx) exit 0 informationally on
# host-tooling-absent SKIP, so on a host without pandoc/openpyxl those
# sub-gates still report PASS at the aggregator level (the SKIP semantic
# is handled inside the verifier; the aggregator only inspects exit code).
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

run m036-p01-fixture-corpus-shape.sh
run m036-p01-probe-shape.sh
run m036-p01-markdown-adapter.sh
run m036-p01-pdf-adapter.sh
run m036-p01-docx-adapter.sh
run m036-p01-xlsx-adapter.sh
run m036-p01-registry-all-live.sh
run m036-p01-test-harness.sh

echo "SUMMARY: m036-p01-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
