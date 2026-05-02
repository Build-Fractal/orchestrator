#!/usr/bin/env bash
# scripts/state/derive-phase.sh — Derive the current orchestrator state from disk
# Reads the file tree under a milestone directory and returns exactly one of 9
# canonical states based on priority-ordered rules. First matching rule wins.
#
# Usage: derive-phase.sh <milestone-dir>
#
# States (priority order):
#   1. pre-planning  — milestone directory does not exist
#   2. discussing    — M###-CONTEXT.md exists with status: draft
#   3. planning      — no M###-ROADMAP.md, OR active phase has no P##-PLAN.md
#   4. replanning    — any phase marked stale in the roadmap
#   5. executing     — active phase has task plans without matching summaries
#   6. verifying     — active phase: all tasks done, no P##-VERIFICATION.md
#   7. summarizing   — active phase: all tasks done + verified, no P##-SUMMARY.md
#   8. validating    — all phases complete (have summaries), no validation marker
#   9. completing    — validation marker exists, no M###-SUMMARY.md
#  10. complete      — M###-SUMMARY.md exists
#
# DESIGN NOTE: This script is intentionally NOT tier-aware. It derives state
# purely from file presence, which means it cannot distinguish "Tier C needs
# discussion" from "Tier B can skip discussion." When no context draft and no
# roadmap exist, it returns "planning" regardless of tier. The Tier C discussion
# gate is enforced by the roadmap command (which reads the tier from
# M###-EVALUATION.md and blocks if the context draft isn't finalized).
# This separation keeps the state machine simple and deterministic — tier-specific
# policy is applied at the command layer, not the state derivation layer.
#
# Exits 0 on successful derivation (outputs state to stdout).
# Exits 1 with usage/error message to stderr on bad input.

# ROOT RESOLUTION (P04/M008): Callers pass an explicit <milestone-dir>
# positional argument. The conventional way to construct that path is:
#   root="$(bash scripts/state/resolve-root.sh)"
#   milestone_dir="$root/milestones/M###"
# This script does NOT resolve the root itself — it accepts whatever
# directory the caller provides. See scripts/state/resolve-root.sh for
# the authoritative precedence chain (env var, config, existing dir,
# default).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROADMAP_SCRIPT="$SCRIPT_DIR/read-roadmap.sh"

# --- Argument validation ---
if [[ $# -lt 1 ]]; then
  echo "derive-phase.sh: missing milestone directory argument" >&2
  echo "Usage: derive-phase.sh <milestone-dir>" >&2
  exit 1
fi

MILESTONE_DIR="$1"

# --- Rule 1: Directory does not exist → pre-planning ---
if [[ ! -d "$MILESTONE_DIR" ]]; then
  echo "pre-planning"
  exit 0
fi

# Extract milestone ID from files in the directory (look for M###-*.md pattern).
# Falls back to directory basename if no matching files found.
MILESTONE_ID="$(basename "$MILESTONE_DIR")"
detected_id=$(find "$MILESTONE_DIR" -maxdepth 1 -name 'M[0-9]*-*' -print 2>/dev/null \
  | head -1 \
  | xargs -I{} basename {} \
  | grep -oE '^M[0-9]+' || true)
if [[ -n "$detected_id" ]]; then
  MILESTONE_ID="$detected_id"
fi

# If we couldn't detect a milestone ID from files, the directory is empty → pre-planning
if [[ "$MILESTONE_ID" = "$(basename "$MILESTONE_DIR")" ]]; then
  # No M###-*.md files found — check if the dir is truly empty of milestone artifacts
  milestone_file_count=$(find "$MILESTONE_DIR" -maxdepth 1 -name 'M[0-9]*-*' 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$milestone_file_count" -eq 0 ]]; then
    # Also check for phases/ dir or other artifacts
    if [[ ! -d "$MILESTONE_DIR/phases" ]]; then
      echo "pre-planning"
      exit 0
    fi
  fi
fi

# --- Rule 2: Context draft with status: draft → discussing ---
CONTEXT_FILE="$MILESTONE_DIR/${MILESTONE_ID}-CONTEXT.md"
if [[ -f "$CONTEXT_FILE" ]]; then
  # Extract status from YAML frontmatter (between --- markers)
  context_status=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$CONTEXT_FILE" \
    | grep '^status:' \
    | head -1 \
    | sed 's/^status:[[:space:]]*//' \
    | sed 's/[[:space:]]*$//' \
    | sed 's/^"\(.*\)"$/\1/' \
    | sed "s/^'\(.*\)'$/\1/") || true
  if [[ "$context_status" = "draft" ]]; then
    echo "discussing"
    exit 0
  fi
fi

# --- Rule 3: No roadmap → planning ---
ROADMAP_FILE="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"
if [[ ! -f "$ROADMAP_FILE" ]]; then
  echo "planning"
  exit 0
fi

# --- Rule 4: Any phase is stale → replanning ---
# read-roadmap.sh returns "stale" as the status for stale phases
phases_data=$(bash "$ROADMAP_SCRIPT" "$ROADMAP_FILE" phases 2>/dev/null) || true

# --- Guard: roadmap exists but parser returned zero phases ---
# This is parser/format drift, not a legitimate state. Without this guard,
# Rule 8 would silently route to "validating" (its all_phases_complete=true
# initial value survives a zero-iteration loop) and validate-milestone.sh
# would then report "0/0 PASS" — a silent false-positive that could close
# a milestone with no work done. Surfaced 2026-05-01 by M036's
# `**P00 (M036a)**` syntax (parenthetical tag inside the bold span)
# which read-roadmap.sh's regex doesn't match. Fail loud so authorial
# drift becomes a build break, not a phantom completion.
if [[ -z "${phases_data//[[:space:]]/}" ]]; then
  echo "derive-phase.sh: roadmap parses to zero phases — likely format drift" >&2
  echo "derive-phase.sh: file: $ROADMAP_FILE" >&2
  echo "derive-phase.sh: expected phase headers like '- [ ] **P00**: ...' (no parenthetical tags inside the bold span)" >&2
  exit 1
fi

if echo "$phases_data" | grep -q ' stale '; then
  echo "replanning"
  exit 0
fi

# --- Determine active phase (needed for rules 3b, 5, 6) ---
active_phase=$(bash "$ROADMAP_SCRIPT" "$ROADMAP_FILE" active-phase 2>/dev/null) || true

# --- Rule 3b: Active phase has no plan file → planning ---
if [[ -n "$active_phase" && "$active_phase" != "none" ]]; then
  phase_plan="$MILESTONE_DIR/phases/${active_phase}/${active_phase}-PLAN.md"
  if [[ ! -f "$phase_plan" ]]; then
    echo "planning"
    exit 0
  fi
fi

# --- Rules 5-7: Check active phase task completion ---
if [[ -n "$active_phase" && "$active_phase" != "none" ]]; then
  tasks_dir="$MILESTONE_DIR/phases/${active_phase}/tasks"

  if [[ -d "$tasks_dir" ]]; then
    # Count task plans and check for missing summaries
    has_incomplete_task=false
    has_any_task=false

    for plan_file in "$tasks_dir"/T*-PLAN.md; do
      [[ -f "$plan_file" ]] || continue
      has_any_task=true
      task_id=$(basename "$plan_file" | sed 's/-PLAN\.md$//')
      summary_file="$tasks_dir/${task_id}-SUMMARY.md"
      # Bilateral-tolerance: the planner emits slug-suffixed plan filenames
      # (`T01-input-audit-PLAN.md`) per commands/plan-phase.md, but
      # write-summary.sh emits the bare-task-id form (`T01-SUMMARY.md`).
      # Accept either shape so the reader and writer stay in sync without
      # forcing slug-suffix emission on the writer.
      if [[ ! -f "$summary_file" ]]; then
        bare_task_id="${task_id%%-*}"
        if [[ "$bare_task_id" != "$task_id" ]]; then
          bare_summary_file="$tasks_dir/${bare_task_id}-SUMMARY.md"
          if [[ -f "$bare_summary_file" ]]; then
            summary_file="$bare_summary_file"
          fi
        fi
      fi
      if [[ ! -f "$summary_file" ]]; then
        has_incomplete_task=true
        break
      fi
    done

    # Rule 5: Active phase has incomplete tasks → executing
    if [[ "$has_incomplete_task" = "true" ]]; then
      echo "executing"
      exit 0
    fi

    # Rule 6: All tasks complete, no verification report → verifying
    if [[ "$has_any_task" = "true" && "$has_incomplete_task" != "true" ]]; then
      verification_file="$MILESTONE_DIR/phases/${active_phase}/${active_phase}-VERIFICATION.md"
      if [[ ! -f "$verification_file" ]]; then
        echo "verifying"
        exit 0
      fi
    fi

    # Rule 7: All tasks complete, verification exists, no phase summary → summarizing
    if [[ "$has_any_task" = "true" ]]; then
      phase_summary="$MILESTONE_DIR/phases/${active_phase}/${active_phase}-SUMMARY.md"
      if [[ ! -f "$phase_summary" ]]; then
        echo "summarizing"
        exit 0
      fi
    fi
  fi
fi

# --- Rule 8: All phases complete (have summaries), no validation marker → validating ---
all_phases_complete=true

# Read phase IDs from the roadmap and check each for a summary
while IFS=' ' read -r pid pstatus prisk pdepends; do
  [[ -z "$pid" ]] && continue
  phase_summary="$MILESTONE_DIR/phases/${pid}/${pid}-SUMMARY.md"
  if [[ ! -f "$phase_summary" ]]; then
    all_phases_complete=false
    break
  fi
done <<< "$phases_data"

if [[ "$all_phases_complete" = "true" ]]; then
  # Check for validation marker (M###-VALIDATED, created by mark-complete.sh)
  validation_file="$MILESTONE_DIR/${MILESTONE_ID}-VALIDATED"
  if [[ ! -f "$validation_file" ]]; then
    echo "validating"
    exit 0
  fi

  # --- Rule 9: Validated but no milestone summary → completing ---
  summary_file="$MILESTONE_DIR/${MILESTONE_ID}-SUMMARY.md"
  if [[ ! -f "$summary_file" ]]; then
    echo "completing"
    exit 0
  fi

  # --- Rule 10: Milestone summary exists → complete ---
  echo "complete"
  exit 0
fi

# Fallback: if we got here, roadmap exists but phases aren't all complete
# and active phase didn't match rules 5-6. This means phases exist in
# the roadmap but haven't been set up yet — treat as planning.
echo "planning"
exit 0
