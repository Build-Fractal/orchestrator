#!/usr/bin/env bash
# tests/m033-acceptance/p07-resume-on-partial-state.sh
#
# SC-12 / FR-20 / CON-6 acceptance: exercises the resume-on-partial-state
# read+resume path of scripts/lifecycle/start.sh against synthetic
# markers written via scripts/util/start-state-markers.sh.
#
# Scenarios covered:
#   1. write+read+next primitives produce the documented output shape.
#   2. With this-branch's marker pre-written, start.sh emits the
#      load-bearing `start-state: resuming from <next>` diagnostic and
#      skips the sub-flow stub.
#   3. --no-resume forces the P01 baseline path (sub-flow stub fires,
#      no resume diagnostic).
#   4. With markers cleared, start.sh runs the P01 baseline (no resume
#      diagnostic, sub-flow stub fires).
#
# Bash 3.2 compatible. No process substitution, no $(...) containing
# pipes. Uses mktemp -d + EXIT trap for cleanup.
#
# Exit 0 on all-pass. Exit 1 on any failure.
#
# spec ref: FR-20 (marker convention), CON-6 (resume on partial state),
#           SC-12 (resume diagnostic acceptance).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

start_sh="$PROJECT_ROOT/scripts/lifecycle/start.sh"
markers_sh="$PROJECT_ROOT/scripts/util/start-state-markers.sh"

pass=0
fail=0

ok() {
    pass=$((pass + 1))
    echo "PASS: $1"
}

ko() {
    fail=$((fail + 1))
    echo "FAIL: $1"
}

# Pre-flight existence checks so failures point at the missing surface.
if [ ! -f "$start_sh" ]; then
    echo "FAIL: scripts/lifecycle/start.sh missing at $start_sh"
    echo "SUMMARY: p07-resume-on-partial-state.sh pass=0 fail=1"
    exit 1
fi
if [ ! -f "$markers_sh" ]; then
    echo "FAIL: scripts/util/start-state-markers.sh missing at $markers_sh"
    echo "SUMMARY: p07-resume-on-partial-state.sh pass=0 fail=1"
    exit 1
fi

staging="$(mktemp -d 2>/dev/null)"
if [ -z "$staging" ] || [ ! -d "$staging" ]; then
    echo "FAIL: could not create mktemp -d staging dir"
    echo "SUMMARY: p07-resume-on-partial-state.sh pass=0 fail=1"
    exit 1
fi
trap 'rm -rf "$staging"' EXIT

# Pre-create config.yml so invoke_init takes the idempotent skip-path.
mkdir -p "$staging/.orchestrator"
echo "schema_version: 1.0" > "$staging/.orchestrator/config.yml"

# ---------------------------------------------------------------------
# Scenario 1: primitives smoke (write / read / next).
# ---------------------------------------------------------------------

bash "$markers_sh" write init-invoked "$staging"
bash "$markers_sh" write ideation "$staging"

read_out="$staging/read.out"
bash "$markers_sh" read "$staging" > "$read_out"

read_line_count=$(wc -l < "$read_out")
read_line_count=${read_line_count// /}
if [ "$read_line_count" = "2" ]; then
    ok "read returns exactly 2 lines"
else
    ko "read line count = $read_line_count (expected 2)"
fi

read_line1=$(sed -n '1p' "$read_out")
read_line2=$(sed -n '2p' "$read_out")
if [ "$read_line1" = "init-invoked" ]; then
    ok "read line 1 is init-invoked (execution order)"
else
    ko "read line 1 = '$read_line1' (expected init-invoked)"
fi
if [ "$read_line2" = "ideation" ]; then
    ok "read line 2 is ideation (execution order)"
else
    ko "read line 2 = '$read_line2' (expected ideation)"
fi

next_out=$(bash "$markers_sh" next "$staging")
if [ "$next_out" = "materials-intake" ]; then
    ok "next returns materials-intake (execution order after ideation)"
else
    ko "next = '$next_out' (expected materials-intake)"
fi

# ---------------------------------------------------------------------
# Scenario 2: resume diagnostic fires when this-branch's marker present.
# Branch greenfield-with-materials -> this_subflow=materials-intake.
# Drop 3 PBJ-shape .md files at staging root to trigger that branch.
# ---------------------------------------------------------------------

# Idempotent fixture writes — files are in staging only, scoped to test.
echo "PBJ brief stub" > "$staging/PRODUCT-BRIEF.md"
echo "PBJ plan stub" > "$staging/MVP-PLAN.md"
echo "PBJ decisions stub" > "$staging/DECISIONS.md"

# Pre-write materials-intake.complete so resume fires.
bash "$markers_sh" write materials-intake "$staging"

run1_out="$staging/run1.out"
run1_err="$staging/run1.err"
( cd "$PROJECT_ROOT" && bash "$start_sh" --project-dir "$staging" --yes ) > "$run1_out" 2> "$run1_err"
run1_rc=$?

if [ "$run1_rc" -eq 0 ]; then
    ok "scenario 2: start.sh exited 0 with marker pre-written"
else
    ko "scenario 2: start.sh exited $run1_rc (expected 0)"
fi

if grep -qF 'start-state: resuming from' "$run1_out"; then
    ok "scenario 2: 'start-state: resuming from' diagnostic appears (SC-12 token)"
else
    ko "scenario 2: 'start-state: resuming from' diagnostic missing"
fi

if grep -qF 'start-state: resuming from ingest-codebase' "$run1_out"; then
    ok "scenario 2: resume target is ingest-codebase (next in execution order)"
else
    ko "scenario 2: resume target is not ingest-codebase"
fi

if grep -qF 'would-execute: materials-intake-stub' "$run1_out"; then
    ko "scenario 2: materials-intake-stub fired despite marker (resume failed)"
else
    ok "scenario 2: materials-intake-stub correctly skipped"
fi

# ---------------------------------------------------------------------
# Scenario 3: --no-resume forces full baseline (stub fires, no resume).
# Marker still present from scenario 2.
# ---------------------------------------------------------------------

run2_out="$staging/run2.out"
run2_err="$staging/run2.err"
( cd "$PROJECT_ROOT" && bash "$start_sh" --project-dir "$staging" --yes --no-resume ) > "$run2_out" 2> "$run2_err"
run2_rc=$?

if [ "$run2_rc" -eq 0 ]; then
    ok "scenario 3: start.sh --no-resume exited 0"
else
    ko "scenario 3: start.sh --no-resume exited $run2_rc (expected 0)"
fi

if grep -qF 'start-state: resuming from' "$run2_out"; then
    ko "scenario 3: resume diagnostic fired despite --no-resume"
else
    ok "scenario 3: --no-resume correctly suppressed resume diagnostic"
fi

if grep -qF 'would-execute: materials-intake-stub' "$run2_out"; then
    ok "scenario 3: --no-resume restored P01 baseline (stub fires)"
else
    ko "scenario 3: --no-resume did NOT restore baseline (stub missing)"
fi

# ---------------------------------------------------------------------
# Scenario 4: clear all markers, default no-marker path is P01 baseline.
# ---------------------------------------------------------------------

bash "$markers_sh" clear init-invoked "$staging"
bash "$markers_sh" clear ideation "$staging"
bash "$markers_sh" clear materials-intake "$staging"

run3_out="$staging/run3.out"
run3_err="$staging/run3.err"
( cd "$PROJECT_ROOT" && bash "$start_sh" --project-dir "$staging" --yes ) > "$run3_out" 2> "$run3_err"
run3_rc=$?

if [ "$run3_rc" -eq 0 ]; then
    ok "scenario 4: start.sh exited 0 with markers cleared"
else
    ko "scenario 4: start.sh exited $run3_rc (expected 0)"
fi

if grep -qF 'start-state: resuming from' "$run3_out"; then
    ko "scenario 4: resume diagnostic fired with no markers (false positive)"
else
    ok "scenario 4: no resume diagnostic with markers cleared"
fi

if grep -qF 'would-execute: materials-intake-stub' "$run3_out"; then
    ok "scenario 4: P01 baseline preserved (materials-intake-stub fires)"
else
    ko "scenario 4: P01 baseline broken (stub missing)"
fi

echo "SUMMARY: p07-resume-on-partial-state.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
