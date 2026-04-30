#!/usr/bin/env bash
# scripts/verify/m028/p03-replay-harness-clean.sh -- M028/P03/T05 plan-level
# verifier for the truth: "the replay harness `tests/run-prompt-corpus-replay.sh`
# exists, parses the 27 entries, runs each through the classifier + hook
# end-to-end, asserts every actual verdict equals the expected verdict, and
# exits 0 only on 27/27 match (no regression on the 20 pre-existing
# entries; FR-22 / SC-8)".
#
# Asserts:
#   1. The harness file exists and is executable.
#   2. The harness exits 0.
#   3. The harness final-line contract holds: stdout contains the literal
#      "WOULD_PROMPT=0/27" line.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
HARNESS="${REPO_ROOT}/tests/run-prompt-corpus-replay.sh"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

if [ ! -f "$HARNESS" ]; then
  fail "harness exists" "missing at $HARNESS"
  echo "FAIL: 1 check(s) failed in p03-replay-harness-clean.sh"
  exit 1
fi
pass "harness exists at tests/run-prompt-corpus-replay.sh"

if [ ! -x "$HARNESS" ]; then
  fail "harness executable" "not +x at $HARNESS"
fi

_out="$(mktemp)"
bash "$HARNESS" > "$_out" 2>&1
_rc=$?

if [ "$_rc" -eq 0 ]; then
  pass "harness exits 0 (27/27 corpus match)"
else
  _tail="$(tail -5 "$_out")"
  fail "harness exits 0" "rc=$_rc tail=[$_tail]"
fi

if grep -qF "WOULD_PROMPT=0/27" "$_out"; then
  pass "harness emits canonical WOULD_PROMPT=0/27"
else
  _wp="$(grep -F 'WOULD_PROMPT=' "$_out" | head -1)"
  fail "WOULD_PROMPT=0/27 line" "saw [$_wp]"
fi

rm -f "$_out"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p03-replay-harness-clean.sh"
  exit 0
fi
echo "FAIL: $fail_count check(s) failed in p03-replay-harness-clean.sh"
exit 1
