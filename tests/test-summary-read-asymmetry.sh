#!/usr/bin/env bash
# tests/test-summary-read-asymmetry.sh — Group 1 / paper-cut sweep
#
# Bug: when commands/plan-phase.md instructs the planner to emit
# slug-suffixed plan filenames (e.g. T01-input-audit-PLAN.md),
# write-summary.sh still emits the bare-task-id form (T01-SUMMARY.md).
# Three readers — derive-phase.sh, auto-loop.sh, recovery-briefing.sh —
# resolved `${task_id}-SUMMARY.md` literally and looked for
# T01-input-audit-SUMMARY.md, treating completed work as incomplete and
# triggering re-dispatch on iteration 1 of every Tier C run with
# slug-bearing plans.
#
# Fix: bilateral-tolerance — readers accept either the slug-suffixed form
# or the bare-task-id form (`${task_id%%-*}-SUMMARY.md`).
#
# This test stages a fixture milestone with one slug-suffixed plan + one
# bare summary and asserts:
#   1. derive-phase.sh reports a state past "executing" (T01 recognized
#      complete despite filename mismatch).
#   2. recovery-briefing.sh lists the task under completed-units.
#   3. auto-loop.sh source carries the bilateral-tolerance fallback shape.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DERIVE="$PROJECT_ROOT/scripts/state/derive-phase.sh"
RECOVERY="$PROJECT_ROOT/scripts/lifecycle/recovery-briefing.sh"
AUTO_LOOP="$PROJECT_ROOT/scripts/lifecycle/auto-loop.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- Stage fixture milestone tree ---
TMPROOT="$(mktemp -d -t papercut-summary-asymmetry.XXXXXX)"
trap 'rm -rf "$TMPROOT"' EXIT

MS_DIR="$TMPROOT/M999"
mkdir -p "$MS_DIR/phases/P01/tasks"

# Roadmap: tier C, P01 active (no P02 → no cross-phase complications).
cat >"$MS_DIR/M999-ROADMAP.md" <<'ROADMAP'
---
milestone: M999
feature_ref: "999-papercut-asymmetry"
feature_spec: "specs/999-papercut-asymmetry/spec.md"
vision: "Bilateral tolerance smoke test"
tier: C
created_at: "2026-04-29T10:00:00Z"
updated_at: "2026-04-29T10:00:00Z"
---

## Phases

- [ ] **P01**: Asymmetry Smoke — "Reader recognizes slug-suffixed plan + bare summary as complete"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: tasks/T01-input-audit-SUMMARY.md
    - Consumes: none
ROADMAP

# Phase plan present so derive-phase moves past "planning".
echo "# P01-PLAN.md (smoke)" >"$MS_DIR/phases/P01/P01-PLAN.md"

# THE asymmetry: slug-suffixed plan filename + bare summary filename.
echo "# T01-input-audit-PLAN.md (smoke)" >"$MS_DIR/phases/P01/tasks/T01-input-audit-PLAN.md"
echo "# T01-SUMMARY.md (bare-task-id form, what write-summary.sh emits)" >"$MS_DIR/phases/P01/tasks/T01-SUMMARY.md"

# --- Test 1: derive-phase.sh recognizes T01 complete → moves past "executing" ---
state="$(bash "$DERIVE" "$MS_DIR" 2>/dev/null)" || true
case "$state" in
  verifying|summarizing|validating|completing|complete)
    pass "derive-phase.sh treats slug-suffixed plan + bare summary as complete (state=$state)"
    ;;
  executing)
    fail "derive-phase.sh still treats slug-suffixed plan as incomplete (state=executing)"
    ;;
  *)
    fail "derive-phase.sh returned unexpected state: $state"
    ;;
esac

# --- Test 2: recovery-briefing.sh lists T01 under completed-units ---
brief="$(bash "$RECOVERY" "$MS_DIR" 2>/dev/null)" || true
if printf '%s\n' "$brief" | grep -qE 'P01/T01-input-audit \(summary exists\)'; then
  pass "recovery-briefing.sh lists slug-suffixed task under completed-units"
elif printf '%s\n' "$brief" | grep -qE 'P01/T01-input-audit \(plan exists, no summary\)'; then
  fail "recovery-briefing.sh still lists slug-suffixed task as incomplete"
else
  fail "recovery-briefing.sh did not surface T01-input-audit at all (brief: $brief)"
fi

# --- Test 3: auto-loop.sh source carries the bilateral-tolerance fallback shape ---
if grep -qE 'bare_task_id="\$\{task_id%%-\*\}"' "$AUTO_LOOP"; then
  pass "auto-loop.sh carries bilateral-tolerance fallback shape"
else
  fail "auto-loop.sh missing bilateral-tolerance fallback (search: bare_task_id=\${task_id%%-*})"
fi

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
