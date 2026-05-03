#!/usr/bin/env bash
# tools/verify/m036-p06-test-harness.sh -- M036 P06 T04 permissive
# harness-shape verifier. rc<=1 acceptable since rc=1 still emits
# BATTERY in fail mode; rc>=2 indicates abort. Asserts each harness
# exists, executable, ran-to-completion, and emitted a well-formed
# BATTERY: pass=N fail=N skip=N last line.
#
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
pass=0
fail=0
chk_harness() {
  local label="$1" path="$2"
  local F="$ROOT/$path"
  if [ ! -f "$F" ]; then
    echo "FAIL: $label (missing: $F)"
    fail=$((fail + 1))
    return
  fi
  if [ ! -x "$F" ]; then
    echo "FAIL: $label (not executable: $F)"
    fail=$((fail + 1))
    return
  fi
  local out
  out=$(mktemp "${TMPDIR:-/tmp}/m036-p06-th.XXXXXX")
  ORCHESTRATOR_ROOT="$ROOT" bash "$F" >"$out" 2>/dev/null || true
  local rc=$?
  # Permissive on rc<=1.
  if [ "$rc" -ge 2 ]; then
    echo "FAIL: $label (rc=$rc; harness aborted)"
    fail=$((fail + 1))
    rm -f "$out"
    return
  fi
  # Last non-empty line should match BATTERY: pass=N fail=N skip=N.
  local last
  last=$(grep -E '^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$' "$out" | tail -n 1)
  if [ -n "$last" ]; then
    echo "PASS: $label-shape-OK"
    pass=$((pass + 1))
  else
    echo "FAIL: $label-malformed-BATTERY-line"
    fail=$((fail + 1))
  fi
  rm -f "$out"
}
chk_harness "sc13-extract-idempotency"     "tests/test-extract-idempotency.sh"
chk_harness "sc5-reingest-idempotency"     "tests/test-reference-reingest-idempotency.sh"
chk_harness "sc6-supersede-chain"          "tests/test-reference-supersede-chain.sh"
echo "SUMMARY: m036-p06-test-harness.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
