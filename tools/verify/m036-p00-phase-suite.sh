#!/usr/bin/env bash
# tools/verify/m036-p00-phase-suite.sh -- M036 P00 phase-suite aggregator.
# Invokes the eight P00 sub-gates in order. Exits 0 iff every sub-gate
# passes. Single-script-file shape per AD-19 -- the `run` helper is a
# single function invocation per gate, no compound chains at the
# invocation layer.
#
# NOTE: filename is milestone-prefixed (m036-) per the phase-suite naming
# convention introduced after the M030/M031/M036 P00 collision. Earlier
# milestones used unprefixed names (p00-phase-suite.sh) which silently
# overwrote each other on each new milestone P00 close. M031's
# aggregator was restored from commit 428650d to
# tools/verify/m031-p00-phase-suite.sh; M030's was lost in the prior
# overwrite (separate cleanup item). See commands/plan-phase.md
# Plan-Time Discipline rule 6.
#
# Eight sub-gates (M036 P00):
#   T01: p00-taxonomy-shape.sh
#        p00-frontmatter-contract-shape.sh
#        p00-source-types-shape.sh
#   T02: p00-edge-types-shape.sh
#        p00-adapter-registry-shape.sh
#   T03: p00-scope-tag-extension.sh
#        p00-spec-management-crossref.sh
#        p00-taxonomy-rejects-unknown.sh
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

run p00-taxonomy-shape.sh
run p00-frontmatter-contract-shape.sh
run p00-source-types-shape.sh
run p00-edge-types-shape.sh
run p00-adapter-registry-shape.sh
run p00-scope-tag-extension.sh
run p00-spec-management-crossref.sh
run p00-taxonomy-rejects-unknown.sh

echo "SUMMARY: m036-p00-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
