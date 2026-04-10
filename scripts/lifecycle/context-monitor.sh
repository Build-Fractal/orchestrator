#!/usr/bin/env bash
# scripts/lifecycle/context-monitor.sh — Session context weight estimator
# Computes a heuristic "session weight" from the execution log, filtered to
# entries created after the current session started (from lock file). Used by
# auto-loop.sh --step=X to decide whether to rotate to a fresh context before
# starting the next phase.
#
# Weight units (proxy for orchestrator context consumption):
#   - Task dispatch cycle:    +1 per dispatch (recorded in execution log)
#   - Retry (attempt > 1):    +1 extra per retry
#   - Phase transition:       +3 per completed phase (verification + summary + reassessment)
#
# Note: Planning dispatches contribute to orchestrator context but are not
# recorded in the execution log, so they are not counted here. The conservative
# default limit (15) accounts for this underestimation.
#
# Usage: context-monitor.sh <execution-log> <lock-file> [--roadmap <roadmap-file>] [--limit N]
#
# Arguments:
#   <execution-log>     Path to JSONL execution log
#   <lock-file>         Path to orchestrator lock file (for session start time)
#   --roadmap <file>    Roadmap file for next-phase task estimate (optional)
#   --limit N           Session weight limit override (default: 15)
#
# Structured output (stdout):
#   CONTEXT:OK weight=<N> limit=<L> headroom=<H>
#   CONTEXT:ROTATE weight=<N> limit=<L> next_est=<E> reason=<msg>
#
# Always exits 0 (status is informational).
# Exits 1 only for missing required arguments.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../util/json-field.sh"

# --- Argument parsing ---
if [[ $# -lt 2 ]]; then
  echo "context-monitor.sh: requires <execution-log> <lock-file> [options]" >&2
  echo "Usage: context-monitor.sh <execution-log> <lock-file> [--roadmap <file>] [--limit N]" >&2
  exit 1
fi

EXECUTION_LOG="$1"
LOCK_FILE="$2"
shift 2

ROADMAP_FILE=""
WEIGHT_LIMIT=15

while [[ $# -gt 0 ]]; do
  case "$1" in
    --roadmap)
      if [[ $# -lt 2 ]]; then
        echo "context-monitor.sh: --roadmap requires a file path" >&2
        exit 1
      fi
      ROADMAP_FILE="$2"
      shift 2
      ;;
    --limit)
      if [[ $# -lt 2 ]]; then
        echo "context-monitor.sh: --limit requires a value" >&2
        exit 1
      fi
      WEIGHT_LIMIT="$2"
      shift 2
      ;;
    *)
      echo "context-monitor.sh: unknown option '$1'" >&2
      exit 1
      ;;
  esac
done

# --- Get session start time from lock file ---
if [[ ! -f "$LOCK_FILE" ]]; then
  # No lock = no session tracking possible, report OK
  echo "CONTEXT:OK weight=0 limit=$WEIGHT_LIMIT headroom=$WEIGHT_LIMIT"
  exit 0
fi

session_start=$(json_field "$LOCK_FILE" "startedAt")
if [[ -z "$session_start" ]]; then
  echo "CONTEXT:OK weight=0 limit=$WEIGHT_LIMIT headroom=$WEIGHT_LIMIT"
  exit 0
fi

# --- Handle missing or empty execution log ---
if [[ ! -f "$EXECUTION_LOG" ]] || [[ ! -s "$EXECUTION_LOG" ]]; then
  echo "CONTEXT:OK weight=0 limit=$WEIGHT_LIMIT headroom=$WEIGHT_LIMIT"
  exit 0
fi

# --- Count session metrics from execution log ---
# Filter entries to those after session start time.
# Timestamps are ISO 8601 (lexicographically sortable).
session_dispatches=0
session_retries=0
session_phases=""
prev_phase=""

while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  # Extract timestamp from the log entry
  entry_ts=$(echo "$line" | grep -oE '"timestamp"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | sed 's/.*"\([^"]*\)"$/\1/' || true)
  [[ -z "$entry_ts" ]] && continue

  # Skip entries from before this session
  if [[ "$entry_ts" < "$session_start" ]]; then
    continue
  fi

  # Count dispatches (any entry with an outcome is a dispatch result)
  if echo "$line" | grep -qE '"outcome"'; then
    session_dispatches=$((session_dispatches + 1))
  fi

  # Count retries (attempt > 1)
  attempt_val=$(echo "$line" | grep -oE '"attempt"[[:space:]]*:[[:space:]]*[0-9]+' \
    | grep -oE '[0-9]+$' || true)
  if [[ -n "$attempt_val" ]] && [[ "$attempt_val" -gt 1 ]]; then
    session_retries=$((session_retries + 1))
  fi

  # Track distinct phases for transition counting
  entry_phase=$(echo "$line" | grep -oE '"phase"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | sed 's/.*"\([^"]*\)"$/\1/' || true)
  if [[ -n "$entry_phase" && "$entry_phase" != "$prev_phase" ]]; then
    session_phases="${session_phases} ${entry_phase}"
    prev_phase="$entry_phase"
  fi
done < "$EXECUTION_LOG"

# Count phase transitions (distinct phases - 1, minimum 0)
phase_count=0
for p in $session_phases; do
  phase_count=$((phase_count + 1))
done
phase_transitions=$((phase_count > 1 ? phase_count - 1 : 0))

# --- Compute session weight ---
# Each dispatch: +1, each retry: +1 extra, each phase transition: +3
weight=$((session_dispatches + session_retries + (phase_transitions * 3)))

headroom=$((WEIGHT_LIMIT - weight))
if [[ $headroom -lt 0 ]]; then
  headroom=0
fi

# --- Estimate next phase cost ---
next_phase_est=0

if [[ -n "$ROADMAP_FILE" && -f "$ROADMAP_FILE" ]]; then
  READ_ROADMAP="$SCRIPT_DIR/../state/read-roadmap.sh"
  if [[ -f "$READ_ROADMAP" ]]; then
    # Get the next incomplete phase
    next_phase=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" active-phase 2>/dev/null) || next_phase=""

    if [[ -n "$next_phase" && "$next_phase" != "none" ]]; then
      # Check if task plans exist for this phase to count tasks
      roadmap_dir=$(dirname "$ROADMAP_FILE")
      tasks_dir="$roadmap_dir/phases/$next_phase/tasks"
      if [[ -d "$tasks_dir" ]]; then
        task_count=$(find "$tasks_dir" -name 'T*-PLAN.md' -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
        # Each task = 1 dispatch + 1 phase transition at the end = tasks + 3
        next_phase_est=$((task_count + 3))
      fi
    fi
  fi
fi

# If we couldn't estimate from the roadmap, use average from this session
if [[ $next_phase_est -eq 0 && $phase_count -gt 0 ]]; then
  avg_tasks=$((session_dispatches / phase_count))
  next_phase_est=$((avg_tasks + 3))
fi

# Fallback: assume a moderate phase (4 tasks + transition)
if [[ $next_phase_est -eq 0 ]]; then
  next_phase_est=7
fi

# --- Decision ---
if [[ $((weight + next_phase_est)) -gt $WEIGHT_LIMIT ]]; then
  echo "CONTEXT:ROTATE weight=$weight limit=$WEIGHT_LIMIT next_est=$next_phase_est reason=session_weight_${weight}_plus_next_${next_phase_est}_exceeds_limit_${WEIGHT_LIMIT}"
else
  echo "CONTEXT:OK weight=$weight limit=$WEIGHT_LIMIT headroom=$headroom"
fi

exit 0
