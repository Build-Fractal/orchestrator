#!/usr/bin/env sh
# m046-p02-marker-exit-contract.sh (M046 SC-9, milestone-blocking)
# NON-STUBBED full-exit-set battery: fixture milestone trees drive the REAL
# scripts/lifecycle/auto-loop.sh to every exit code in its contract, asserting
# BOTH the observed exit code AND the exact marker content per case (the dual
# assertion is the anti-false-pass mechanism — a fixture drifting to the wrong
# exit code fails loud instead of green-lighting a wrong mapping). Every case
# runs against a fresh scratch copy of its checked-in tree under
# tests/fixtures/m046-p02/exit-trees/ (auto-loop mutates milestone trees).
#
# Probe-pass findings (2026-07-13; recorded per the T03 plan-time honesty rule):
#   - budget (exit 2): auto-loop.sh calls read-config.sh with NO file args, so
#     `.orchestrator/config.yml` is NOT consulted for dispatch_budget — the
#     layer-1 env override SPECKIT_ORCHESTRATOR_DISPATCH_BUDGET is the only
#     live config source on this path. The case sets it to 1 against a log
#     with one `"event":"dispatch"` record (the canonical fixture record shape
#     budget-checker.sh's literal '"dispatch"' grep matches; the
#     record-result.sh shape with only `dispatch_method` does NOT match).
#   - stuck (exit 3): two `"event":"dispatch"` records for MFIX/P01/T01 with
#     no `"success"` token; budget env vars are explicitly unset so Step B
#     passes with "no limits configured".
#   - rotate (exit 14): --step=X + sibling orchestrator.lock with
#     startedAt=2020 (all 3 outcome-bearing log records count; weight=3) +
#     SPECKIT_ORCHESTRATOR_SESSION_WEIGHT_LIMIT=1 → CONTEXT:ROTATE.
#   - planning-ok (exit 0 AUTO:PLANNING): tree nested as root/milestones/MFIX
#     so ORCH_ROOT (= milestone-dir/../..) contains milestones/; build-context
#     PHASE_PLAN succeeds end-to-end, degrading gracefully on the missing
#     optional inputs (knowledge index / context draft / feature spec).
#   - planning-failed (exit 13): same nesting, NO roadmap but phases/ present
#     → derive-phase yields `planning`, build-context fails on the missing
#     roadmap → AUTO:PLANNING_FAILED.
#   - drift (exit 12): roadmap [x] P01 with no P01-SUMMARY.md trips the
#     sync-roadmap drift guard before derive-phase.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AUTO_LOOP="$REPO_ROOT/scripts/lifecycle/auto-loop.sh"
TREES="$REPO_ROOT/tests/fixtures/m046-p02/exit-trees"

[ -f "$AUTO_LOOP" ] || { echo "FAIL: auto-loop.sh not found: $AUTO_LOOP"; exit 1; }
[ -d "$TREES" ]     || { echo "FAIL: exit-trees fixture dir not found: $TREES"; exit 1; }

passes=0
fails=0

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# stage <case> — fresh scratch copy of the whole case dir; returns nothing.
# The marker is removed defensively so a stale checked-in marker can never
# satisfy an assertion (Principle II: only the live run may write it).
stage() {
  rm -rf "$scratch/$1"
  cp -R "$TREES/$1" "$scratch/$1"
  rm -f "$scratch/$1/MFIX/.self-continue-outcome" \
        "$scratch/$1/root/milestones/MFIX/.self-continue-outcome" 2>/dev/null || true
}

# assert_case <name> <want-rc> <got-rc> <marker-file> <want-marker>
assert_case() {
  _name="$1"; _want_rc="$2"; _got_rc="$3"; _marker_file="$4"; _want_marker="$5"
  if [ "$_got_rc" -ne "$_want_rc" ]; then
    echo "FAIL: case=$_name expected exit $_want_rc, got $_got_rc"
    fails=$((fails + 1))
    return 0
  fi
  if [ ! -f "$_marker_file" ]; then
    echo "FAIL: case=$_name exit=$_got_rc marker file missing (expected '$_want_marker')"
    fails=$((fails + 1))
    return 0
  fi
  _got_marker="$(cat "$_marker_file")"
  if [ "$_got_marker" = "$_want_marker" ]; then
    echo "PASS: case=$_name exit=$_got_rc marker=$_got_marker"
    passes=$((passes + 1))
  else
    echo "FAIL: case=$_name exit=$_got_rc marker: expected '$_want_marker', got '$_got_marker'"
    fails=$((fails + 1))
  fi
}

# --- Case 1: planning-ok — planning state, build-context PHASE_PLAN succeeds ---
stage planning-ok
mdir="$scratch/planning-ok/root/milestones/MFIX"
rc=0
env -u SPECKIT_ORCHESTRATOR_DISPATCH_BUDGET -u SPECKIT_ORCHESTRATOR_DURATION_BUDGET \
    -u SPECKIT_ORCHESTRATOR_SESSION_WEIGHT_LIMIT \
    ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$mdir" >/dev/null 2>&1 || rc=$?
assert_case planning-ok 0 "$rc" "$mdir/.self-continue-outcome" "planning P01"

# --- Case 2: phase-complete — all task summaries, no phase summary ---
stage phase-complete
mdir="$scratch/phase-complete/MFIX"
rc=0
env -u SPECKIT_ORCHESTRATOR_DISPATCH_BUDGET -u SPECKIT_ORCHESTRATOR_DURATION_BUDGET \
    ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$mdir" >/dev/null 2>&1 || rc=$?
assert_case phase-complete 0 "$rc" "$mdir/.self-continue-outcome" "phase_complete P01"

# --- Case 3: validating — roadmap all [x], summaries present, no VALIDATED ---
stage validating
mdir="$scratch/validating/MFIX"
rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$mdir" >/dev/null 2>&1 || rc=$?
assert_case validating 0 "$rc" "$mdir/.self-continue-outcome" "validating"

# --- Case 4: err-args — --step=G without --task, exit 1 ---
stage err-args
mdir="$scratch/err-args/MFIX"
rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$mdir" --step=G >/dev/null 2>&1 || rc=$?
assert_case err-args 1 "$rc" "$mdir/.self-continue-outcome" "error"

# --- Case 5: budget — executing tree + 1 dispatch record + env budget=1 ---
stage budget
mdir="$scratch/budget/MFIX"
rc=0
env -u SPECKIT_ORCHESTRATOR_DURATION_BUDGET \
    ORCHESTRATOR_SELF_CONTINUE_MARKER=1 SPECKIT_ORCHESTRATOR_DISPATCH_BUDGET=1 \
  bash "$AUTO_LOOP" "$mdir" >/dev/null 2>&1 || rc=$?
assert_case budget 2 "$rc" "$mdir/.self-continue-outcome" "budget"

# --- Case 6: stuck — 2 failure dispatches for next task's unit, no budget env ---
stage stuck
mdir="$scratch/stuck/MFIX"
rc=0
env -u SPECKIT_ORCHESTRATOR_DISPATCH_BUDGET -u SPECKIT_ORCHESTRATOR_DURATION_BUDGET \
    ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$mdir" >/dev/null 2>&1 || rc=$?
assert_case stuck 3 "$rc" "$mdir/.self-continue-outcome" "stuck"

# --- Case 7: complete — MFIX-VALIDATED present, exit 10 ---
stage complete
mdir="$scratch/complete/MFIX"
rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$mdir" >/dev/null 2>&1 || rc=$?
assert_case complete 10 "$rc" "$mdir/.self-continue-outcome" "complete"

# --- Case 8: pause — pause-requested file in milestone dir, exit 11 ---
stage pause
mdir="$scratch/pause/MFIX"
rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$mdir" >/dev/null 2>&1 || rc=$?
assert_case pause 11 "$rc" "$mdir/.self-continue-outcome" "pause"

# --- Case 9: drift — roadmap [x] with no phase summary, exit 12 ---
stage drift
mdir="$scratch/drift/MFIX"
rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$mdir" >/dev/null 2>&1 || rc=$?
assert_case drift 12 "$rc" "$mdir/.self-continue-outcome" "unexpected_state"

# --- Case 10: planning-failed — planning state, build-context fails, exit 13 ---
stage planning-failed
mdir="$scratch/planning-failed/root/milestones/MFIX"
rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$mdir" >/dev/null 2>&1 || rc=$?
assert_case planning-failed 13 "$rc" "$mdir/.self-continue-outcome" "planning_failed"

# --- Case 11: rotate — --step=X, lock + heavy log + env weight limit, exit 14 ---
# Word-wise assertion per the task plan: word 1 must be `rotation`, word 2 the
# active phase (P01), asserted separately.
stage rotate
mdir="$scratch/rotate/MFIX"
rc=0
env -u SPECKIT_ORCHESTRATOR_DISPATCH_BUDGET -u SPECKIT_ORCHESTRATOR_DURATION_BUDGET \
    ORCHESTRATOR_SELF_CONTINUE_MARKER=1 SPECKIT_ORCHESTRATOR_SESSION_WEIGHT_LIMIT=1 \
  bash "$AUTO_LOOP" "$mdir" --step=X >/dev/null 2>&1 || rc=$?
marker_file="$mdir/.self-continue-outcome"
if [ "$rc" -ne 14 ]; then
  echo "FAIL: case=rotate expected exit 14, got $rc"
  fails=$((fails + 1))
elif [ ! -f "$marker_file" ]; then
  echo "FAIL: case=rotate exit=14 marker file missing (expected 'rotation P01')"
  fails=$((fails + 1))
else
  marker_raw="$(cat "$marker_file")"
  word1="$(printf '%s' "$marker_raw" | awk '{print $1}')"
  word2="$(printf '%s' "$marker_raw" | awk '{print $2}')"
  if [ "$word1" = "rotation" ] && [ "$word2" = "P01" ]; then
    echo "PASS: case=rotate exit=14 marker=$marker_raw (word1=rotation word2=P01)"
    passes=$((passes + 1))
  else
    echo "FAIL: case=rotate marker words: expected 'rotation'+'P01', got '$word1'+'$word2'"
    fails=$((fails + 1))
  fi
fi

echo "SUMMARY: pass=$passes fail=$fails"
if [ "$fails" -eq 0 ]; then
  exit 0
else
  exit 1
fi
