#!/usr/bin/env bash
# tools/verify/m036-p05-sc4-test-exists-and-passes.sh -- SC-4 Truth Check
# wrapper. Asserts:
#   (a) tests/test-reference-graph-edges.sh exists.
#   (b) Running it exits 0.
#
# Single-script-file invocation per AD-19. The wrapper exists so the SC-4
# acceptance plugs into the M036/P05 phase-suite aggregator alongside the
# 7 sub-gate verifiers from T01/T02/T03 -- the aggregator can only consume
# tools/verify/*.sh shaped sub-gates, so we wrap the integration test
# rather than referencing tests/test-reference-graph-edges.sh directly.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
test_file="$ROOT/tests/test-reference-graph-edges.sh"

if [ ! -f "$test_file" ]; then
  echo "FAIL: m036-p05-sc4-test-exists-and-passes (tests/test-reference-graph-edges.sh missing)" >&2
  exit 1
fi

if bash "$test_file" >/dev/null 2>&1; then
  echo "PASS: m036-p05-sc4-test-exists-and-passes (SC-4)"
  exit 0
fi

echo "FAIL: m036-p05-sc4-test-exists-and-passes (tests/test-reference-graph-edges.sh exited non-zero)" >&2
exit 1
