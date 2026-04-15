#!/usr/bin/env bash
# scripts/verify/m003-p08-source-not-modified.sh
# Truth: the P08 integration test harness never writes inside the source
# fixture. Runs the integration test once and inspects stdout/stderr for any
# "source fixture was modified" FAIL line; exits 0 if none found.
#
# This delegates the fingerprint logic to the integration test (which uses
# lib/snapshot-tree.sh). The verify script only observes the result, keeping
# each Check: a single-script-file invocation (AD-19).
#
# MEM001 safe. Exit 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST="$REPO_ROOT/tests/integration/test-m003-e2e-migration.sh"

if [ ! -x "$TEST" ]; then
  echo "FAIL: integration test missing or not executable: $TEST"
  exit 1
fi

# Capture combined stdout+stderr. The test itself may exit non-zero for
# unrelated assertions; what matters here is that the specific "source
# fixture was modified" failure did not appear.
out="$(bash "$TEST" 2>&1 || true)"

if echo "$out" | grep -q 'source fixture was modified'; then
  echo "FAIL: integration test reported source fixture was modified"
  echo "$out" | grep 'source fixture was modified' >&2
  exit 1
fi

# Also assert the "unmodified" PASS line is actually present for the synthetic
# pass (so we know the check was exercised, not just absent).
if ! echo "$out" | grep -q 'synthetic: source fixture unmodified'; then
  echo "FAIL: integration test did not assert synthetic source unmodified (did it run?)"
  echo "$out" >&2
  exit 1
fi

echo "PASS: source fixture not modified by migration pipeline"
exit 0
