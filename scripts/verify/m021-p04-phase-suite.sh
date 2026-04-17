#!/usr/bin/env bash
# scripts/verify/m021-p04-phase-suite.sh -- Phase-level cohesion runner.
#
# Invokes run-suite.sh m021 P04 (auto-discovers scripts/verify/m021-p04-*.sh)
# AND invokes scripts/verify/replay-prompt-corpus.sh explicitly (its name
# does not match the m021-p04-* glob) plus scripts/verify/m021-p04-dogfood-attestation.sh.
# Asserts all pass.
#
# Self-recursion guard: when run-suite.sh discovers this script via its
# m021-p04-*.sh glob, we set M021_P04_SUITE_ACTIVE=1 so the nested invocation
# short-circuits with a no-op PASS (the outer invocation is the authoritative run).
#
# Exit 0 on all-pass; 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Nested invocation (from run-suite.sh inside this very suite): short-circuit
# to avoid infinite recursion. The outer invocation already covers the
# semantics this script asserts.
if [ "${M021_P04_SUITE_ACTIVE:-0}" = "1" ]; then
  echo "PASS: m021-p04-phase-suite.sh (nested no-op)"
  exit 0
fi

export M021_P04_SUITE_ACTIVE=1

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Invoke run-suite.sh m021 P04 (discovers m021-p04-*.sh gates including
# m021-p04-dogfood-attestation.sh; the nested call back into this script
# no-ops via the M021_P04_SUITE_ACTIVE guard above).
bash "${REPO_ROOT}/scripts/verify/run-suite.sh" m021 P04
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "run-suite.sh m021 P04"
else
  fail "run-suite.sh m021 P04" "rc=$rc"
fi

# Invoke replay gate explicitly (doesn't match m021-p04-* glob).
bash "${REPO_ROOT}/scripts/verify/replay-prompt-corpus.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "replay-prompt-corpus.sh"
else
  fail "replay-prompt-corpus.sh" "rc=$rc"
fi

# Invoke dogfood attestation gate explicitly (belt-and-suspenders; also
# discovered by run-suite above).
bash "${REPO_ROOT}/scripts/verify/m021-p04-dogfood-attestation.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "m021-p04-dogfood-attestation.sh"
else
  fail "m021-p04-dogfood-attestation.sh" "rc=$rc"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-phase-suite.sh"
  exit 0
fi
echo "FAIL: m021-p04-phase-suite.sh ($fail_count failures)"
exit 1
