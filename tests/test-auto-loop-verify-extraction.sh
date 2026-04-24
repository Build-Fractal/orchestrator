#!/usr/bin/env bash
# tests/test-auto-loop-verify-extraction.sh — Bug G regression test
#
# Bug G: scripts/lifecycle/auto-loop.sh --step=V used `sed -n '/.../\|/.../'`
# (BRE alternation) to extract the Must-Haves / Verification section from a
# task plan. BSD sed on macOS does not support `\|` alternation in BRE, so
# verify_section was empty and the verifier silently emitted
#   AUTO:VERIFY_PASS phase=... task=... checks_passed=0
# for every task — masking real failures.
#
# Fix: switch the section extractor to ERE (`sed -nE`) so the alternation
# works on both GNU and BSD sed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTO_LOOP="$PROJECT_ROOT/scripts/lifecycle/auto-loop.sh"
FIXTURE_MILESTONE="$PROJECT_ROOT/tests/fixtures/auto-loop-verify-extraction/milestones/M999"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- Test 1: bbt-companion-shaped plan with 2 Check lines → checks_passed=2 ---
output=$(bash "$AUTO_LOOP" "$FIXTURE_MILESTONE" --step=V --phase=P00 --task=T01 2>&1) && rc=$? || rc=$?
if [[ "$rc" -eq 0 ]] && echo "$output" | grep -qE 'AUTO:VERIFY_PASS .*checks_passed=2'; then
  pass "two inline-backtick Check lines extracted (checks_passed=2)"
else
  fail "two inline-backtick Check lines extracted (rc=$rc, output: $output)"
fi

# --- Test 2: One failing Check → AUTO:VERIFY_FAIL with correct counts ---
output=$(bash "$AUTO_LOOP" "$FIXTURE_MILESTONE" --step=V --phase=P00 --task=T02 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]] && echo "$output" | grep -qE 'AUTO:VERIFY_FAIL .*checks_passed=1 checks_failed=1'; then
  pass "failing Check flips verdict to AUTO:VERIFY_FAIL (1 pass, 1 fail)"
else
  fail "failing Check flips verdict to AUTO:VERIFY_FAIL (rc=$rc, output: $output)"
fi

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
