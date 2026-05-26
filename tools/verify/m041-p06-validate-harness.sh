#!/usr/bin/env bash
# tools/verify/m041-p06-validate-harness.sh
# Verifies the #Q-1 corpus-validation harness: computes a verdict when the
# corpus clears the floor, and reports "insufficient corpus" when it doesn't.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if ! command -v jq >/dev/null 2>&1; then
  echo "PASS: jq absent — harness computation path skipped (advisory tool requires jq)"
  exit 0
fi

# Computation path: 3 distinct mock issues, floor lowered to 2 → a verdict line.
out="$(GH_MOCK_DIR=tests/fixtures/detective/gh-mock \
  bash scripts/diagnostics/detective-validate-threshold.sh --min-corpus 2 2>/dev/null)"
case "$out" in
  *"verdict=PASS"*|*"verdict=WARN"*|*"verdict=ESCALATE"*) : ;;
  *) echo "FAIL: harness did not emit a verdict on the computation path: $out"; exit 1 ;;
esac

# Insufficient-corpus path: default floor 5 > 3 mock issues → caution message.
out_low="$(GH_MOCK_DIR=tests/fixtures/detective/gh-mock \
  bash scripts/diagnostics/detective-validate-threshold.sh 2>/dev/null)"
case "$out_low" in
  *"insufficient corpus"*) : ;;
  *) echo "FAIL: harness did not report insufficient corpus below the floor: $out_low"; exit 1 ;;
esac
echo "PASS: validate-threshold harness computes a verdict and degrades cleanly"
