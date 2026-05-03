#!/usr/bin/env bash
# tools/verify/m036-p06-acceptance-harness-passes.sh -- M036 P06 T04
# strict pass-rate gate. Asserts each harness exits 0 specifically
# (rc=0). Permissive+strict gate split: m036-p06-test-harness.sh
# asserts harness-machinery is well-formed; this verifier asserts
# the harnesses ran-and-passed.
#
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
pass=0
fail=0
run_strict() {
  local label="$1" path="$2"
  local F="$ROOT/$path"
  if [ ! -f "$F" ]; then
    echo "FAIL: $label (missing: $F)"
    fail=$((fail + 1))
    return
  fi
  if ORCHESTRATOR_ROOT="$ROOT" bash "$F" >/dev/null 2>&1; then
    echo "PASS: $label-rc=0"
    pass=$((pass + 1))
  else
    echo "FAIL: $label-rc-nonzero"
    fail=$((fail + 1))
  fi
}
run_strict "sc13-extract-idempotency"     "tests/test-extract-idempotency.sh"
run_strict "sc5-reingest-idempotency"     "tests/test-reference-reingest-idempotency.sh"
run_strict "sc6-supersede-chain"          "tests/test-reference-supersede-chain.sh"
echo "SUMMARY: m036-p06-acceptance-harness-passes.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
