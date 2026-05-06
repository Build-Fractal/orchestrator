#!/usr/bin/env bash
# tools/verify/m029-p03-closure-ceremony-shape.sh
# Asserts the four closure-ceremony artifacts exist in canonical shape and
# that validate-milestone.sh M029 passes:
#   - .orchestrator/milestones/M029/M029-VALIDATED              (marker file)
#   - .orchestrator/milestones/M029/M029-SUMMARY.md             (canonical frontmatter)
#   - .orchestrator/milestones/M029/execution-log.jsonl         (milestone-grain unit_close line)
#   - bash tools/verify/m029-p03-validate-milestone-pass.sh exits 0
#
# AD-19 straight-line bash (single-script-file shape, no compound chains,
# no $() pipes). Bash 3.2 / MEM001 compatible.
#
# Per the M032 closure ceremony precedent: write-summary.sh milestone emits
# the unit_close JSONL record with `record_type:"unit_close"` (not
# `event:"unit_close"`) — assertion uses the actual emitter shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MARKER="$PROJECT_ROOT/.orchestrator/milestones/M029/M029-VALIDATED"
SUMMARY="$PROJECT_ROOT/.orchestrator/milestones/M029/M029-SUMMARY.md"
LOG="$PROJECT_ROOT/.orchestrator/milestones/M029/execution-log.jsonl"
VPV="$PROJECT_ROOT/tools/verify/m029-p03-validate-milestone-pass.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# --- Assertion 1: M029-VALIDATED marker file present.
if [ -f "$MARKER" ]; then
  pass "M029-VALIDATED marker present"
else
  fail "M029-VALIDATED marker missing at $MARKER"
fi

# --- Assertion 2: M029-SUMMARY.md present.
if [ -f "$SUMMARY" ]; then
  pass "M029-SUMMARY.md present"
else
  fail "M029-SUMMARY.md missing at $SUMMARY"
fi

# --- Assertion 3: M029-SUMMARY.md frontmatter contains canonical fields.
if [ -f "$SUMMARY" ]; then
  if grep -F -q -e 'type: milestone-summary' "$SUMMARY"; then
    pass "summary type: milestone-summary"
  else
    fail "summary missing 'type: milestone-summary'"
  fi
  if grep -F -q -e 'verification_result: "pass"' "$SUMMARY"; then
    pass "summary verification_result: pass"
  else
    fail "summary missing 'verification_result: \"pass\"'"
  fi
  if grep -F -q -e 'completed_at:' "$SUMMARY"; then
    pass "summary completed_at present"
  else
    fail "summary missing 'completed_at:'"
  fi
  if grep -F -q -e 'id: "M029"' "$SUMMARY"; then
    pass "summary id: M029"
  else
    fail "summary missing 'id: \"M029\"'"
  fi
fi

# --- Assertion 4: execution-log.jsonl carries milestone-grain unit_close.
# write-summary.sh milestone emits `"record_type":"unit_close"` +
# `"granularity":"milestone"` + `"milestone":"M029"` on the same line.
if [ -f "$LOG" ]; then
  # Extract candidate lines containing both the M029 milestone-grain marker
  # and the unit_close record_type. Use grep -F twice via tempfile (AD-19:
  # no piped substitution).
  TMP_UC="/tmp/m029-cc-uc.$$"
  trap 'rm -f "$TMP_UC"' EXIT INT TERM
  grep -F -e '"record_type":"unit_close"' "$LOG" > "$TMP_UC" 2>/dev/null || true
  if [ -s "$TMP_UC" ]; then
    if grep -F -q -e '"granularity":"milestone"' "$TMP_UC"; then
      pass "execution-log carries milestone-grain unit_close"
    else
      fail "execution-log unit_close lines lack granularity:\"milestone\""
    fi
    if grep -F -q -e '"M029"' "$TMP_UC"; then
      pass "unit_close line carries M029 substring"
    else
      fail "unit_close line missing M029 substring"
    fi
  else
    fail "execution-log has no unit_close lines"
  fi
else
  fail "execution-log.jsonl missing at $LOG"
fi

# --- Assertion 5: validate-milestone-pass verifier exists + exits 0.
if [ -x "$VPV" ]; then
  pass "validate-milestone-pass.sh present + executable"
  bash "$VPV" > /dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "validate-milestone-pass.sh exited 0"
  else
    fail "validate-milestone-pass.sh exited $rc"
  fi
else
  fail "validate-milestone-pass.sh missing at $VPV"
fi

printf 'SUMMARY: m029-p03-closure-ceremony-shape.sh pass=%d fail=%d\n' "$PASS_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -eq 0 ]; then
  exit 0
fi
exit 1
