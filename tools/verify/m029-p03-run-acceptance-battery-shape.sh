#!/usr/bin/env bash
# tools/verify/m029-p03-run-acceptance-battery-shape.sh
# Shape verifier for the M029 milestone-grain acceptance battery (SC-11):
# asserts the script body chains all three per-phase batteries + the SC-12
# validator hook + emits the canonical `BATTERY: pass=<N> fail=<M>` line.
# Plus a behavioural run that asserts `BATTERY: pass=14 fail=0` exit 0.
#
# AD-19 straight-line bash (single-script-file shape; per-assertion grep -F
# on captured tempfile, not piped substitution). Bash 3.2 / MEM001.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BATTERY="$PROJECT_ROOT/tests/m029-acceptance/run-acceptance-battery.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# --- Assertion 1: battery script present + executable.
if [ -x "$BATTERY" ]; then
  pass "run-acceptance-battery.sh present + executable"
else
  fail "run-acceptance-battery.sh missing or not executable at $BATTERY"
  printf 'SUMMARY: m029-p03-run-acceptance-battery-shape.sh pass=%d fail=%d\n' "$PASS_COUNT" "$FAIL_COUNT"
  exit 1
fi

# --- Body-shape assertions: each per-phase battery + validator hook referenced.
if grep -F -q -e 'p01-acceptance-battery.sh' "$BATTERY"; then
  pass "P01 battery referenced"
else
  fail "P01 battery reference missing"
fi

if grep -F -q -e 'p02-acceptance-battery.sh' "$BATTERY"; then
  pass "P02 battery referenced"
else
  fail "P02 battery reference missing"
fi

if grep -F -q -e 'p03-acceptance-battery.sh' "$BATTERY"; then
  pass "P03 battery referenced"
else
  fail "P03 battery reference missing"
fi

if grep -F -q -e 'm029-p03-validate-milestone-pass.sh' "$BATTERY"; then
  pass "SC-12 validator hook referenced"
else
  fail "SC-12 validator hook reference missing"
fi

# --- Assertion: canonical BATTERY: line literal present in body.
if grep -F -q -e 'BATTERY: pass=' "$BATTERY"; then
  pass "BATTERY: pass= literal present"
else
  fail "BATTERY: pass= literal missing"
fi

# --- Assertion: SC accounting comment references pass=14 milestone-grain count.
if grep -F -q -e 'Total: 14' "$BATTERY"; then
  pass "Total: 14 SC accounting comment present"
else
  fail "Total: 14 SC accounting comment missing"
fi

# --- Behavioural run: invoke battery, capture output, assert BATTERY: pass=14 fail=0 exit 0.
TMP_OUT="/tmp/m029-rab-out.$$"
trap 'rm -f "$TMP_OUT"' EXIT INT TERM

bash "$BATTERY" > "$TMP_OUT" 2>&1
rc=$?

if [ "$rc" -eq 0 ]; then
  pass "battery exited 0"
else
  fail "battery exited $rc (expected 0)"
fi

if grep -F -q -e 'BATTERY: pass=14 fail=0' "$TMP_OUT"; then
  pass "BATTERY: pass=14 fail=0 emitted"
else
  fail "BATTERY: pass=14 fail=0 not emitted"
fi

printf 'SUMMARY: m029-p03-run-acceptance-battery-shape.sh pass=%d fail=%d\n' "$PASS_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -eq 0 ]; then
  exit 0
fi
exit 1
