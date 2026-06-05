#!/usr/bin/env bash
# m043-p04-phase-suite.sh — P04 phase-suite aggregator. Runs the three P04
# gates in order, exits 0 iff all pass, emits one SUMMARY line. Must not
# recurse into itself.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

pass=0
fail=0
run_gate() {
  if bash "$1"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
}

run_gate "tools/verify/m043-p04-protocol-anchors.sh"
run_gate "tools/verify/m043-p04-evidence-gate.sh"
run_gate "tools/verify/m043-p04-deferred-note.sh"

echo "SUMMARY: m043-p04-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
