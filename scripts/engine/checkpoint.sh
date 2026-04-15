#!/usr/bin/env bash
# scripts/engine/checkpoint.sh — Atomic engine checkpoint read/write/detect.
[ -n "${_CHECKPOINT_SOURCED:-}" ] && return 0
_CHECKPOINT_SOURCED=1

# Source this file to get:
#   - checkpoint_path <milestone>          — echoes the checkpoint file path
#   - checkpoint_write <milestone> <phase> <task> <outcome>
#   - checkpoint_read <milestone> <field>  — field in: run_id|milestone|phase|last_task|outcome|timestamp
#   - checkpoint_detect <milestone>        — returns 0 if a checkpoint exists, 1 otherwise
#   - checkpoint_clear <milestone>         — removes the checkpoint file (called on full phase success)
#
# Emits:
#   EVENT:CHECKPOINT_WRITE   on every successful checkpoint_write
#   (caller of checkpoint_read emits CHECKPOINT_RESUME — this library only persists state)
#
# Constitution:
#   Principle VI (State On Disk Is Truth) — the checkpoint is the handoff between crashed runs.
#   Principle IX (Reproducibility) — timestamps come from orch_now (ORCH_STARTED_AT).
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.

_checkpoint_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
. "${_checkpoint_dir}/../lib/errors.sh"
# shellcheck disable=SC1090
. "${_checkpoint_dir}/../lib/events.sh"
# shellcheck disable=SC1090
. "${_checkpoint_dir}/../lib/run-context.sh"

# --- Configuration ---
ORCH_CHECKPOINT_ROOT="${ORCH_CHECKPOINT_ROOT:-.orchestrator/milestones}"

# _checkpoint_escape <string>
# Minimal JSON string escaping: backslash, double-quote, control chars → space.
_checkpoint_escape() {
  local s="$1"
  s="$(printf '%s' "$s" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
  s="$(printf '%s' "$s" | tr '\n' ' ' | tr '\r' ' ' | tr '\t' ' ')"
  printf '%s' "$s"
}

# checkpoint_path <milestone>
# Returns the absolute-ish path to the checkpoint JSON file for the milestone.
checkpoint_path() {
  local milestone="$1"
  if [ -z "$milestone" ]; then
    return 1
  fi
  printf '%s/%s/engine-checkpoint.json\n' "$ORCH_CHECKPOINT_ROOT" "$milestone"
}

# checkpoint_write <milestone> <phase> <task> <outcome>
# Writes atomically: build temp file, mv into place. Emits CHECKPOINT_WRITE.
checkpoint_write() {
  local milestone="$1"
  local phase="$2"
  local task="$3"
  local outcome="${4:-success}"

  if [ -z "$milestone" ] || [ -z "$phase" ] || [ -z "$task" ]; then
    emit_event SAFETY_WARNING reason="checkpoint_write_missing_args" \
      milestone="${milestone:-<empty>}" phase="${phase:-<empty>}" task="${task:-<empty>}"
    return 1
  fi

  local cp
  cp="$(checkpoint_path "$milestone")"
  local cp_dir
  cp_dir="$(dirname "$cp")"
  if [ ! -d "$cp_dir" ]; then
    mkdir -p "$cp_dir" 2>/dev/null || {
      emit_event SAFETY_WARNING reason="checkpoint_mkdir_failed" path="$cp_dir"
      return 1
    }
  fi

  local run_id ts
  run_id="${ORCH_RUN_ID:-unset}"
  ts="$(orch_now)"

  local esc_run_id esc_milestone esc_phase esc_task esc_outcome esc_ts
  esc_run_id="$(_checkpoint_escape "$run_id")"
  esc_milestone="$(_checkpoint_escape "$milestone")"
  esc_phase="$(_checkpoint_escape "$phase")"
  esc_task="$(_checkpoint_escape "$task")"
  esc_outcome="$(_checkpoint_escape "$outcome")"
  esc_ts="$(_checkpoint_escape "$ts")"

  local tmp="${cp}.tmp.$$"
  {
    printf '{\n'
    printf '  "run_id": "%s",\n'    "$esc_run_id"
    printf '  "milestone": "%s",\n' "$esc_milestone"
    printf '  "phase": "%s",\n'     "$esc_phase"
    printf '  "last_task": "%s",\n' "$esc_task"
    printf '  "outcome": "%s",\n'   "$esc_outcome"
    printf '  "timestamp": "%s"\n'  "$esc_ts"
    printf '}\n'
  } > "$tmp" 2>/dev/null || {
    rm -f "$tmp"
    emit_event SAFETY_WARNING reason="checkpoint_write_failed" path="$tmp"
    return 1
  }

  mv "$tmp" "$cp" 2>/dev/null || {
    rm -f "$tmp"
    emit_event SAFETY_WARNING reason="checkpoint_mv_failed" path="$cp"
    return 1
  }

  emit_event CHECKPOINT_WRITE milestone="$milestone" phase="$phase" \
    last_task="$task" outcome="$outcome" path="$cp"
  return 0
}

# checkpoint_read <milestone> <field>
# field is one of: run_id, milestone, phase, last_task, outcome, timestamp.
# Prints the value to stdout or returns 1 if the checkpoint or field is missing.
checkpoint_read() {
  local milestone="$1"
  local field="$2"

  if [ -z "$milestone" ] || [ -z "$field" ]; then
    return 1
  fi

  local cp
  cp="$(checkpoint_path "$milestone")"
  if [ ! -f "$cp" ]; then
    return 1
  fi

  # Parse: "field": "value"  — allow leading whitespace and optional trailing comma.
  local line
  line="$(grep -E "\"${field}\"[[:space:]]*:" "$cp" 2>/dev/null | head -1)"
  if [ -z "$line" ]; then
    return 1
  fi
  # Strip up to the colon, then strip quotes and trailing comma.
  line="${line#*:}"
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*,[[:space:]]*$//' \
    -e 's/^"//' -e 's/"$//')"
  printf '%s\n' "$line"
  return 0
}

# checkpoint_detect <milestone>
# Returns 0 if a non-empty checkpoint file exists for the milestone, 1 otherwise.
checkpoint_detect() {
  local milestone="$1"
  if [ -z "$milestone" ]; then
    return 1
  fi
  local cp
  cp="$(checkpoint_path "$milestone")"
  [ -s "$cp" ]
}

# checkpoint_clear <milestone>
# Removes the checkpoint file for the milestone. Safe to call when no checkpoint exists.
checkpoint_clear() {
  local milestone="$1"
  if [ -z "$milestone" ]; then
    return 1
  fi
  local cp
  cp="$(checkpoint_path "$milestone")"
  rm -f "$cp" 2>/dev/null
  return 0
}
