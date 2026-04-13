#!/usr/bin/env bash
# scripts/util/check-plan-exists.sh — Check phase plan and task plan existence
# Single-script replacement for compound test/ls patterns that trigger
# Claude Code harness safety heuristics (AD-19).
#
# Usage: check-plan-exists.sh <milestone-dir> <phase-id>
#
# Output (stdout):
#   PLAN_EXISTS task_plans=<N>
#   PLAN_MISSING task_plans=0
#
# Exit 0 always (informational check, not a gate).
# Bash 3.2 compatible.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "check-plan-exists.sh: requires <milestone-dir> <phase-id>" >&2
  exit 1
fi

MILESTONE_DIR="$1"
PHASE_ID="$2"

PLAN_FILE="$MILESTONE_DIR/phases/$PHASE_ID/${PHASE_ID}-PLAN.md"
TASKS_DIR="$MILESTONE_DIR/phases/$PHASE_ID/tasks"

task_plan_count=0
if [[ -d "$TASKS_DIR" ]]; then
  for f in "$TASKS_DIR"/T*-PLAN.md; do
    [[ -f "$f" ]] && task_plan_count=$((task_plan_count + 1))
  done
fi

if [[ -f "$PLAN_FILE" ]]; then
  echo "PLAN_EXISTS task_plans=$task_plan_count"
else
  echo "PLAN_MISSING task_plans=0"
fi
