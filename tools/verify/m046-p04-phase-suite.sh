#!/usr/bin/env sh
# tools/verify/m046-p04-phase-suite.sh — M046 P04 phase-close gate suite.
#
# Aggregates the nine m046-p04 verifiers and emits one SUITE: line per member
# and a final aggregate SUMMARY line; exits 0 iff 9/9 pass. Member 9
# (m046-p04-attended-parity.sh) itself carries the four M045/P02 driver
# regressions, so a green suite proves both the new unattended envelope and the
# unchanged attended path (FR-17). Milestone-prefixed name per the P00-clobber
# lesson; modeled on tools/verify/m046-p02-phase-suite.sh. Straight-line
# invocation per AD-19 — nine literal `bash <path>` calls, no loop-over-array.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

pass=0
fail=0

emit_suite_result() {
  rc="$1"
  name="$2"
  if [ "$rc" -eq 0 ]; then
    pass=$(( pass + 1 ))
    printf 'SUITE: %s PASS\n' "$name"
  else
    fail=$(( fail + 1 ))
    printf 'SUITE: %s FAIL\n' "$name"
  fi
}

bash tools/verify/m046-p04-envelope-unit.sh
rc=$?
emit_suite_result "$rc" "m046-p04-envelope-unit.sh"

bash tools/verify/m046-p04-fail-closed.sh
rc=$?
emit_suite_result "$rc" "m046-p04-fail-closed.sh"

bash tools/verify/m046-p04-budget-kill.sh
rc=$?
emit_suite_result "$rc" "m046-p04-budget-kill.sh"

bash tools/verify/m046-p04-reserve-spend.sh
rc=$?
emit_suite_result "$rc" "m046-p04-reserve-spend.sh"

bash tools/verify/m046-p04-stop-file-live.sh
rc=$?
emit_suite_result "$rc" "m046-p04-stop-file-live.sh"

bash tools/verify/m046-p04-thrash.sh
rc=$?
emit_suite_result "$rc" "m046-p04-thrash.sh"

bash tools/verify/m046-p04-wall-clock.sh
rc=$?
emit_suite_result "$rc" "m046-p04-wall-clock.sh"

bash tools/verify/m046-p04-docs-shape.sh
rc=$?
emit_suite_result "$rc" "m046-p04-docs-shape.sh"

bash tools/verify/m046-p04-attended-parity.sh
rc=$?
emit_suite_result "$rc" "m046-p04-attended-parity.sh"

printf 'SUMMARY: pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
