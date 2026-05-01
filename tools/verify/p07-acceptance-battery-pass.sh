#!/usr/bin/env bash
# tools/verify/p07-acceptance-battery-pass.sh — M030/P07/T02 acceptance gate.
#
# Thin wrapper over tests/m030-acceptance/run-acceptance-battery.sh.
# Asserts:
#   1) the runner exits 0
#   2) its last stdout line matches ^BATTERY: pass=[0-9]+ fail=0$
#
# The pass count is informational (currently 22 verifier invocations
# covering 14 SCs); the binding contract is `fail=0`. AD-19 single-script-
# file shape; bash 3.2 compatible.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RUNNER="$PROJECT_ROOT/tests/m030-acceptance/run-acceptance-battery.sh"

pass=0
fail=0

if [ ! -x "$RUNNER" ] && [ ! -f "$RUNNER" ]; then
  echo "FAIL: runner missing at $RUNNER"
  echo "SUMMARY: p07-acceptance-battery-pass.sh pass=0 fail=1"
  exit 1
fi

stdout_capture="$(bash "$RUNNER")"
rc=$?

if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: runner exit 0"
else
  fail=$((fail + 1))
  echo "FAIL: runner exited $rc"
fi

last_line="$(printf '%s\n' "$stdout_capture" | tail -n 1)"
if printf '%s\n' "$last_line" | grep -qE '^BATTERY: pass=[0-9]+ fail=0$'; then
  pass=$((pass + 1))
  echo "OK: last line matches ^BATTERY: pass=N fail=0$ ($last_line)"
else
  fail=$((fail + 1))
  echo "FAIL: expected last line ^BATTERY: pass=N fail=0$; got: $last_line"
fi

echo "SUMMARY: p07-acceptance-battery-pass.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
