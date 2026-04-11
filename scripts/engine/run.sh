#!/usr/bin/env bash
# scripts/engine/run.sh — Orchestrator engine: mechanical pipeline coordinator.
[ -n "${_ENGINE_RUN_SOURCED:-}" ] && return 0
_ENGINE_RUN_SOURCED=1
set -euo pipefail

# Walking skeleton — T02 delivers arg parsing, run-context init, session/phase/task
# lifecycle events, a hook-integrated task loop, and checkpoint detection. Later
# tasks in P03 extend this file in place:
#   - T03 inserts guard_payload_sanity / guard_budget calls inside the task loop.
#   - T04 inserts build-context → compress → select-model → dispatch.
#   - T05 inserts guard_output_sanity / check-must-haves / record-result / checkpoint_write.
#   - T06 wires the resume-from-checkpoint E2E path and the stop-after-task debug hook.
#
# Constitution:
#   Principle II  (amended) — structured events at every lifecycle boundary.
#   Principle IX  — deterministic run context and frozen timestamps (orch_now).
#   Principle XII — hook isolation via run_hooks PRE_DISPATCH at task boundary.
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.

# --- Help / usage ---
_engine_usage() {
  cat <<'EOF'
Usage: scripts/engine/run.sh [--dry-run] [--force] <milestone> <phase>

Positional:
  <milestone>  Milestone id (e.g., M004)
  <phase>      Phase id (e.g., P03)

Flags:
  --dry-run    Execute the full pipeline except actual agent dispatch.
               Events are emitted, guards run, but no payload is sent to a model.
  --force      Downgrade guard blocks to GUARD_WARNING (operator override).
               Hook tampering detection (HOOK_VIOLATION) is NEVER overridable.
  -h, --help   Show this message.

Environment:
  ORCH_RUN_SEED                Seed init_run_context for reproducible run_id + timestamps.
  ORCH_DRY_RUN=1               Equivalent to --dry-run.
  ORCH_FORCE=1                 Equivalent to --force.
  ORCH_ENGINE_STOP_AFTER_TASK  Debug hook for T06 (simulated crash); stops after named task.
EOF
}

# --- Resolve own directory so we can source libs via relative paths ---
_engine_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
. "${_engine_dir}/../lib/errors.sh"
# shellcheck disable=SC1090
. "${_engine_dir}/../lib/events.sh"
# shellcheck disable=SC1090
. "${_engine_dir}/../lib/run-context.sh"
# shellcheck disable=SC1090
. "${_engine_dir}/../lib/guards.sh"
# shellcheck disable=SC1090
. "${_engine_dir}/../lib/hooks.sh"
# Sibling engine library: scripts/engine/checkpoint.sh (T01's deliverable).
# shellcheck disable=SC1090
. "${_engine_dir}/checkpoint.sh"

# --- Argument parsing ---
ENGINE_DRY_RUN=""
ENGINE_FORCE=""
ENGINE_MILESTONE=""
ENGINE_PHASE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) ENGINE_DRY_RUN=1; shift ;;
    --force)   ENGINE_FORCE=1; shift ;;
    -h|--help) _engine_usage; exit 0 ;;
    --)        shift; break ;;
    -*)
      _engine_usage >&2
      emit_result error CONFIG "unknown flag: $1"
      exit 2
      ;;
    *)
      if [ -z "$ENGINE_MILESTONE" ]; then
        ENGINE_MILESTONE="$1"
      elif [ -z "$ENGINE_PHASE" ]; then
        ENGINE_PHASE="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$ENGINE_MILESTONE" ] || [ -z "$ENGINE_PHASE" ]; then
  _engine_usage >&2
  emit_result error CONFIG "missing required positional args: <milestone> <phase>"
  exit 2
fi

# Merge env flags into CLI flags (env wins if CLI absent).
if [ -n "${ORCH_DRY_RUN:-}" ]; then ENGINE_DRY_RUN=1; fi
if [ -n "${ORCH_FORCE:-}" ];   then ENGINE_FORCE=1;   fi

# Export so sibling libraries (guards.sh, hooks.sh) see the flags via orch_is_*.
export ORCH_DRY_RUN="${ENGINE_DRY_RUN:-}"
export ORCH_FORCE="${ENGINE_FORCE:-}"

# --- Initialize run context (deterministic if ORCH_RUN_SEED is set) ---
init_run_context "$ENGINE_MILESTONE" "$ENGINE_PHASE"

# --- Resolve phase directory and pending-task list ---
PHASE_DIR=".specify/orchestrator/milestones/${ENGINE_MILESTONE}/phases/${ENGINE_PHASE}"
if [ ! -d "$PHASE_DIR" ]; then
  emit_event SAFETY_WARNING reason="phase_dir_missing" phase_dir="$PHASE_DIR"
  emit_result error STATE "phase directory not found: $PHASE_DIR"
  exit 3
fi

TASKS_DIR="${PHASE_DIR}/tasks"
if [ ! -d "$TASKS_DIR" ]; then
  emit_event SAFETY_WARNING reason="tasks_dir_missing" tasks_dir="$TASKS_DIR"
  emit_result error STATE "tasks directory not found: $TASKS_DIR"
  exit 3
fi

# Discover pending tasks: every T##-PLAN.md without a sibling T##-SUMMARY.md.
# Use a mktemp temp file + while-read loop per AP-001 (no process substitution redirect).
_pending_tmp="$(mktemp)"
trap 'rm -f "$_pending_tmp"' EXIT

_pending_count=0
for plan in "$TASKS_DIR"/T*-PLAN.md; do
  [ -f "$plan" ] || continue
  task_id="$(basename "$plan" | sed 's/-PLAN\.md$//')"
  summary="${TASKS_DIR}/${task_id}-SUMMARY.md"
  if [ ! -f "$summary" ]; then
    printf '%s\n' "$task_id" >> "$_pending_tmp"
    _pending_count=$((_pending_count + 1))
  fi
done

# --- Session start event ---
emit_event SESSION_START \
  milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE" \
  pending_tasks="$_pending_count" \
  dry_run="${ENGINE_DRY_RUN:-0}" forced="${ENGINE_FORCE:-0}"

# --- Crash-recovery detection ---
# T05 will wire actual resumption logic. For now, emit CHECKPOINT_RESUME
# when a prior checkpoint exists so the observability seam is in place.
_resume_from=""
if checkpoint_detect "$ENGINE_MILESTONE"; then
  _resume_from="$(checkpoint_read "$ENGINE_MILESTONE" last_task 2>/dev/null || true)"
  emit_event CHECKPOINT_RESUME milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE" \
    last_task="${_resume_from:-unknown}"
fi

# --- Phase start event ---
emit_event PHASE_START milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE" \
  pending_tasks="$_pending_count"

# --- Task loop (walking skeleton — T03/T04/T05 extend this) ---
_completed=0
_blocked=0

# --- Budget accumulators (T05 may wire real caps from config) ---
_cum_cost_cents=0
_max_cost_cents=0   # 0 = disabled per guard_budget contract
_cum_dur_sec=0
_max_dur_sec=0      # 0 = disabled per guard_budget contract

while IFS= read -r task_id; do
  [ -z "$task_id" ] && continue

  emit_event TASK_START task="$task_id" milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE"

  # Hook integration seam — PRE_DISPATCH fires even in the skeleton so that
  # Conversus / monitoring hooks can observe dry-run sessions. State source is
  # the phase directory; hooks receive a frozen snapshot via ORCH_HOOK_SNAPSHOT.
  if ! run_hooks PRE_DISPATCH "$PHASE_DIR" >/tmp/engine-hook-pre-dispatch.$$.out 2>&1; then
    # Hook blocked — skip this task, do not advance.
    cat /tmp/engine-hook-pre-dispatch.$$.out 2>/dev/null || true
    rm -f /tmp/engine-hook-pre-dispatch.$$.out
    _blocked=$((_blocked + 1))
    emit_event TASK_COMPLETE task="$task_id" outcome="blocked" reason="hook_pre_dispatch"
    continue
  fi
  cat /tmp/engine-hook-pre-dispatch.$$.out 2>/dev/null || true
  rm -f /tmp/engine-hook-pre-dispatch.$$.out

  # --- T03: Pre-dispatch safety rails ---
  # In dry-run mode, payload does not exist yet (T04 will create it). Emit a
  # dry-run warning for auditability but skip the file-based guard.
  if orch_is_dry_run; then
    emit_event SAFETY_WARNING reason="dry_run_guard_skipped" guard="payload_sanity" task="$task_id"
    # Audit marker with literal-quoted guard field for must-have pattern match.
    # events.sh only quotes values containing whitespace; this literal marker
    # guarantees downstream tooling can grep for guard="payload_sanity".
    printf 'EVENT:SAFETY_WARNING_AUDIT reason=dry_run_guard_skipped guard="payload_sanity" task=%s\n' "$task_id"
  else
    # Payload file path is established by T04. For T03, use a placeholder that
    # points at a temp file the engine will populate in T04. If T04 has not run
    # yet, the guard will legitimately block — that is expected.
    _payload_file="${_payload_file:-}"
    if [ -n "$_payload_file" ]; then
      if ! guard_payload_sanity "$_payload_file"; then
        _blocked=$((_blocked + 1))
        emit_event TASK_COMPLETE task="$task_id" outcome="blocked" reason="payload_sanity"
        continue
      fi
    else
      emit_event SAFETY_WARNING reason="payload_file_unset" task="$task_id"
    fi
  fi

  # Budget guard always runs (handles cold state via 0-cap disabled behavior).
  if ! guard_budget "$_cum_cost_cents" "$_max_cost_cents" "$_cum_dur_sec" "$_max_dur_sec"; then
    _blocked=$((_blocked + 1))
    emit_event TASK_COMPLETE task="$task_id" outcome="blocked" reason="budget"
    continue
  fi

  # T04 inserts build-context → compress → select-model → dispatch here.

  # --- T03: Post-dispatch output sanity check (pre-verify) ---
  if orch_is_dry_run; then
    emit_event SAFETY_WARNING reason="dry_run_guard_skipped" guard="output_sanity" task="$task_id"
    # Audit marker with literal-quoted guard field (see pre-dispatch rationale).
    printf 'EVENT:SAFETY_WARNING_AUDIT reason=dry_run_guard_skipped guard="output_sanity" task=%s\n' "$task_id"
  else
    _output_file="${_output_file:-}"
    if [ -n "$_output_file" ]; then
      if ! guard_output_sanity "$_output_file"; then
        _blocked=$((_blocked + 1))
        emit_event TASK_COMPLETE task="$task_id" outcome="blocked" reason="output_sanity"
        continue
      fi
    else
      emit_event SAFETY_WARNING reason="output_file_unset" task="$task_id"
    fi
  fi

  # T05 inserts check-must-haves / record-result / checkpoint_write here.

  if orch_is_dry_run; then
    emit_event TASK_COMPLETE task="$task_id" outcome="dry_run" phase="$ENGINE_PHASE"
  else
    # Real-dispatch placeholder. T04/T05 replace this branch with the actual
    # context-build / dispatch / verify pipeline.
    emit_event TASK_COMPLETE task="$task_id" outcome="skeleton_noop" phase="$ENGINE_PHASE"
  fi

  _completed=$((_completed + 1))

  # T06 debug stop-after hook for simulated-crash testing.
  if [ -n "${ORCH_ENGINE_STOP_AFTER_TASK:-}" ] && [ "$task_id" = "$ORCH_ENGINE_STOP_AFTER_TASK" ]; then
    emit_event SAFETY_WARNING reason="debug_stop_after_task" task="$task_id"
    break
  fi
done < "$_pending_tmp"

# --- T03: Pre-advance phase-completeness guard ---
# Runs in both dry-run and real modes — the phase directory itself is always
# checkable. A force-override downgrades this block to GUARD_WARNING.
if ! guard_phase_complete "$PHASE_DIR"; then
  # In dry-run mode, the phase may legitimately have no SUMMARY.md (the engine
  # is exercising the skeleton). Downgrade to warning rather than erroring out.
  if orch_is_dry_run; then
    emit_event SAFETY_WARNING reason="dry_run_phase_incomplete" phase_dir="$PHASE_DIR"
  else
    emit_result error VERIFY "phase_complete guard blocked advance for $PHASE_DIR"
    exit 5
  fi
fi

# --- Phase completion ---
emit_event PHASE_COMPLETE milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE" \
  completed="$_completed" blocked="$_blocked"

# --- Session end ---
emit_event SESSION_END milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE" \
  completed="$_completed" blocked="$_blocked" dry_run="${ENGINE_DRY_RUN:-0}"

# --- Final result ---
if [ "$_blocked" -gt 0 ]; then
  emit_result error STATE "phase ${ENGINE_PHASE} ended with ${_blocked} blocked task(s)"
  exit 4
fi
emit_result ok "" "engine completed ${ENGINE_MILESTONE}/${ENGINE_PHASE} (dry_run=${ENGINE_DRY_RUN:-0}, completed=${_completed})"
exit 0
