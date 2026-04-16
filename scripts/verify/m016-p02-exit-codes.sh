#!/usr/bin/env bash
set -euo pipefail
# Verify run-suite.sh exit codes: 0 for all-pass, non-zero for no-args/no-match
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SUITE="$PROJECT_ROOT/scripts/verify/run-suite.sh"

fail=0

# Test 1: no args should exit non-zero
if bash "$RUN_SUITE" > /dev/null 2>&1; then
  echo "FAIL: run-suite.sh should exit non-zero with no arguments"
  fail=1
fi

# Test 2: nonexistent milestone should exit non-zero
if bash "$RUN_SUITE" nonexistent P99 > /dev/null 2>&1; then
  echo "FAIL: run-suite.sh should exit non-zero when no scripts match"
  fail=1
fi

# Test 3: known good suite (m016 P01) should exit 0
if ! bash "$RUN_SUITE" m016 P01 > /dev/null 2>&1; then
  echo "FAIL: run-suite.sh should exit 0 for m016 P01 (all scripts pass)"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: run-suite.sh exit codes correct (no-args=1, no-match=1, all-pass=0)"
  exit 0
fi
exit 1
