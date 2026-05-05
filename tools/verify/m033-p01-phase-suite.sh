#!/usr/bin/env bash
set -u -o pipefail

# m033-p01-phase-suite.sh
# P01 phase-suite aggregator. Runs all 14 P01 verifiers in dependency
# order (fixture verifiers first, then SSOT parity, then start.sh
# shape, then start.sh behavior, then friendly-tester shape, then
# acceptance wrappers). Emits the canonical SUMMARY line consumed by
# scripts/verify/validate-milestone.sh.

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERIFIER_DIR="$PROJECT_ROOT/tools/verify"

pass=0
fail=0

verifiers=(
  m033-p01-pbj-fixture-shape.sh
  m033-p01-pbj-fixture-readme-oracle.sh
  m033-p01-branch-detection-ssot-parity.sh
  m033-p01-start-md-shape.sh
  m033-p01-start-sh-flags-and-init-invocation.sh
  m033-p01-branch-detection-rules.sh
  m033-p01-subflow-stubs-shape.sh
  m033-p01-disambiguation-question-shape.sh
  m033-p01-friendly-tester-protocol-shape.sh
  m033-p01-report-template-shape.sh
  m033-p01-validate-report-sh-contract.sh
  m033-p01-validate-report-fixtures-shape.sh
  m033-p01-acceptance-shape-sc1.sh
  m033-p01-acceptance-shape-sc8.sh
)

for v in "${verifiers[@]}"; do
  if bash "$VERIFIER_DIR/$v" >/dev/null 2>&1; then
    pass=$((pass+1))
    echo "PASS: $v"
  else
    fail=$((fail+1))
    echo "FAIL: $v"
  fi
done

echo "SUMMARY: m033-p01-phase-suite.sh pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
