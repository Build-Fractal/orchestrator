#!/usr/bin/env bash
# tools/verify/m036-p05-phase-suite.sh -- M036 P05 phase-suite aggregator.
# Invokes the eight P05 sub-gates in order. Exits 0 iff every sub-gate
# passes. Single-script-file shape per AD-19 -- the `run` helper is a
# single function invocation per gate, no compound chains at the
# invocation layer.
#
# Filename is milestone-prefixed (m036-p05-) per the phase-suite naming
# convention introduced after the M030/M031/M036 P00 collision incident.
# See commands/plan-phase.md Plan-Time Discipline rule 6 and the M036/P00
# phase-summary for context.
#
# Eight sub-gates (M036 P05):
#   T01: m036-p05-edges-schema-accepts-new.sh
#        m036-p05-edges-schema-accepts-old.sh
#        m036-p05-rebuild-emits-new-edges.sh
#   T02: m036-p05-traverse-cites.sh
#        m036-p05-traverse-relates-to-baseline.sh   (CON-5 regression guard)
#   T03: m036-p05-scope-filter-source-tag.sh
#        m036-p05-scope-filter-baseline.sh           (CON-5 regression guard)
#   T04: m036-p05-sc4-test-exists-and-passes.sh     (SC-4 end-to-end)
#
# Output contract:
#   - exactly one canonical SUMMARY: line on stdout
#       "SUMMARY: m036-p05-phase-suite.sh pass=N fail=M"
#   - sub-gate failures emit a SUB-FAIL: <gate> diagnostic to stderr
#     (debug surface; stdout reserved for the SUMMARY: consumer)
#   - exit 0 iff fail=0; exit 1 otherwise.
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0
fail=0

run() {
  local gate="$1"
  if bash "$ROOT/tools/verify/$gate" >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "SUB-FAIL: $gate" >&2
  fi
}

run m036-p05-edges-schema-accepts-new.sh
run m036-p05-edges-schema-accepts-old.sh
run m036-p05-rebuild-emits-new-edges.sh
run m036-p05-traverse-cites.sh
run m036-p05-traverse-relates-to-baseline.sh
run m036-p05-scope-filter-source-tag.sh
run m036-p05-scope-filter-baseline.sh
run m036-p05-sc4-test-exists-and-passes.sh

echo "SUMMARY: m036-p05-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
