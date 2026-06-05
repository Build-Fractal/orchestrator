#!/usr/bin/env bash
# m043-p00-phase-suite.sh — P00 phase-suite aggregator. Runs both P00 gates
# in order, exits 0 iff both pass, emits one SUMMARY line.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

pass=0
fail=0

run_gate() {
  # $1 = gate script path (relative to repo root)
  if bash "$1"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
}

run_gate "tools/verify/m043-p00-findings-shape.sh"
run_gate "tools/verify/m043-p00-fixture-seeds-present.sh"

echo "SUMMARY: m043-p00-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
