#!/usr/bin/env bash
# scripts/lifecycle/recovery-briefing.sh — Synthesize crash recovery context from disk
# Examines surviving artifacts in a milestone directory to determine what completed
# before a crash and what was in progress, then outputs a structured briefing.
#
# Usage: recovery-briefing.sh <milestone-dir>
#
# Reads: lock file, phase/task directory tree, execution-log.jsonl
# Uses: scripts/state/derive-phase.sh for current state derivation
# Output: structured recovery briefing to stdout (follows templates/recovery-briefing.md)
#
# Exit 0 on success. Exit 1 if milestone directory doesn't exist.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DERIVE_PHASE="$SCRIPT_DIR/../state/derive-phase.sh"

# --- Argument validation ---
if [[ $# -lt 1 ]]; then
  echo "recovery-briefing.sh: requires <milestone-dir>" >&2
  echo "Usage: recovery-briefing.sh <milestone-dir>" >&2
  exit 1
fi

MILESTONE_DIR="$1"

if [[ ! -d "$MILESTONE_DIR" ]]; then
  echo "recovery-briefing.sh: milestone directory not found: $MILESTONE_DIR" >&2
  exit 1
fi

# --- Helper: ISO 8601 timestamp ---
iso_timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# --- Helper: Read a JSON field value (shared utility, no jq required) ---
source "$SCRIPT_DIR/../util/json-field.sh"

# --- Detect milestone ID ---
MILESTONE_ID="$(basename "$MILESTONE_DIR")"
detected_id=$(find "$MILESTONE_DIR" -maxdepth 1 -name 'M[0-9]*-*' -print 2>/dev/null \
  | head -1 \
  | xargs -I{} basename {} \
  | grep -oE '^M[0-9]+' || true)
if [[ -n "$detected_id" ]]; then
  MILESTONE_ID="$detected_id"
fi

# --- Derive current state ---
current_state="unknown"
if [[ -f "$DERIVE_PHASE" ]]; then
  current_state="$(bash "$DERIVE_PHASE" "$MILESTONE_DIR" 2>/dev/null)" || current_state="unknown"
fi

# --- Read lock file info ---
ORCH_DIR="$MILESTONE_DIR/.orchestrator"
LOCK_FILE="$ORCH_DIR/orchestrator.lock"

lock_status="not found"
lock_pid=""
lock_unit_id=""
lock_unit_type=""
lock_started=""
lock_unit_started=""
lock_pid_status="n/a"

if [[ -f "$LOCK_FILE" ]]; then
  lock_status="present"
  lock_pid="$(json_field "$LOCK_FILE" "pid")"
  lock_unit_id="$(json_field "$LOCK_FILE" "unitId")"
  lock_unit_type="$(json_field "$LOCK_FILE" "unitType")"
  lock_started="$(json_field "$LOCK_FILE" "startedAt")"
  lock_unit_started="$(json_field "$LOCK_FILE" "unitStartedAt")"

  if [[ -n "$lock_pid" ]]; then
    if kill -0 "$lock_pid" 2>/dev/null; then
      lock_pid_status="alive"
    else
      lock_pid_status="dead"
    fi
  fi
fi

# --- Detect git worktrees (FR-075) ---
worktree_info=""
if command -v git >/dev/null 2>&1; then
  worktree_list=$(git worktree list --porcelain 2>/dev/null | grep "^worktree " | grep -v "$(git rev-parse --show-toplevel 2>/dev/null)" || true)
  if [[ -n "$worktree_list" ]]; then
    worktree_info="Active worktrees detected:
$(echo "$worktree_list" | sed 's/^worktree /- /')"
  fi
fi

# --- Walk phase/task tree to find completed and incomplete work ---
completed_units=""
incomplete_units=""

phases_dir="$MILESTONE_DIR/phases"
if [[ -d "$phases_dir" ]]; then
  for phase_dir in "$phases_dir"/P[0-9]*/; do
    [[ -d "$phase_dir" ]] || continue
    phase_id="$(basename "$phase_dir")"

    # Check for phase summary
    if [[ -f "${phase_dir}${phase_id}-SUMMARY.md" ]]; then
      completed_units="${completed_units}- Phase ${phase_id} (summary exists)
"
    fi

    # Check tasks within the phase
    tasks_dir="${phase_dir}tasks"
    if [[ -d "$tasks_dir" ]]; then
      for plan_file in "$tasks_dir"/T*-PLAN.md; do
        [[ -f "$plan_file" ]] || continue
        task_id="$(basename "$plan_file" | sed 's/-PLAN\.md$//')"
        summary_file="$tasks_dir/${task_id}-SUMMARY.md"
        # Bilateral-tolerance for slug-suffixed plan filenames; see
        # scripts/state/derive-phase.sh for the same fallback shape.
        if [[ ! -f "$summary_file" ]]; then
          bare_task_id="${task_id%%-*}"
          if [[ "$bare_task_id" != "$task_id" ]]; then
            bare_summary_file="$tasks_dir/${bare_task_id}-SUMMARY.md"
            if [[ -f "$bare_summary_file" ]]; then
              summary_file="$bare_summary_file"
            fi
          fi
        fi

        if [[ -f "$summary_file" ]]; then
          completed_units="${completed_units}- ${phase_id}/${task_id} (summary exists)
"
        else
          incomplete_units="${incomplete_units}- ${phase_id}/${task_id} (plan exists, no summary)
"
        fi
      done
    fi
  done
fi

# Default text if nothing found
if [[ -z "$completed_units" ]]; then
  completed_units="(none found)
"
fi
if [[ -z "$incomplete_units" ]]; then
  incomplete_units="(none found)
"
fi

# --- Read recent execution log entries ---
EXEC_LOG="$ORCH_DIR/execution-log.jsonl"
recent_dispatches=""
if [[ -f "$EXEC_LOG" ]] && [[ -s "$EXEC_LOG" ]]; then
  recent_dispatches="$(tail -5 "$EXEC_LOG")"
fi

# --- Calculate runtime ---
runtime="unknown"
if [[ -n "$lock_started" ]]; then
  runtime="started at $lock_started"
fi

# --- Build recovery plan ---
recovery_plan="1. Break the stale lock: \`bash scripts/lifecycle/lock-manager.sh break $LOCK_FILE\`
2. Review incomplete work above for partial artifacts
3. Resume dispatch: run \`/orchestrator-resume\` to continue from the crash point"

if [[ "$lock_status" = "not found" ]]; then
  recovery_plan="1. No lock file found — previous session may have completed or been cleaned up
2. Derive current state and resume from the next pending unit
3. Run \`/orchestrator-auto\` to start or continue autonomous dispatch"
fi

# --- Output structured briefing ---
NOW="$(iso_timestamp)"

cat <<EOF
---
schema_version: "1.0"
type: recovery-briefing
milestone: "$MILESTONE_ID"
recovered_at: "$NOW"
crash_detected_at: "$NOW"
---

## Crash State

- **Last Active Unit**: ${lock_unit_type:-unknown} — ${lock_unit_id:-unknown}
- **Last Known State**: $current_state
- **Lock File**: $lock_status
- **PID**: ${lock_pid:-n/a} (${lock_pid_status})
- **Runtime**: $runtime
- **Started At**: ${lock_started:-n/a}
- **Unit Started At**: ${lock_unit_started:-n/a}

## Completed Work

$completed_units

## Incomplete Work

$incomplete_units

## Recent Dispatch History

$(if [[ -n "$recent_dispatches" ]]; then echo "$recent_dispatches"; else echo "(no execution log found)"; fi)

## Recovery Plan

$recovery_plan

$(if [[ -n "$worktree_info" ]]; then
echo "## Worktree Isolation"
echo ""
echo "$worktree_info"
fi)
EOF
