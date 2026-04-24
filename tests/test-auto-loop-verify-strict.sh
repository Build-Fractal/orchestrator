#!/usr/bin/env bash
# tests/test-auto-loop-verify-strict.sh — Issue #5 regression test
#
# Issue #5: M026/P02/T01 emitted AUTO:VERIFY_PASS phase=P02 task=T01
# checks_passed=0 because the plan's Verification section used a fenced
# ```bash ... ``` block, but the extractor only matched inline single
# backticks. Silent-zero PASS is the same anti-pattern visible-skip
# fixes elsewhere.
#
# Fix: extend extractor to also pull commands from fenced code blocks;
# hard-fail when the Verification section has content but the parser
# extracted zero executable commands.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTO_LOOP="$PROJECT_ROOT/scripts/lifecycle/auto-loop.sh"
FIXTURE="$PROJECT_ROOT/tests/fixtures/auto-loop-verify-strict/milestones/M999"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- T01: fenced block with two bash commands → checks_passed=2, exit 0 ---
out=$(bash "$AUTO_LOOP" "$FIXTURE" --step=V --phase=P00 --task=T01 2>&1) && rc=$? || rc=$?
if [[ "$rc" -eq 0 ]] && echo "$out" | grep -qE 'AUTO:VERIFY_PASS .*checks_passed=2'; then
  pass "T01 fenced block → checks_passed=2 (rc=$rc)"
else
  fail "T01 fenced block → checks_passed=2 (rc=$rc, output: $out)"
fi

# --- T02: prose-only Verification section → hard-fail VERIFY_NO_CHECKS ---
out=$(bash "$AUTO_LOOP" "$FIXTURE" --step=V --phase=P00 --task=T02 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "T02 prose-only Verification → non-zero exit (got rc=$rc)"
else
  fail "T02 prose-only Verification → non-zero exit (got rc=$rc, output: $out)"
fi

if echo "$out" | grep -q 'AUTO:VERIFY_NO_CHECKS'; then
  pass "T02 emits AUTO:VERIFY_NO_CHECKS marker"
else
  fail "T02 emits AUTO:VERIFY_NO_CHECKS (got: $out)"
fi

if echo "$out" | grep -qE 'inline backticks|fenced code block'; then
  pass "T02 stderr names the canonical command shapes"
else
  fail "T02 stderr names canonical shapes (got: $out)"
fi

# --- T03: no Verification section → legitimate skip, checks_passed=0, exit 0 ---
out=$(bash "$AUTO_LOOP" "$FIXTURE" --step=V --phase=P00 --task=T03 2>&1) && rc=$? || rc=$?
if [[ "$rc" -eq 0 ]] && echo "$out" | grep -qE 'AUTO:VERIFY_PASS .*checks_passed=0'; then
  pass "T03 no-Verification-section → legitimate skip (checks_passed=0, rc=0)"
else
  fail "T03 no-Verification-section → legitimate skip (rc=$rc, output: $out)"
fi

# --- T04: fenced block with `bash` language hint → command extracted ---
out=$(bash "$AUTO_LOOP" "$FIXTURE" --step=V --phase=P00 --task=T04 2>&1) && rc=$? || rc=$?
if [[ "$rc" -eq 0 ]] && echo "$out" | grep -qE 'AUTO:VERIFY_PASS .*checks_passed=1'; then
  pass "T04 fenced block with bash hint → checks_passed=1"
else
  fail "T04 fenced block with bash hint → checks_passed=1 (rc=$rc, output: $out)"
fi

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
