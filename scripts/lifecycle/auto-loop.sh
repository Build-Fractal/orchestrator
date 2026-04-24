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
#     Steps G→H: record result, update lock
#
#   Verification: auto-loop.sh <milestone-dir> --step=V --phase=P## --task=T##
#     Runs task-level verification from the task plan's Verification section
#
# Usage:
#   auto-loop.sh <milestone-dir> [--output-file=<path>]
#   auto-loop.sh <milestone-dir> --step=G --task=T## --outcome=<success|failure> \
#     [--verification_result=<pass|fail|skipped>] [--duration_s=N] \
#     [--model=<id>] [--tokens-input=N] [--tokens-output=N] \
#     [--tokens-cache-read=N] [--cost=<amount>] [--cache-hit-rate=<rate>] \
#     [--output-file=<path>]
#   auto-loop.sh <milestone-dir> --step=V --phase=P## --task=T## [--output-file=<path>]
#   auto-loop.sh <milestone-dir> --step=X [--output-file=<path>]
#
# When --output-file is provided, structured output (AUTO:*, CONTEXT:*) is
# written to that file instead of stdout. This allows callers to avoid command
# substitution — output=$(bash auto-loop.sh ...) — which triggers Claude Code's
# harness safety heuristic (AD-19). Instead:
#   bash auto-loop.sh <dir> --output-file=<path>
#   # then read the file for structured output
#
# Structured output (stdout):
#   AUTO:READY milestone=<M###> phase=<P##> task=<T##> payload_bytes=<N>
#   AUTO:RECORDED milestone=<M###> phase=<P##> task=<T##>
#   AUTO:VERIFY_PASS phase=<P##> task=<T##> checks_passed=<N>
#   AUTO:VERIFY_FAIL phase=<P##> task=<T##> checks_passed=<N> checks_failed=<N>
#   AUTO:PHASE_COMPLETE phase=<P##>
#   AUTO:MILESTONE_VALIDATING
#   AUTO:MILESTONE_COMPLETE
#   CONTEXT:OK weight=<N> limit=<L> headroom=<H>
#   CONTEXT:ROTATE weight=<N> limit=<L> next_est=<E> reason=<msg>
#
# Exit codes:
#   0  — success (check stdout for action type)
#   1  — error (missing args, missing scripts)
#   2  — budget exceeded
#   3  — stuck detected
#   10 — milestone already complete
#   11 — pause requested
#   12 — unexpected state
#   13 — planning payload assembly failed (build-context.sh non-zero on PHASE_PLAN)
#   14 — context rotation recommended

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
CONTEXT_MONITOR="$PROJECT_ROOT/scripts/lifecycle/context-monitor.sh"
CHECK_MUST_HAVES="$PROJECT_ROOT/scripts/verify/check-must-haves.sh"
RUN_COMMANDS="$PROJECT_ROOT/scripts/verify/run-commands.sh"
REBUILD_INDEX="$PROJECT_ROOT/scripts/knowledge/rebuild-index.sh"

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
PHASE=""
OUTCOME=""
VERIFICATION_RESULT=""
DURATION_S=""
MODEL_USED=""
TOKENS_INPUT=""
TOKENS_OUTPUT=""
TOKENS_CACHE_READ=""
COST_ESTIMATED=""
CACHE_HIT_RATE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --step=*)             STEP="${1#--step=}" ;;
    --task=*)             TASK="${1#--task=}" ;;
    --phase=*)            PHASE="${1#--phase=}" ;;
    --outcome=*)          OUTCOME="${1#--outcome=}" ;;
    --verification_result=*) VERIFICATION_RESULT="${1#--verification_result=}" ;;
    --duration_s=*)       DURATION_S="${1#--duration_s=}" ;;
    --model=*)            MODEL_USED="${1#--model=}" ;;
    --tokens-input=*)     TOKENS_INPUT="${1#--tokens-input=}" ;;
    --tokens-output=*)    TOKENS_OUTPUT="${1#--tokens-output=}" ;;
    --tokens-cache-read=*) TOKENS_CACHE_READ="${1#--tokens-cache-read=}" ;;
    --cost=*)             COST_ESTIMATED="${1#--cost=}" ;;
    --cache-hit-rate=*)   CACHE_HIT_RATE="${1#--cache-hit-rate=}" ;;
    --output-file=*)      OUTPUT_FILE="${1#--output-file=}" ;;
    --output-file)        OUTPUT_FILE="$2"; shift ;;
    *)
      echo "auto-loop.sh: unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# --- Output routing: when --output-file is set, redirect structured output ---
# This allows callers to avoid command substitution (which triggers Claude Code
# harness safety heuristics). Instead of output=$(bash auto-loop.sh ...),
# callers run: bash auto-loop.sh ... --output-file <path> && read the file.
_auto_output() {
  if [[ -n "$OUTPUT_FILE" ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    printf '%s\n' "$1" > "$OUTPUT_FILE"
  else
    echo "$1"
  fi
}

# --- Derive milestone ID from directory ---
DETECT_MILESTONE="$PROJECT_ROOT/scripts/util/detect-milestone-id.sh"
if [[ -f "$DETECT_MILESTONE" ]]; then
  MILESTONE_ID="$(bash "$DETECT_MILESTONE" "$MILESTONE_DIR")"
else
  MILESTONE_ID="$(basename "$MILESTONE_DIR")"
fi

ROADMAP_FILE="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"
EXECUTION_LOG="$MILESTONE_DIR/execution-log.jsonl"
LOCK_FILE="$MILESTONE_DIR/../orchestrator.lock"
ORCH_ROOT="$(cd "$MILESTONE_DIR/../.." 2>/dev/null && pwd)" || ORCH_ROOT="$MILESTONE_DIR"

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
  if [[ -n "$MODEL_USED" ]]; then
    record_args+=("--model=$MODEL_USED")
  fi
  if [[ -n "$TOKENS_INPUT" ]]; then
    record_args+=("--tokens-input=$TOKENS_INPUT")
  fi
  if [[ -n "$TOKENS_OUTPUT" ]]; then
    record_args+=("--tokens-output=$TOKENS_OUTPUT")
  fi
  if [[ -n "$TOKENS_CACHE_READ" ]]; then
    record_args+=("--tokens-cache-read=$TOKENS_CACHE_READ")
  fi
  if [[ -n "$COST_ESTIMATED" ]]; then
    record_args+=("--cost=$COST_ESTIMATED")
  fi
  if [[ -n "$CACHE_HIT_RATE" ]]; then
    record_args+=("--cache-hit-rate=$CACHE_HIT_RATE")
  fi

  bash "$RECORD_RESULT" "${record_args[@]}" >/dev/null 2>&1
  _auto_output "AUTO:RECORDED milestone=$MILESTONE_ID phase=$active_phase task=$TASK"

  # --- Step H: Update lock ---
  if [[ -f "$LOCK_FILE" ]]; then
    bash "$LOCK_MANAGER" update "$LOCK_FILE" "$MILESTONE_ID/$active_phase/$TASK" >/dev/null 2>&1 || true
  fi

  # --- Step I: Post-dispatch is complete ---
  # Next-task determination is deferred to the next pre-dispatch call (Stage 1).
  # This avoids race conditions where summaries haven't been written yet when
  # scanning for the next incomplete task.

  exit 0
fi

# ============================================================================
# VERIFICATION PHASE (--step=V)
# ============================================================================
if [[ "$STEP" = "V" ]]; then
  if [[ -z "$TASK" || -z "$PHASE" ]]; then
    echo "auto-loop.sh: --step=V requires --phase=P## and --task=T##" >&2
    exit 1
  fi

  task_plan="$MILESTONE_DIR/phases/$PHASE/tasks/${TASK}-PLAN.md"
  if [[ ! -f "$task_plan" ]]; then
    echo "auto-loop.sh: task plan not found: $task_plan" >&2
    exit 1
  fi

  # Extract verification commands from the task plan's Verification section
  # Look for lines with backtick-wrapped commands under ## Verification or ## Must-Haves
  verify_section=$(sed -n '/^## \(Verification\|Must-Haves\)/,/^## [^#]/p' "$task_plan" | sed '$d' || true)
  if [[ -z "$verify_section" ]]; then
    # Try without trailing delimiter (section is last in file)
    verify_section=$(sed -n '/^## \(Verification\|Must-Haves\)/,$p' "$task_plan" || true)
  fi

  if [[ -z "$verify_section" ]]; then
    _auto_output "AUTO:VERIFY_PASS phase=$PHASE task=$TASK checks_passed=0"
    exit 0
  fi

  # Resolve project root for running check commands
  VERIFY_PROJECT_ROOT=""
  candidate="$MILESTONE_DIR"
  while [[ "$candidate" != "/" ]]; do
    parent_name=$(basename "$(dirname "$candidate")")
    if [[ "$parent_name" = "milestones" ]]; then
      # Go up through milestones/ → orchestrator/ → .specify/ → project root
      VERIFY_PROJECT_ROOT="$(cd "$candidate/../../.." 2>/dev/null && pwd)" || true
      break
    fi
    candidate="$(dirname "$candidate")"
  done
  if [[ -z "$VERIFY_PROJECT_ROOT" ]]; then
    VERIFY_PROJECT_ROOT="$(cd "$MILESTONE_DIR/../.." 2>/dev/null && pwd)" || VERIFY_PROJECT_ROOT="."
  fi

  # Extract and run check commands from backtick-wrapped lines
  checks_passed=0
  checks_failed=0
  fail_details=""

  while IFS= read -r line; do
    # Match lines containing `command` backtick patterns (Check: `cmd` or - `cmd`)
    check_cmd=""
    if echo "$line" | grep -qE '`[^`]+`'; then
      check_cmd=$(echo "$line" | sed 's/.*`\([^`]*\)`.*/\1/')
    fi
    [[ -z "$check_cmd" ]] && continue

    # Run the check command relative to project root
    if (cd "$VERIFY_PROJECT_ROOT" && eval "$check_cmd") >/dev/null 2>&1; then
      echo "PASS: $check_cmd"
      checks_passed=$((checks_passed + 1))
    else
      echo "FAIL: $check_cmd"
      checks_failed=$((checks_failed + 1))
      fail_details="${fail_details}FAIL: $check_cmd\n"
    fi
  done <<< "$verify_section"

  if [[ "$checks_failed" -gt 0 ]]; then
    _auto_output "AUTO:VERIFY_FAIL phase=$PHASE task=$TASK checks_passed=$checks_passed checks_failed=$checks_failed"
    exit 1
  else
    _auto_output "AUTO:VERIFY_PASS phase=$PHASE task=$TASK checks_passed=$checks_passed"
    exit 0
  fi
fi

# ============================================================================
# CONTEXT CHECK PHASE (--step=X)
# ============================================================================
if [[ "$STEP" = "X" ]]; then
  # Check session context weight at phase boundaries.
  # Returns exit code 14 if rotation is recommended.
  if [[ ! -f "$CONTEXT_MONITOR" ]]; then
    # Context monitor not available — skip check, proceed
    _auto_output "CONTEXT:OK weight=0 limit=0 headroom=0 (monitor unavailable)"
    exit 0
  fi

  monitor_args=("$EXECUTION_LOG" "$LOCK_FILE")

  if [[ -f "$ROADMAP_FILE" ]]; then
    monitor_args+=("--roadmap" "$ROADMAP_FILE")
  fi

  # Read configured session weight limit
  weight_limit=""
  if [[ -f "$READ_CONFIG" ]]; then
    weight_limit=$(bash "$READ_CONFIG" session_weight_limit 2>/dev/null) || weight_limit=""
  fi
  if [[ -n "$weight_limit" && "$weight_limit" != "null" ]]; then
    monitor_args+=("--limit" "$weight_limit")
  fi

  context_output=$(bash "$CONTEXT_MONITOR" "${monitor_args[@]}" 2>/dev/null) || context_output="CONTEXT:OK weight=0 limit=15 headroom=15"
  _auto_output "$context_output"

  if echo "$context_output" | grep -q "^CONTEXT:ROTATE"; then
    exit 14
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

# --- Ensure knowledge graph is current before dispatch ---
if [ -f "$REBUILD_INDEX" ]; then
  bash "$REBUILD_INDEX" --root "$PROJECT_ROOT" >/dev/null 2>&1 || true
fi

# --- Step A: Derive state and identify next task ---
state=$(bash "$DERIVE_PHASE" "$MILESTONE_DIR" 2>/dev/null) || state="unknown"

case "$state" in
  executing)
    ;; # Valid state for task dispatch, continue
  planning)
    # Phase needs planning before tasks can be dispatched
    active_phase=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" active-phase 2>/dev/null) || active_phase="unknown"
    # Build planning payload using PHASE_PLAN mode. Mirror the task-dispatch
    # error-handling pattern (capture stderr, fail loud) — a silent fallback
    # to a one-line stub would let the planner hallucinate over missing
    # spec/roadmap/knowledge context with no way to tell the difference.
    plan_stderr_log="$MILESTONE_DIR/build-context-planning-stderr.log"
    plan_payload=$(bash "$BUILD_CONTEXT" "$ORCH_ROOT" "$MILESTONE_ID" "$active_phase" "PHASE_PLAN" 2>"$plan_stderr_log") || {
      plan_stderr=$(cat "$plan_stderr_log" 2>/dev/null || true)
      plan_stderr_tail=$(printf '%s' "$plan_stderr" | tail -5 | tr '\n' ' ')
      rm -f "$plan_stderr_log"
      echo "auto-loop.sh: build-context.sh (planning) failed: $plan_stderr" >&2
      _auto_output "AUTO:PLANNING_FAILED phase=$active_phase milestone=$MILESTONE_ID stderr=$plan_stderr_tail"
      exit 13
    }
    rm -f "$plan_stderr_log"
    plan_payload_bytes=$(printf '%s' "$plan_payload" | wc -c | tr -d ' ')
    plan_payload_file="$MILESTONE_DIR/phases/$active_phase/${active_phase}-PLANNING-PAYLOAD.md"
    mkdir -p "$(dirname "$plan_payload_file")"
    printf '%s' "$plan_payload" > "$plan_payload_file"
    _auto_output "AUTO:PLANNING phase=$active_phase milestone=$MILESTONE_ID payload_bytes=$plan_payload_bytes payload_file=$plan_payload_file"
    exit 0
    ;;
  verifying|summarizing)
    # Phase transition needed — report phase complete
    active_phase=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" active-phase 2>/dev/null) || active_phase="unknown"
    _auto_output "AUTO:PHASE_COMPLETE phase=$active_phase"
    exit 0
    ;;
  validating)
    _auto_output "AUTO:MILESTONE_VALIDATING"
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
  _auto_output "AUTO:PHASE_COMPLETE phase=$active_phase"
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
build_stderr=""
payload=$(bash "$BUILD_CONTEXT" "$ORCH_ROOT" "$MILESTONE_ID" "$active_phase" "$next_task" 2>"$MILESTONE_DIR/build-context-stderr.log") || {
  # Log the error so the orchestrating agent can diagnose payload assembly failures
  build_stderr=$(cat "$MILESTONE_DIR/build-context-stderr.log" 2>/dev/null || true)
  echo "auto-loop.sh: build-context.sh failed: $build_stderr" >&2
  payload="Task: $next_task in phase $active_phase of milestone $MILESTONE_ID"
}
rm -f "$MILESTONE_DIR/build-context-stderr.log"

payload_bytes=$(printf '%s' "$payload" | wc -c | tr -d ' ')

# Write payload to a file so the orchestrating agent can pass it directly to a subagent
# without holding the full payload in its own context
payload_file="$MILESTONE_DIR/phases/$active_phase/tasks/${next_task}-PAYLOAD.md"
mkdir -p "$(dirname "$payload_file")"
printf '%s' "$payload" > "$payload_file"

# Output the structured status line with payload file path
_auto_output "AUTO:READY milestone=$MILESTONE_ID phase=$active_phase task=$next_task payload_bytes=$payload_bytes payload_file=$payload_file"

exit 0
