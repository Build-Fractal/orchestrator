#!/usr/bin/env bash
# tools/verify/m029-p03-validate-milestone-pass.sh
# SC-12 hook: invoke `scripts/verify/validate-milestone.sh` on M029 and assert
# the success-shape line + exit 0. Mirrors the M032/M033 closure-ceremony
# convention: validator emits `VALIDATE: PASS — N/N checks passed` on full
# pass; this verifier asserts on that line shape, not on a literal `100%`
# string (CLAUDE.md "M032 ... validate-milestone.sh 122/122 PASS").
#
# AD-19 straight-line bash (single-script-file shape, no compound chains,
# no $() pipes). Bash 3.2 / MEM001 compatible (parallel pass/fail counters,
# no associative arrays).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

VALIDATOR="$PROJECT_ROOT/scripts/verify/validate-milestone.sh"
MILESTONE_DIR="$PROJECT_ROOT/.orchestrator/milestones/M029"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# --- Assertion 1: validator script present.
if [ -f "$VALIDATOR" ]; then
  pass "validate-milestone.sh present"
else
  fail "validate-milestone.sh missing at $VALIDATOR"
  printf 'SUMMARY: m029-p03-validate-milestone-pass.sh pass=%d fail=%d\n' "$PASS_COUNT" "$FAIL_COUNT"
  exit 1
fi

# --- Assertion 2: M029 milestone dir present.
if [ -d "$MILESTONE_DIR" ]; then
  pass "M029 milestone dir present"
else
  fail "M029 milestone dir missing at $MILESTONE_DIR"
  printf 'SUMMARY: m029-p03-validate-milestone-pass.sh pass=%d fail=%d\n' "$PASS_COUNT" "$FAIL_COUNT"
  exit 1
fi

# --- Run validator, capture stdout to tempfile (AD-19: no $(cmd | grep)).
TMP_OUT="/tmp/m029-validate-out.$$"
trap 'rm -f "$TMP_OUT"' EXIT INT TERM

bash "$VALIDATOR" "$MILESTONE_DIR" > "$TMP_OUT" 2>&1
rc=$?

# --- Assertion 3: exit code 0.
if [ "$rc" -eq 0 ]; then
  pass "validate-milestone.sh exited 0"
else
  fail "validate-milestone.sh exited $rc (expected 0)"
fi

# --- Assertion 4: success line shape `VALIDATE: PASS` present.
if grep -F -q -e 'VALIDATE: PASS' "$TMP_OUT"; then
  pass "VALIDATE: PASS line present"
else
  fail "VALIDATE: PASS line absent in validator output"
fi

# --- Assertion 5: success line carries N/N shape `checks passed`.
if grep -F -q -e 'checks passed' "$TMP_OUT"; then
  pass "checks-passed token present"
else
  fail "checks-passed token absent"
fi

# --- Assertion 6: validator output references P03 (the new phase).
if grep -F -q -e 'P03' "$TMP_OUT"; then
  pass "P03 referenced in validator output"
else
  fail "P03 not referenced in validator output"
fi

# --- Assertion 7: no FAIL — N/M lines (which would indicate failures).
if grep -F -q -e 'VALIDATE: FAIL' "$TMP_OUT"; then
  fail "VALIDATE: FAIL line present in validator output"
else
  pass "no VALIDATE: FAIL lines"
fi

printf 'SUMMARY: m029-p03-validate-milestone-pass.sh pass=%d fail=%d\n' "$PASS_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -eq 0 ]; then
  exit 0
fi
exit 1
