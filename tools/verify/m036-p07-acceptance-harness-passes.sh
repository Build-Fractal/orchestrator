#!/usr/bin/env bash
# tools/verify/m036-p07-acceptance-harness-passes.sh — M036 P07 T04
# strict pass-rate gate complementing the permissive harness-shape
# verifier (m036-p07-test-harness.sh). Asserts both SC-3 and SC-7
# acceptance harnesses exit 0 specifically (every assertion passed).
# Permissive+strict split lets the phase-suite independently fail on
# harness-machinery-broken vs harness-ran-but-found-regressions.
# AD-19 single-script-file shape.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
pass=0
fail=0

chk_pass() {
  local label="$1" path="$2"
  if [ ! -f "$path" ]; then
    echo "FAIL: $label missing"
    fail=$((fail + 1))
    return
  fi
  if ORCHESTRATOR_ROOT="$ROOT" bash "$path" >/dev/null 2>&1; then
    echo "PASS: $label rc=0"
    pass=$((pass + 1))
  else
    echo "FAIL: $label rc!=0"
    fail=$((fail + 1))
  fi
}

chk_pass "test-reference-dispatch-injection"      "$ROOT/tests/test-reference-dispatch-injection.sh"
chk_pass "test-reference-backwards-compat-golden" "$ROOT/tests/test-reference-backwards-compat-golden.sh"

echo "SUMMARY: m036-p07-acceptance-harness-passes.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
