#!/usr/bin/env bash
# scripts/verify/m019-p01-additive-compat.sh — M019/P01 additive-compat gate.
#
# Asserts that pre-M019 execution-log records (no `record_type` field) still
# validate against scripts/verify/m019-schema.sh (SC-10 additivity) AND that
# scripts/state/derive-phase.sh runs against a milestone directory whose log
# is seeded with the pre-M019 fixture without error.
#
# Emits one PASS: or FAIL: line on stdout. Exit 0 on all-pass, 1 otherwise.
#
# MEM004 carve-out: pipes/$()/awk permitted.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA="$REPO_ROOT/scripts/verify/m019-schema.sh"
DERIVE="$REPO_ROOT/scripts/state/derive-phase.sh"
FIXTURE_LOG="$REPO_ROOT/tests/fixtures/m019-p01/pre-m019-execution-log.jsonl"
FIXTURE_MILESTONE="$REPO_ROOT/tests/fixtures/m019-p01/fixture-milestone"

VALID_STATES="pre-planning discussing planning replanning executing verifying summarizing validating completing complete blocked paused crashed"

fail_count=0

if [ ! -r "$FIXTURE_LOG" ]; then
  printf 'FAIL: m019-p01-additive-compat.sh pre-m019-fixture-missing at=%s\n' "$FIXTURE_LOG"
  exit 1
fi

# Gate 1: schema validator must accept pre-M019 records (additivity).
if ! bash "$SCHEMA" "$FIXTURE_LOG" >/dev/null 2>&1; then
  printf 'FAIL: m019-p01-additive-compat.sh schema-rejects-pre-m019 file=%s\n' "$FIXTURE_LOG"
  fail_count=$(( fail_count + 1 ))
fi

# Gate 2: derive-phase.sh runs against a milestone whose log is seeded with
# the pre-M019 fixture. We copy the fixture milestone tree to a temp dir,
# overlay the pre-M019 log, and assert the script exits 0 with a known state.
TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT INT TERM

# Copy fixture milestone tree
cp -R "$FIXTURE_MILESTONE" "$TMPROOT/M999" 2>/dev/null || true
# Seed pre-M019 log
cp "$FIXTURE_LOG" "$TMPROOT/M999/execution-log.jsonl" 2>/dev/null || true

state_out=""
state_rc=0
state_out="$(bash "$DERIVE" "$TMPROOT/M999" 2>/dev/null)" || state_rc=$?

if [ "$state_rc" -ne 0 ]; then
  printf 'FAIL: m019-p01-additive-compat.sh derive-phase-exit=%d\n' "$state_rc"
  fail_count=$(( fail_count + 1 ))
else
  matched=0
  for st in $VALID_STATES; do
    if [ "$state_out" = "$st" ]; then
      matched=1
      break
    fi
  done
  if [ "$matched" -ne 1 ]; then
    printf 'FAIL: m019-p01-additive-compat.sh derive-phase-unknown-state=%s\n' "$state_out"
    fail_count=$(( fail_count + 1 ))
  fi
fi

if [ "$fail_count" -gt 0 ]; then
  printf 'FAIL: m019-p01-additive-compat.sh %d gate(s) failed\n' "$fail_count"
  exit 1
fi

printf 'PASS: m019-p01-additive-compat.sh schema + derive-phase accept pre-M019 log\n'
exit 0
