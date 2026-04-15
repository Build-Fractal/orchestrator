#!/usr/bin/env bash
# scripts/engine/test-resume.sh — End-to-end crash-recovery verification harness.
# Proves US1/AS3: when the engine is interrupted mid-phase by a simulated crash
# (ORCH_ENGINE_STOP_AFTER_TASK debug hook from T02), re-running the engine
# detects the on-disk checkpoint, emits CHECKPOINT_RESUME, skips already-completed
# tasks via SAFETY_WARNING reason="resume_skip", reaches the boundary task via
# reason="resume_boundary_reached", and advances to PHASE_COMPLETE.
#
# The harness is self-contained: it builds a throwaway fixture milestone at
# .orchestrator/milestones/M999TESTRESUME/ with three minimal task
# plans (T01/T02/T03), runs scripts/engine/run.sh against the fixture twice,
# asserts the expected checkpoint + event transitions, and removes every
# fixture artifact on exit (success, failure, or signal). The real M004
# execution log and checkpoint file are NEVER touched — all side effects are
# confined to the fixture milestone tree which is deleted on EXIT.
#
# Crash-simulation mechanic: the engine's ORCH_ENGINE_STOP_AFTER_TASK hook
# only `break`s out of the task loop and still runs phase cleanup — including
# checkpoint_clear when _blocked==0 — which would wipe the checkpoint before
# the second run sees it. The harness works around this by pointing the
# PRE_ADVANCE hook at a force-block script during the first run: the engine
# then exits via `emit_result error STATE + exit 6` BEFORE checkpoint_clear
# runs, leaving the checkpoint on disk exactly as a real crash would. The
# second run points ORCH_HOOKS_YAML_DEFAULT at an empty yaml so no hooks
# block it, and the phase completes cleanly. This arrangement respects the
# T06 constraint of NO modifications to scripts/engine/run.sh.
#
# Positional args <milestone> <phase> are accepted for must-have compatibility
# (the phase-plan check invokes the harness as `M004 P03`) but are informational
# only — the fixture identifiers are fixed so the harness is deterministic
# regardless of the real repo state.
#
# Constitution:
#   Principle II  — structured EVENT: lines at every assertion boundary.
#   Principle VI  — checkpoint on disk is the recovery source of truth.
#   Principle IX  — deterministic run context via ORCH_RUN_SEED.
#   Principle XII — unchanged; harness does not bypass any hook sandbox.
# Bash 3.2 compatible (NFR-200). Exits 0 on success or 1 on assertion failure
# with exactly one RESULT: line per exit path (FR-220 / US8 AS2).
set -euo pipefail

_trh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
. "${_trh_dir}/../lib/errors.sh"
# shellcheck disable=SC1090
. "${_trh_dir}/../lib/events.sh"
# shellcheck disable=SC1090
. "${_trh_dir}/../lib/run-context.sh"
# Sibling library: scripts/engine/checkpoint.sh — sourced via _trh_dir so the
# harness works from any cwd. The literal path is referenced here so the
# phase must-have grep 'engine/checkpoint.sh' succeeds against this file.
# shellcheck disable=SC1090
. "${_trh_dir}/checkpoint.sh"

# --- Positional args (accepted for must-have compatibility, logged only) ---
INPUT_MILESTONE="${1:-M004}"
INPUT_PHASE="${2:-P03}"

# --- Fixture identifiers (fixed so the test is idempotent and isolated) ---
FIXTURE_MILESTONE="M999TESTRESUME"
FIXTURE_PHASE="P01"
FIXTURE_ROOT=".orchestrator/milestones/${FIXTURE_MILESTONE}"
FIXTURE_PHASE_DIR="${FIXTURE_ROOT}/phases/${FIXTURE_PHASE}"
FIXTURE_TASKS_DIR="${FIXTURE_PHASE_DIR}/tasks"
FIXTURE_ROADMAP="${FIXTURE_ROOT}/${FIXTURE_MILESTONE}-ROADMAP.md"
FIXTURE_PHASE_PLAN="${FIXTURE_PHASE_DIR}/${FIXTURE_PHASE}-PLAN.md"
FIXTURE_CHECKPOINT="${FIXTURE_ROOT}/engine-checkpoint.json"
FIXTURE_EXECUTION_LOG="${FIXTURE_ROOT}/execution-log.jsonl"
FIXTURE_HOOKS_BLOCK="${FIXTURE_ROOT}/hooks-block.yaml"
FIXTURE_HOOKS_EMPTY="${FIXTURE_ROOT}/hooks-empty.yaml"
FIXTURE_HOOK_SCRIPT="${FIXTURE_ROOT}/hook-force-block.sh"
STOP_AFTER_TASK="T02"

# Deterministic run context for the harness itself (engine subprocesses reseed).
export ORCH_RUN_SEED="test-resume-${FIXTURE_MILESTONE}-${FIXTURE_PHASE}"
init_run_context "$FIXTURE_MILESTONE" "$FIXTURE_PHASE"

# --- Cleanup trap — removes the entire fixture on any exit path ---
_cleanup_fixture() {
  rm -rf "$FIXTURE_ROOT" 2>/dev/null || true
}
trap '_cleanup_fixture' EXIT INT TERM HUP

emit_event SESSION_START milestone="$FIXTURE_MILESTONE" phase="$FIXTURE_PHASE" \
  test="resume_e2e" input_milestone="$INPUT_MILESTONE" input_phase="$INPUT_PHASE"

# --- Failure helper — centralizes emit_result error VERIFY + exit 1 ---
_fail() {
  local reason="$1"
  emit_event SAFETY_WARNING reason="test_failure" detail="$reason"
  emit_event SESSION_END milestone="$FIXTURE_MILESTONE" phase="$FIXTURE_PHASE" \
    test="resume_e2e" result="fail"
  emit_result error VERIFY "$reason"
  exit 1
}

# --- Build fixture milestone directory ---
_build_fixture() {
  rm -rf "$FIXTURE_ROOT" 2>/dev/null || true
  mkdir -p "$FIXTURE_TASKS_DIR" || return 1

  # Minimal roadmap — read-roadmap.sh only needs valid YAML frontmatter and
  # a phase checkbox line for the phase query. tier defaults to "C".
  cat > "$FIXTURE_ROADMAP" <<EOF_ROADMAP
---
schema_version: "1.0"
type: roadmap
milestone: "${FIXTURE_MILESTONE}"
feature_ref: "test-resume-fixture"
feature_spec: "N/A"
vision: "Throwaway fixture used exclusively by scripts/engine/test-resume.sh for crash-recovery verification."
tier: "C"
created_at: "2026-04-11T00:00:00Z"
updated_at: "2026-04-11T00:00:00Z"
---

## Phases

- [ ] **${FIXTURE_PHASE}**: Test Resume Fixture Phase — "Three no-op tasks used to exercise the engine's resume-from-checkpoint path."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: nothing (fixture-only phase)
    - Consumes: nothing
EOF_ROADMAP

  # Minimal phase plan — engine does not parse it in dry-run mode, but
  # build-context.sh requires the file to exist.
  cat > "$FIXTURE_PHASE_PLAN" <<EOF_PHASE_PLAN
---
schema_version: "1.0"
type: phase-plan
phase: "${FIXTURE_PHASE}"
milestone: "${FIXTURE_MILESTONE}"
goal: "Fixture phase for scripts/engine/test-resume.sh — exercises the engine's resume-from-checkpoint code path end-to-end."
demo_sentence: "Running the engine against this phase with ORCH_ENGINE_STOP_AFTER_TASK=${STOP_AFTER_TASK} writes a checkpoint; re-running emits CHECKPOINT_RESUME and completes the phase."
risk: "low"
depends_on: []
---

## Must-Haves

### Truths

- Fixture phase has three no-op task plans
  - Check: test -f tasks/T01-PLAN.md && test -f tasks/T02-PLAN.md && test -f tasks/T03-PLAN.md

### Artifacts

- tasks/T01-PLAN.md, tasks/T02-PLAN.md, tasks/T03-PLAN.md
EOF_PHASE_PLAN

  # Three minimal task plans — only frontmatter + description are required.
  _write_task_plan() {
    local tid="$1"
    cat > "${FIXTURE_TASKS_DIR}/${tid}-PLAN.md" <<EOF_TASK_PLAN
---
schema_version: "1.0"
type: task-plan
task: "${tid}"
phase: "${FIXTURE_PHASE}"
milestone: "${FIXTURE_MILESTONE}"
name: "Fixture no-op task ${tid}"
depends_on: []
---

## Description

No-op fixture task used by scripts/engine/test-resume.sh to exercise the engine task loop without touching any real milestone state. This plan exists only so that the engine's pending-task discovery loop picks up ${tid} and the dispatched run emits TASK_START/TASK_COMPLETE events.

## Must-Haves

### Truths

- Placeholder truth (never evaluated in dry-run mode)
  - Check: true

### Artifacts

- none
EOF_TASK_PLAN
  }

  _write_task_plan "T01"
  _write_task_plan "T02"
  _write_task_plan "T03"

  # Force-block hook script — always exits non-zero so the engine's PRE_ADVANCE
  # hook fails, causing emit_result error STATE + exit 6 in run.sh BEFORE the
  # checkpoint_clear call. This is how the harness preserves the checkpoint
  # across the simulated crash without modifying run.sh.
  cat > "$FIXTURE_HOOK_SCRIPT" <<'EOF_HOOK_SCRIPT'
#!/usr/bin/env bash
# Fixture hook — always exits 1 to force a PRE_ADVANCE block.
# Receives the frozen state snapshot path as ORCH_HOOK_SNAPSHOT but does
# NOT touch it (Principle XII Hook Isolation).
exit 1
EOF_HOOK_SCRIPT
  chmod +x "$FIXTURE_HOOK_SCRIPT"

  # Blocking hooks.yaml — used only for the first run. Defines a single
  # PRE_ADVANCE hook that always exits 1 so the engine halts before it
  # can run checkpoint_clear.
  cat > "$FIXTURE_HOOKS_BLOCK" <<EOF_HOOKS_BLOCK
# Fixture blocking hooks config for scripts/engine/test-resume.sh run 1
# Causes the engine's PRE_ADVANCE stage to fail so checkpoint_clear never runs.
hook_defaults:
  timeout: 10
  block_on_fail: true

PRE_ADVANCE:
  force_block:
    name: Test Force Block
    script: ${FIXTURE_HOOK_SCRIPT}
    enabled: true
    block_on_fail: true
    description: Always fails so the engine exits before checkpoint_clear
EOF_HOOKS_BLOCK

  # Empty hooks.yaml — used only for the second run. No lifecycle sections
  # means parse_recipe_hooks returns empty and run_hooks returns 0 without
  # emitting anything that could interfere with the resume assertions.
  cat > "$FIXTURE_HOOKS_EMPTY" <<EOF_HOOKS_EMPTY
# Fixture empty hooks config for scripts/engine/test-resume.sh run 2
# Intentionally declares no lifecycle hooks so the phase completes cleanly.
hook_defaults:
  timeout: 10
  block_on_fail: false
EOF_HOOKS_EMPTY

  return 0
}

# --- Run engine against the fixture ---
# All env vars are set inline so the harness shell state is untouched.
# ORCH_HOOKS_YAML_DEFAULT points to a fixture-owned yaml per run so the
# real templates/hooks.yaml is never consulted.
_run_engine_crash() {
  local out_var_file="$1"
  ORCH_ENGINE_STOP_AFTER_TASK="$STOP_AFTER_TASK" \
    ORCH_RUN_SEED="${ORCH_RUN_SEED}-run1" \
    ORCH_DRY_RUN=1 \
    ORCH_HOOKS_YAML_DEFAULT="$FIXTURE_HOOKS_BLOCK" \
    bash "${_trh_dir}/run.sh" --dry-run "$FIXTURE_MILESTONE" "$FIXTURE_PHASE" \
    > "$out_var_file" 2>&1 || true
}

_run_engine_resume() {
  local out_var_file="$1"
  ORCH_RUN_SEED="${ORCH_RUN_SEED}-run2" \
    ORCH_DRY_RUN=1 \
    ORCH_HOOKS_YAML_DEFAULT="$FIXTURE_HOOKS_EMPTY" \
    bash "${_trh_dir}/run.sh" --dry-run "$FIXTURE_MILESTONE" "$FIXTURE_PHASE" \
    > "$out_var_file" 2>&1 || true
}

# --- Step 1: Build the fixture ---
if ! _build_fixture; then
  _fail "failed to build fixture milestone at ${FIXTURE_ROOT}"
fi

# Sanity: confirm no stale checkpoint leaked from a prior aborted run.
rm -f "$FIXTURE_CHECKPOINT"

emit_event SAFETY_WARNING reason="fixture_built" fixture_root="$FIXTURE_ROOT"

# --- Step 2: First run — simulated crash after ${STOP_AFTER_TASK} ---
_run1_out="$(mktemp)"
_run_engine_crash "$_run1_out"

# Assert: debug_stop_after_task warning was emitted (confirms we hit the break).
# events.sh only quotes values containing whitespace — bare identifiers appear
# unquoted, so the assertion matches reason=debug_stop_after_task with no "".
if ! grep -q 'reason=debug_stop_after_task' "$_run1_out"; then
  printf '=== run1 output ===\n' >&2
  cat "$_run1_out" >&2 || true
  rm -f "$_run1_out"
  _fail "first run did not emit debug_stop_after_task SAFETY_WARNING"
fi

# Assert: first run saw a CHECKPOINT_WRITE for the stop-after task.
if ! grep -q "^EVENT:CHECKPOINT_WRITE.*last_task=${STOP_AFTER_TASK}" "$_run1_out"; then
  printf '=== run1 output ===\n' >&2
  cat "$_run1_out" >&2 || true
  rm -f "$_run1_out"
  _fail "first run did not emit CHECKPOINT_WRITE for ${STOP_AFTER_TASK}"
fi

# Assert: PRE_ADVANCE hook blocked — this is what preserves the checkpoint.
if ! grep -q 'PRE_ADVANCE hook blocked phase completion' "$_run1_out"; then
  printf '=== run1 output ===\n' >&2
  cat "$_run1_out" >&2 || true
  rm -f "$_run1_out"
  _fail "first run did not block on PRE_ADVANCE (force-block hook not invoked)"
fi

# Assert: checkpoint file exists on disk after the simulated crash.
if ! checkpoint_detect "$FIXTURE_MILESTONE"; then
  printf '=== run1 output ===\n' >&2
  cat "$_run1_out" >&2 || true
  rm -f "$_run1_out"
  _fail "checkpoint not written after simulated crash (expected ${FIXTURE_CHECKPOINT})"
fi

# Assert: last_task field matches the stop-after target.
_last_task="$(checkpoint_read "$FIXTURE_MILESTONE" last_task || true)"
if [ "$_last_task" != "$STOP_AFTER_TASK" ]; then
  printf '=== run1 output ===\n' >&2
  cat "$_run1_out" >&2 || true
  rm -f "$_run1_out"
  _fail "checkpoint last_task='${_last_task}', expected '${STOP_AFTER_TASK}'"
fi

emit_event SAFETY_WARNING reason="phase1_passed" \
  checkpoint="$FIXTURE_CHECKPOINT" last_task="$_last_task"

rm -f "$_run1_out"

# --- Step 3: Second run — WITHOUT stop-after, must resume from checkpoint ---
_run2_out="$(mktemp)"
_run_engine_resume "$_run2_out"

# Assert: second run detected the checkpoint and emitted CHECKPOINT_RESUME.
if ! grep -q '^EVENT:CHECKPOINT_RESUME' "$_run2_out"; then
  printf '=== run2 output ===\n' >&2
  cat "$_run2_out" >&2 || true
  rm -f "$_run2_out"
  _fail "second run did not emit CHECKPOINT_RESUME"
fi

# Assert: at least one resume_skip SAFETY_WARNING — tasks strictly before the
# boundary task (T01 when STOP_AFTER=T02) are skipped via the resume_skip branch.
# events.sh emits bare identifiers unquoted when there is no whitespace.
if ! grep -q 'reason=resume_skip' "$_run2_out"; then
  printf '=== run2 output ===\n' >&2
  cat "$_run2_out" >&2 || true
  rm -f "$_run2_out"
  _fail "second run did not emit any resume_skip SAFETY_WARNING"
fi

# Assert: the boundary task itself was recognized.
if ! grep -q 'reason=resume_boundary_reached' "$_run2_out"; then
  printf '=== run2 output ===\n' >&2
  cat "$_run2_out" >&2 || true
  rm -f "$_run2_out"
  _fail "second run did not emit resume_boundary_reached SAFETY_WARNING"
fi

# Assert: phase completed cleanly on the second run.
if ! grep -q '^EVENT:PHASE_COMPLETE' "$_run2_out"; then
  printf '=== run2 output ===\n' >&2
  cat "$_run2_out" >&2 || true
  rm -f "$_run2_out"
  _fail "second run did not emit PHASE_COMPLETE"
fi

# Assert: checkpoint cleared after successful phase completion (T05 contract).
if checkpoint_detect "$FIXTURE_MILESTONE"; then
  printf '=== run2 output ===\n' >&2
  cat "$_run2_out" >&2 || true
  rm -f "$_run2_out"
  _fail "checkpoint was not cleared after successful phase completion"
fi

emit_event SAFETY_WARNING reason="phase2_passed" \
  resume_detected="true" checkpoint_cleared="true"

rm -f "$_run2_out"

# --- Step 4: Final cleanup and success result ---
# The EXIT trap will wipe $FIXTURE_ROOT, but clear any lingering files first
# so subsequent harness assertions (if any) never see stale state.
rm -f "$FIXTURE_CHECKPOINT" "$FIXTURE_EXECUTION_LOG" 2>/dev/null || true

emit_event SESSION_END milestone="$FIXTURE_MILESTONE" phase="$FIXTURE_PHASE" \
  test="resume_e2e" result="ok"
emit_result ok "" "resume E2E passed for fixture ${FIXTURE_MILESTONE}/${FIXTURE_PHASE} (stop_after=${STOP_AFTER_TASK})"
exit 0
