#!/usr/bin/env bash
# scripts/verify/m021-p04-dogfood-attestation.sh -- AD-8 dogfood attestation.
#
# Asserts M021's own orchestrator:auto execution of P01-P04 observed:
#   (a) auto-loop marker present and non-empty
#   (b) execution-log.jsonl has no user_prompt / safety_prompt /
#       hook_reject_unexpected events (hook_reject_recovered is tolerated --
#       those are the AD-6 designed recovery path, not prompts)
#   (c) every present P*-SUMMARY.md records verification_result: pass
#
# Exit 0 on all-pass; 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
M021_DIR="${REPO_ROOT}/.orchestrator/milestones/M021"
AUTO_LOOP="${M021_DIR}/auto-loop-result.txt"
EXEC_LOG="${M021_DIR}/execution-log.jsonl"
PHASES_DIR="${M021_DIR}/phases"
CORPUS="${REPO_ROOT}/tests/fixtures/m021-prompt-corpus.txt"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# --- Landmark: P04 reached T01 (corpus fixture exists) ---
if [ -f "$CORPUS" ]; then
  pass "landmark: tests/fixtures/m021-prompt-corpus.txt present (P04/T01 reached)"
else
  fail "landmark: corpus fixture" "missing at $CORPUS"
fi

# --- Check (a): auto-loop marker ---
if [ -f "$AUTO_LOOP" ] && [ -s "$AUTO_LOOP" ]; then
  pass "check-a: auto-loop marker present and non-empty"
else
  fail "check-a: auto-loop marker" "missing or empty at $AUTO_LOOP"
fi

# --- Check (b): no prompt events in execution log ---
# Tolerant of hook_reject_recovered events (AD-6 designed recovery path).
if [ -f "$EXEC_LOG" ]; then
  _b_clean=1
  for needle in '"event":"user_prompt"' '"event":"safety_prompt"' '"event":"hook_reject_unexpected"'; do
    if grep -qF "$needle" "$EXEC_LOG"; then
      fail "check-b: no prompt events" "found [$needle] in $EXEC_LOG"
      _b_clean=0
    fi
  done
  if [ "$_b_clean" -eq 1 ]; then
    pass "check-b: no prompt events in execution-log.jsonl"
  fi
else
  fail "check-b: execution log" "missing at $EXEC_LOG"
fi

# --- Check (c): every present P*-SUMMARY.md records verification_result: pass ---
_c_clean=1
_c_found=0
for summary in "$PHASES_DIR"/P*/P*-SUMMARY.md; do
  if [ ! -f "$summary" ]; then
    continue  # glob fell through, no summaries yet
  fi
  _c_found=$((_c_found + 1))
  if grep -qE '^verification_result: *"?pass"?' "$summary"; then
    pass "check-c: $(basename "$(dirname "$summary")") verified pass"
  else
    fail "check-c: $(basename "$(dirname "$summary")") verification_result" "not 'pass' in $summary"
    _c_clean=0
  fi
done
if [ "$_c_clean" -eq 1 ] && [ "$_c_found" -ge 1 ]; then
  pass "check-c: every present phase summary records verification_result: pass"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-dogfood-attestation.sh"
  exit 0
fi
echo "FAIL: m021-p04-dogfood-attestation.sh ($fail_count failures)"
exit 1
