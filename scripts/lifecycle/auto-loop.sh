#!/usr/bin/env bash
# scripts/lifecycle/auto-loop.sh — Single-step mechanical loop driver for autonomous dispatch
# Executes ONE iteration of the auto loop's mechanical steps, then exits with
# structured output. The agent (via auto.md) calls this script repeatedly.
#
# Two-phase execution model:
#   Phase 1 (pre-dispatch):  auto-loop.sh <milestone-dir>
#     Steps A→D: derive state, check budget, check stuck, build context
#     Outputs payload to stdout, exits with status indicating "ready to dispatch"
#
#   Phase 2 (post-dispatch): auto-loop.sh <milestone-dir> --step=G --task=T## --outcome=<success|failure> [options]
#     Steps G→I: record result, update lock, check for more tasks / sync roadmap
#
# Usage:
#   auto-loop.sh <milestone-dir>
#   auto-loop.sh <milestone-dir> --step=G --task=T## --outcome=<success|failure> \
#     [--verification_result=<pass|fail|skipped>] [--duration_s=N]
#
# Structured output (stdout):
#   AUTO:READY milestone=<M###> phase=<P##> task=<T##> payload_bytes=<N>
#   AUTO:RECORDED milestone=<M###> phase=<P##> task=<T##>
#   AUTO:ADVANCE next_task=<T##>
#   AUTO:PHASE_COMPLETE phase=<P##>
#   AUTO:MILESTONE_VALIDATING
#   AUTO:MILESTONE_COMPLETE
#
# Exit codes:
#   0  — success (check stdout for action type)
#   1  — error (missing args, missing scripts)
#   2  — budget exceeded
#   3  — stuck detected
#   10 — milestone already complete
#   11 — pause requested
#   12 — unexpected state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Script paths ---
DERIVE_PHASE="$PROJECT_ROOT/scripts/state/derive-phase.sh"
READ_ROADMAP="$PROJECT_ROOT/scripts/state/read-roadmap.sh"
READ_CONFIG="$PROJECT_ROOT/scripts/state/read-config.sh"
BUILD_CONTEXT="$PROJECT_ROOT/scripts/dispatch/build-context.sh"
BUDGET_CHECKER="$PROJECT_ROOT/scripts/lifecycle/budget-checker.sh"
STUCK_DETECTOR="$PROJECT_ROOT/scripts/lifecycle/stuck-detector.sh"
LOCK_MANAGER="$PROJECT_ROOT/scripts/lifecycle/lock-manager.sh"
RECORD_RESULT="$PROJECT_ROOT/scripts/lifecycle/record-result.sh"
SYNC_ROADMAP="$PROJECT_ROOT/scripts/lifecycle/sync-roadmap.sh"

# --- Validate required scripts exist ---
for required_script in "$DERIVE_PHASE" "$READ_ROADMAP" "$BUILD_CONTEXT" \
  "$BUDGET_CHECKER" "$STUCK_DETECTOR" "$LOCK_MANAGER" "$RECORD_RESULT" "$SYNC_ROADMAP"; do
  if [[ ! -f "$required_script" ]]; then
    echo "auto-loop.sh: required script not found: $required_script" >&2
    exit 1
  fi
done

# --- Argument parsing ---
if [[ $# -lt 1 ]]; then
  echo "auto-loop.sh: requires <milestone-dir> [--step=G --task=T## --outcome=...]" >&2
  echo "Usage:" >&2
  echo "  Pre-dispatch:  auto-loop.sh <milestone-dir>" >&2
  echo "  Post-dispatch: auto-loop.sh <milestone-dir> --step=G --task=T## --outcome=<success|failure> [options]" >&2
  exit 1
fi

MILESTONE_DIR="$1"
shift

if [[ ! -d "$MILESTONE_DIR" ]]; then
  echo "auto-loop.sh: milestone directory not found: $MILESTONE_DIR" >&2
  exit 1
fi

STEP=""
TASK=""
OUTCOME=""
VERIFICATION_RESULT=""
DURATION_S=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --step=*)             STEP="${1#--step=}" ;;
    --task=*)             TASK="${1#--task=}" ;;
    --outcome=*)          OUTCOME="${1#--outcome=}" ;;
    --verification_result=*) VERIFICATION_RESULT="${1#--verification_result=}" ;;
    --duration_s=*)       DURATION_S="${1#--duration_s=}" ;;
    *)
      echo "auto-loop.sh: unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# --- Derive milestone ID from directory ---
MILESTONE_ID="$(basename "$MILESTONE_DIR")"
# Try to detect M###-*.md files for a more accurate ID
detected_id=$(find "$MILESTONE_DIR" -maxdepth 1 -name 'M[0-9]*-*' -print 2>/dev/null \
  | head -1 \
  | xargs -I{} basename {} \
  | grep -oE '^M[0-9]+' || true)
if [[ -n "$detected_id" ]]; then
  MILESTONE_ID="$detected_id"
fi

ROADMAP_FILE="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"
EXECUTION_LOG="$MILESTONE_DIR/execution-log.jsonl"
LOCK_FILE="$MILESTONE_DIR/../orchestrator.lock"
ORCH_ROOT="$(cd "$MILESTONE_DIR/.." 2>/dev/null && pwd)" || ORCH_ROOT="$MILESTONE_DIR"

# If the lock file path doesn't resolve (fixture mode), use milestone dir
if [[ ! -d "$(dirname "$LOCK_FILE")" ]]; then
  LOCK_FILE="$MILESTONE_DIR/orchestrator.lock"
  ORCH_ROOT="$MILESTONE_DIR"
fi

# ============================================================================
# POST-DISPATCH PHASE (--step=G)
# ============================================================================
if [[ "$STEP" = "G" ]]; then
  # Validate required args for post-dispatch
  if [[ -z "$TASK" || -z "$OUTCOME" ]]; then
    echo "auto-loop.sh: --step=G requires --task=T## and --outcome=<success|failure>" >&2
    exit 1
  fi

  # --- Derive active phase ---
  active_phase=""
  if [[ -f "$ROADMAP_FILE" ]]; then
    active_phase=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" active-phase 2>/dev/null) || true
  fi
  if [[ -z "$active_phase" || "$active_phase" = "none" ]]; then
    echo "auto-loop.sh: cannot determine active phase for recording" >&2
    exit 1
  fi

  # --- Step G: Record result via record-result.sh ---
  record_args=(
    "$EXECUTION_LOG"
    "--milestone=$MILESTONE_ID"
    "--phase=$active_phase"
    "--task=$TASK"
    "--outcome=$OUTCOME"
    "--tier=C"
    "--dispatch_method=subagent"
  )
  if [[ -n "$VERIFICATION_RESULT" ]]; then
    record_args+=("--verification_result=$VERIFICATION_RESULT")
  fi
  if [[ -n "$DURATION_S" ]]; then
    record_args+=("--duration_s=$DURATION_S")
  fi

  bash "$RECORD_RESULT" "${record_args[@]}" >/dev/null 2>&1
  echo "AUTO:RECORDED milestone=$MILESTONE_ID phase=$active_phase task=$TASK"

  # --- Step H: Update lock ---
  if [[ -f "$LOCK_FILE" ]]; then
    bash "$LOCK_MANAGER" update "$LOCK_FILE" "$MILESTONE_ID/$active_phase/$TASK" >/dev/null 2>&1 || true
  fi

  # --- Step I: Advance — check for more tasks / phase complete / milestone state ---
  tasks_dir="$MILESTONE_DIR/phases/$active_phase/tasks"
  next_task=""
  if [[ -d "$tasks_dir" ]]; then
    for plan_file in "$tasks_dir"/T*-PLAN.md; do
      [[ -f "$plan_file" ]] || continue
      task_id=$(basename "$plan_file" | sed 's/-PLAN\.md$//')
      summary_file="$tasks_dir/${task_id}-SUMMARY.md"
      if [[ ! -f "$summary_file" ]]; then
        next_task="$task_id"
        break
      fi
    done
  fi

  if [[ -n "$next_task" ]]; then
    echo "AUTO:ADVANCE next_task=$next_task"
  else
    # All tasks in phase complete — check milestone state
    state=$(bash "$DERIVE_PHASE" "$MILESTONE_DIR" 2>/dev/null) || state="unknown"

    # Sync roadmap if it exists
    if [[ -f "$ROADMAP_FILE" ]]; then
      bash "$SYNC_ROADMAP" "$ROADMAP_FILE" "$MILESTONE_DIR" --fix >/dev/null 2>&1 || true
    fi

    case "$state" in
      verifying|summarizing)
        echo "AUTO:PHASE_COMPLETE phase=$active_phase"
        ;;
      validating)
        echo "AUTO:MILESTONE_VALIDATING"
        ;;
      complete)
        echo "AUTO:MILESTONE_COMPLETE"
        ;;
      *)
        echo "AUTO:PHASE_COMPLETE phase=$active_phase"
        ;;
    esac
  fi

  exit 0
fi

# ============================================================================
# PRE-DISPATCH PHASE (default, no --step)
# ============================================================================

# --- Check for pause request ---
PAUSE_FILE=""
# Check standard orchestrator location
if [[ -f "$ORCH_ROOT/pause-requested" ]]; then
  PAUSE_FILE="$ORCH_ROOT/pause-requested"
elif [[ -f "$MILESTONE_DIR/pause-requested" ]]; then
  PAUSE_FILE="$MILESTONE_DIR/pause-requested"
fi

if [[ -n "$PAUSE_FILE" ]]; then
  rm -f "$PAUSE_FILE"
  exit 11
fi

# --- Step A: Derive state and identify next task ---
state=$(bash "$DERIVE_PHASE" "$MILESTONE_DIR" 2>/dev/null) || state="unknown"

case "$state" in
  executing)
    ;; # Valid state for task dispatch, continue
  planning)
    # Phase needs planning before tasks can be dispatched
    active_phase=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" active-phase 2>/dev/null) || active_phase="unknown"
    echo "AUTO:PLANNING phase=$active_phase milestone=$MILESTONE_ID"
    exit 0
    ;;
  verifying|summarizing)
    # Phase transition needed — report phase complete
    active_phase=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" active-phase 2>/dev/null) || active_phase="unknown"
    echo "AUTO:PHASE_COMPLETE phase=$active_phase"
    exit 0
    ;;
  validating)
    echo "AUTO:MILESTONE_VALIDATING"
    exit 0
    ;;
  completing|complete)
    exit 10
    ;;
  *)
    echo "auto-loop.sh: unexpected state '$state' from derive-phase.sh" >&2
    exit 12
    ;;
esac

# Identify active phase
active_phase=""
if [[ -f "$ROADMAP_FILE" ]]; then
  active_phase=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" active-phase 2>/dev/null) || true
fi
if [[ -z "$active_phase" || "$active_phase" = "none" ]]; then
  echo "auto-loop.sh: no active phase found in roadmap" >&2
  exit 12
fi

# Find next incomplete task
tasks_dir="$MILESTONE_DIR/phases/$active_phase/tasks"
next_task=""
if [[ -d "$tasks_dir" ]]; then
  for plan_file in "$tasks_dir"/T*-PLAN.md; do
    [[ -f "$plan_file" ]] || continue
    task_id=$(basename "$plan_file" | sed 's/-PLAN\.md$//')
    summary_file="$tasks_dir/${task_id}-SUMMARY.md"
    if [[ ! -f "$summary_file" ]]; then
      next_task="$task_id"
      break
    fi
  done
fi

if [[ -z "$next_task" ]]; then
  # All tasks complete in active phase — state should transition
  echo "AUTO:PHASE_COMPLETE phase=$active_phase"
  exit 0
fi

# --- Step B: Check budget ---
if [[ -f "$EXECUTION_LOG" ]]; then
  # Read budget config (use defaults if config unavailable)
  dispatch_limit=$(bash "$READ_CONFIG" dispatch_budget 2>/dev/null) || dispatch_limit="null"
  duration_limit=$(bash "$READ_CONFIG" duration_budget 2>/dev/null) || duration_limit="null"

  budget_args=("$EXECUTION_LOG")
  if [[ "$dispatch_limit" != "null" && -n "$dispatch_limit" ]]; then
    budget_args+=("--dispatch-budget" "$dispatch_limit")
  fi
  if [[ "$duration_limit" != "null" && -n "$duration_limit" ]]; then
    budget_args+=("--duration-budget" "$duration_limit")
  fi

  budget_output=$(bash "$BUDGET_CHECKER" "${budget_args[@]}" 2>/dev/null) || true
  if echo "$budget_output" | grep -q "^BUDGET:EXCEEDED"; then
    echo "$budget_output" >&2
    exit 2
  fi
fi

# --- Step C: Check stuck ---
if [[ -f "$EXECUTION_LOG" ]]; then
  unit_id="$MILESTONE_ID/$active_phase/$next_task"
  stuck_output=$(bash "$STUCK_DETECTOR" "$EXECUTION_LOG" "$unit_id" 2>/dev/null) || true
  if echo "$stuck_output" | grep -q "^STUCK:YES"; then
    echo "$stuck_output" >&2
    exit 3
  fi
fi

# --- Step D: Build context payload ---
payload=$(bash "$BUILD_CONTEXT" "$ORCH_ROOT" "$MILESTONE_ID" "$active_phase" "$next_task" 2>/dev/null) || {
  # If build-context fails (e.g. missing phase plan in fixture), output minimal info
  payload="Task: $next_task in phase $active_phase of milestone $MILESTONE_ID"
}

payload_bytes=$(printf '%s' "$payload" | wc -c | tr -d ' ')

# Write payload to a file so the orchestrating agent can pass it directly to a subagent
# without holding the full payload in its own context
payload_file="$MILESTONE_DIR/phases/$active_phase/tasks/${next_task}-PAYLOAD.md"
mkdir -p "$(dirname "$payload_file")"
printf '%s' "$payload" > "$payload_file"

# Output the structured status line with payload file path
echo "AUTO:READY milestone=$MILESTONE_ID phase=$active_phase task=$next_task payload_bytes=$payload_bytes payload_file=$payload_file"

exit 0
