#!/usr/bin/env bash
# tools/verify/m036-p01-test-harness.sh -- M036 P01 SC-9 test-harness shape
# verifier. Asserts:
#   1. tests/test-tier-1-adapters.sh exists and is executable.
#   2. The harness runs to completion (does not crash).
#   3. The harness emits a `BATTERY:` summary line.
#
# Permissive on per-adapter PASS/SKIP counts: when host tooling is absent
# the harness SKIPs adapters and exits 0 with a lower pass count -- the
# contract here is "ran to completion + emitted BATTERY: line", not "all
# four adapters passed". The phase-suite aggregator catches per-adapter
# regressions via the per-adapter verifiers; this verifier polices the
# harness shape only.
#
# Single-script-file shape per AD-19 / AP-009.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
HARNESS="$ROOT/tests/test-tier-1-adapters.sh"
TMP="${TMPDIR:-/tmp}/m036-p01-test-harness.$$.out"
pass=0
fail=0

if [ -f "$HARNESS" ]; then
  echo "PASS: harness-exists"
  pass=$((pass + 1))
else
  echo "FAIL: harness-exists ($HARNESS not found)"
  fail=$((fail + 1))
  echo "SUMMARY: m036-p01-test-harness pass=$pass fail=$fail"
  exit 1
fi

if [ -x "$HARNESS" ]; then
  echo "PASS: harness-executable"
  pass=$((pass + 1))
else
  echo "FAIL: harness-executable ($HARNESS not -x)"
  fail=$((fail + 1))
fi

set +e
bash "$HARNESS" >"$TMP" 2>/dev/null
rc=$?
set -e

# rc may be 0 (all-pass / SKIPs only) or 1 (any FAIL). The harness running
# to completion is the contract here -- not a specific exit code -- so we
# only require rc to be 0 or 1 (i.e. the script did not abort with a
# different signal). bash exits 1 on `set -eu` violations and 2 on syntax
# errors, so accepting {0,1} captures "ran-and-emitted-BATTERY".
if [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; then
  echo "PASS: harness-ran-to-completion (rc=$rc)"
  pass=$((pass + 1))
else
  echo "FAIL: harness-ran-to-completion (rc=$rc)"
  fail=$((fail + 1))
fi

if grep -q "^BATTERY:" "$TMP"; then
  echo "PASS: harness-emits-BATTERY"
  pass=$((pass + 1))
else
  echo "FAIL: harness-emits-BATTERY (no BATTERY: line in stdout)"
  fail=$((fail + 1))
fi

rm -f "$TMP"

echo "SUMMARY: m036-p01-test-harness pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
