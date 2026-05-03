#!/usr/bin/env bash
# tools/verify/m036-p07-test-harness.sh — M036 P07 T04 permissive
# harness-shape verifier. Asserts both SC-3 and SC-7 acceptance harnesses
# exist + are executable + emit BATTERY: as their last stdout line.
# rc<=1 acceptable since rc=1 still emits BATTERY: in fail mode (the
# permissive shape contract); rc>=2 indicates harness machinery itself
# is broken (syntax error / abort path).
#
# Permissive+strict gate split per the M036-canonical acceptance-harness
# pattern (fourth instance: M036/P02/T04 SC-10, M036/P03/T04 SC-11+SC-12,
# M036/P04/T04 SC-1+SC-2, now M036/P07/T04 SC-3+SC-7). This file is the
# permissive arm; m036-p07-acceptance-harness-passes.sh is the strict arm.
# AD-19 single-script-file shape.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
pass=0
fail=0

chk_harness() {
  local label="$1" path="$2"
  if [ ! -f "$path" ]; then
    echo "FAIL: $label missing"
    fail=$((fail + 1))
    return
  fi
  if [ ! -x "$path" ]; then
    echo "FAIL: $label not-executable"
    fail=$((fail + 1))
    return
  fi
  local out tmp rc last
  tmp="$(mktemp)"
  set +e
  ORCHESTRATOR_ROOT="$ROOT" bash "$path" > "$tmp" 2>/dev/null
  rc=$?
  set -e
  if [ "$rc" -ge 2 ]; then
    echo "FAIL: $label rc=$rc (harness-machinery-broken)"
    rm -f "$tmp"
    fail=$((fail + 1))
    return
  fi
  last="$(tail -n 1 "$tmp")"
  rm -f "$tmp"
  case "$last" in
    BATTERY:*) echo "PASS: $label well-formed (rc=$rc)"; pass=$((pass + 1)) ;;
    *) echo "FAIL: $label missing-BATTERY-last-line"; fail=$((fail + 1)) ;;
  esac
}

chk_harness "test-reference-dispatch-injection"      "$ROOT/tests/test-reference-dispatch-injection.sh"
chk_harness "test-reference-backwards-compat-golden" "$ROOT/tests/test-reference-backwards-compat-golden.sh"

echo "SUMMARY: m036-p07-test-harness.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
