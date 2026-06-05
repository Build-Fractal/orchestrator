#!/usr/bin/env bash
# m043-p01-phase-suite.sh — P01 phase-suite aggregator. Runs all four P01
# gates in order, exits 0 iff all pass, emits one SUMMARY line.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

pass=0
fail=0
run_gate() {
  if bash "$1"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
}

run_gate "tools/verify/m043-p01-config-and-resolver.sh"
run_gate "tools/verify/m043-p01-wrangler-lint.sh"
run_gate "tools/verify/m043-p01-wiki-init-branch.sh"
run_gate "tools/verify/m043-p01-wiki-deploy-url.sh"

echo "SUMMARY: m043-p01-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
