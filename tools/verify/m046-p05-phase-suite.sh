#!/usr/bin/env sh
# tools/verify/m046-p05-phase-suite.sh — M046 P05 phase-close gate suite.
#
# Aggregates the five m046-p05 verifiers and emits one SUITE: line per member
# and a final aggregate SUMMARY line; exits 0 iff 5/5 pass. Members 4 and 5
# (sc5-write-tool-scope + sc15-verification-immutability) are NON-STUBBED,
# milestone-blocking gates that each drive a real unattended child through the
# LIVE installed production hook inside their own isolated scratch HOME, so a
# green suite proves the scope-guard hook, its install wiring, the driver policy
# composition, and both blocking safety criteria end to end. Milestone-prefixed
# name per the P00-clobber lesson; modeled on
# tools/verify/m046-p04-phase-suite.sh. Straight-line invocation per AD-19 —
# five literal `bash <path>` calls, no loop-over-array. The suite never sets or
# overrides HOME globally; each member manages its own scratch HOME.
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

bash tools/verify/m046-p05-scope-guard-deny.sh
rc=$?
emit_suite_result "$rc" "m046-p05-scope-guard-deny.sh"

bash tools/verify/m046-p05-install-wiring.sh
rc=$?
emit_suite_result "$rc" "m046-p05-install-wiring.sh"

bash tools/verify/m046-p05-driver-policy.sh
rc=$?
emit_suite_result "$rc" "m046-p05-driver-policy.sh"

bash tools/verify/m046-p05-sc5-write-tool-scope.sh
rc=$?
emit_suite_result "$rc" "m046-p05-sc5-write-tool-scope.sh"

bash tools/verify/m046-p05-sc15-verification-immutability.sh
rc=$?
emit_suite_result "$rc" "m046-p05-sc15-verification-immutability.sh"

printf 'SUMMARY: pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
