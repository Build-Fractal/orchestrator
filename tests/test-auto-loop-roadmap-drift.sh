#!/usr/bin/env bash
# tests/test-auto-loop-roadmap-drift.sh — Issue #3 regression test
#
# auto-loop.sh previously trusted derive-phase.sh's output without
# cross-checking that roadmap checkboxes agreed with phase-summary
# existence on disk. M026 entered a session with P01 complete on disk
# but - [ ] in the roadmap, and derive-phase returned "planning" —
# which would have routed auto to re-plan an already-planned phase.
#
# Fix: at the top of the pre-dispatch loop, run sync-roadmap in
# read-only mode. If SYNC:MISMATCH appears, refuse to advance and
# surface the recovery command.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTO_LOOP="$PROJECT_ROOT/scripts/lifecycle/auto-loop.sh"
FIXTURE_MILESTONE="$PROJECT_ROOT/tests/fixtures/auto-loop-drift/milestones/M999"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- Drift case: roadmap=[ ] but disk has P00-SUMMARY.md ---
output=$(bash "$AUTO_LOOP" "$FIXTURE_MILESTONE" 2>&1) && rc=$? || rc=$?

if [[ "$rc" -eq 12 ]]; then
  pass "auto-loop exits 12 on roadmap drift (got rc=$rc)"
else
  fail "auto-loop exits 12 on roadmap drift (got rc=$rc, output: $output)"
fi

if echo "$output" | grep -q 'AUTO:ROADMAP_DRIFT'; then
  pass "drift output emits AUTO:ROADMAP_DRIFT marker"
else
  fail "drift output emits AUTO:ROADMAP_DRIFT (got: $output)"
fi

if echo "$output" | grep -q 'phase=P00'; then
  pass "drift output names the mismatched phase (P00)"
else
  fail "drift output names mismatched phase (got: $output)"
fi

if echo "$output" | grep -q 'sync-roadmap.*--fix'; then
  pass "drift output names the --fix recovery command"
else
  fail "drift output names --fix recovery (got: $output)"
fi

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
