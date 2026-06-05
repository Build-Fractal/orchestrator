#!/usr/bin/env bash
# m043-p03-phase-suite.sh — P03 phase-suite aggregator. Runs all four P03 gates
# in order, exits 0 iff all pass, emits one SUMMARY line.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

pass=0
fail=0
run_gate() {
  if bash "$1"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
}

run_gate "tools/verify/m043-p03-warning-matrix.sh"
run_gate "tools/verify/m043-p03-doctor-wiring.sh"
run_gate "tools/verify/m043-p03-installation-anchors.sh"
run_gate "tools/verify/m043-p03-giscus-bytestable.sh"

echo "SUMMARY: m043-p03-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
