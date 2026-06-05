#!/usr/bin/env bash
# m043-p04-evidence-gate.sh — drives the T02 validate-evidence.sh against all
# three SC-9 branches and asserts the exit codes:
#   pass fixture     -> exit 0
#   deferred fixture -> exit 0
#   absent note      -> exit 1 (fail-closed)
# Bash 3.2; offline. The validator is a repo-resident script, invoked
# directly (NOT through run-probe.sh).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

VALIDATOR="tests/m043-acceptance/live-deploy/validate-evidence.sh"
PASS_FX="tests/m043-acceptance/live-deploy/fixtures/evidence-pass.md"
DEFER_FX="tests/m043-acceptance/live-deploy/fixtures/evidence-deferred.md"
ABSENT="/tmp/m043-p04-nonexistent-$$.md"

fail=0
pass=0

assert_exit() {
  # $1 = expected code, $2 = actual code, $3 = label
  if [ "$1" -eq "$2" ]; then
    pass=$((pass + 1))
  else
    echo "MISMATCH: $3 expected exit $1, got $2"
    fail=1
  fi
}

if bash "$VALIDATOR" "$PASS_FX" >/dev/null 2>&1; then rc=0; else rc=$?; fi
assert_exit 0 "$rc" "pass-fixture"

if bash "$VALIDATOR" "$DEFER_FX" >/dev/null 2>&1; then rc=0; else rc=$?; fi
assert_exit 0 "$rc" "deferred-fixture"

if bash "$VALIDATOR" "$ABSENT" >/dev/null 2>&1; then rc=0; else rc=$?; fi
assert_exit 1 "$rc" "absent-note"

echo "m043-p04-evidence-gate pass=$pass fail=$fail"
exit $fail
