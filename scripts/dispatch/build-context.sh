#!/usr/bin/env bash
# scripts/dispatch/build-context.sh — Assemble dispatch payload for task execution
# Builds a complete context payload from orchestrator state, filtered by scope (R007 — <20% of artifacts).
#
# Usage: build-context.sh <orchestrator-root> <milestone-id> <phase-id> <task-id> [--config-defaults <file>]
#   orchestrator-root: the .specify/orchestrator/ directory (or fixture milestone dir)
#   milestone-id: M### (e.g., M001)
#   phase-id: P## (e.g., P02)
#   task-id: T## (e.g., T01)
#   --config-defaults: optional config file for context_verbosity etc.
#
# Output: assembled dispatch prompt to stdout (following dispatch-prompt.md template)
# Stderr: "Context payload: X bytes (Y% of total artifacts)" — budget monitoring
# Exit 0 on success. Exit 1 on missing arguments or required files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCOPE_FILTER="$SCRIPT_DIR/scope-filter.sh"
READ_ROADMAP="$PROJECT_ROOT/scripts/state/read-roadmap.sh"
READ_CONFIG="$PROJECT_ROOT/scripts/state/read-config.sh"

# --- Argument parsing ---
ORCH_ROOT=""
MILESTONE_ID=""
PHASE_ID=""
TASK_ID=""
CONFIG_DEFAULTS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-defaults)
      CONFIG_DEFAULTS="$2"; shift 2 ;;
    -*)
      echo "build-context.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      if [[ -z "$ORCH_ROOT" ]]; then
        ORCH_ROOT="$1"
      elif [[ -z "$MILESTONE_ID" ]]; then
        MILESTONE_ID="$1"
      elif [[ -z "$PHASE_ID" ]]; then
        PHASE_ID="$1"
      elif [[ -z "$TASK_ID" ]]; then
        TASK_ID="$1"
      fi
      shift ;;
  esac
done

# Validate required arguments
if [[ -z "$ORCH_ROOT" || -z "$MILESTONE_ID" || -z "$PHASE_ID" || -z "$TASK_ID" ]]; then
  echo "build-context.sh: missing required arguments" >&2
  echo "Usage: build-context.sh <orchestrator-root> <milestone-id> <phase-id> <task-id> [--config-defaults <file>]" >&2
  exit 1
fi

# --- Resolve paths ---
# Support both .specify/orchestrator/milestones/M001 and fixture dirs where ORCH_ROOT is the milestone
# Try: <root>/milestones/<M###>/ first, then treat <root> as the milestone dir itself
MILESTONE_DIR=""
if [[ -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ]]; then
  MILESTONE_DIR="$ORCH_ROOT/milestones/$MILESTONE_ID"
elif [[ -d "$ORCH_ROOT/phases" ]]; then
  # Fixture mode: root IS the milestone directory
  MILESTONE_DIR="$ORCH_ROOT"
else
  echo "build-context.sh: milestone directory not found at '$ORCH_ROOT/milestones/$MILESTONE_ID' or '$ORCH_ROOT'" >&2
  exit 1
fi

PHASE_DIR="$MILESTONE_DIR/phases/$PHASE_ID"
TASK_PLAN="$PHASE_DIR/tasks/${TASK_ID}-PLAN.md"
PHASE_PLAN="$PHASE_DIR/${PHASE_ID}-PLAN.md"
ROADMAP="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"

# Validate required files exist
if [[ ! -f "$TASK_PLAN" ]]; then
  echo "build-context.sh: task plan not found: $TASK_PLAN" >&2
  exit 1
fi

if [[ ! -f "$PHASE_PLAN" ]]; then
  echo "build-context.sh: phase plan not found: $PHASE_PLAN" >&2
  exit 1
fi

if [[ ! -f "$ROADMAP" ]]; then
  echo "build-context.sh: roadmap not found: $ROADMAP" >&2
  exit 1
fi

# --- Read config values ---
config_read() {
  local key="$1"
  local default="$2"
  local value=""
  if [[ -n "$CONFIG_DEFAULTS" && -f "$CONFIG_DEFAULTS" ]]; then
    value=$(bash "$READ_CONFIG" "$key" --defaults "$CONFIG_DEFAULTS" 2>/dev/null) || true
  fi
  if [[ -z "$value" || "$value" = "null" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

CONTEXT_VERBOSITY=$(config_read "context_verbosity" "standard")
DURATION_BUDGET=$(config_read "duration_budget" "2h")
DISPATCH_BUDGET=$(config_read "dispatch_budget" "3")
BUDGET_ENFORCEMENT=$(config_read "budget_enforcement" "warn")

# --- Read tier from roadmap ---
TIER=$(bash "$READ_ROADMAP" "$ROADMAP" tier 2>/dev/null) || TIER="unknown"

# --- Read phase dependencies ---
PHASE_DATA=$(bash "$READ_ROADMAP" "$ROADMAP" phase "$PHASE_ID" 2>/dev/null) || PHASE_DATA=""
DEPENDS="none"
if [[ -n "$PHASE_DATA" ]]; then
  DEPENDS=$(echo "$PHASE_DATA" | awk '{print $4}')
fi

# --- Read task plan content ---
TASK_PLAN_CONTENT=$(cat "$TASK_PLAN")

# --- Read phase plan excerpt (goal, demo, must-haves) ---
PHASE_EXCERPT=""
if [[ -f "$PHASE_PLAN" ]]; then
  # Extract Goal section
  goal_line=$(grep -E '^## Goal' "$PHASE_PLAN" -A 2 | tail -n +2 | head -2 || true)
  # Extract Demo section
  demo_line=$(grep -E '^## Demo' "$PHASE_PLAN" -A 2 | tail -n +2 | head -2 || true)
  # Extract Must-Haves section (up to next ##)
  must_haves=$(sed -n '/^## Must-Haves/,/^## [^M]/p' "$PHASE_PLAN" | head -20 || true)

  PHASE_EXCERPT="### Goal
$goal_line

### Demo
$demo_line

### Must-Haves
$must_haves"
fi

# --- Gather upstream summaries ---
UPSTREAM_SUMMARIES=""
if [[ "$DEPENDS" != "none" && "$CONTEXT_VERBOSITY" != "minimal" ]]; then
  IFS=',' read -ra dep_list <<< "$DEPENDS"
  for dep in "${dep_list[@]}"; do
    dep=$(echo "$dep" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    summary_file="$MILESTONE_DIR/phases/$dep/${dep}-SUMMARY.md"
    if [[ -f "$summary_file" ]]; then
      UPSTREAM_SUMMARIES="${UPSTREAM_SUMMARIES}
### ${dep} Summary
$(cat "$summary_file")
"
    fi
  done
fi

if [[ -z "$UPSTREAM_SUMMARIES" ]]; then
  UPSTREAM_SUMMARIES="No upstream summaries available."
fi

# --- Scope-filtered knowledge ---
KNOWLEDGE_ENTRIES=""
if [[ "$CONTEXT_VERBOSITY" != "minimal" ]]; then
  KNOWLEDGE_FILE="$MILESTONE_DIR/KNOWLEDGE.md"
  if [[ -f "$KNOWLEDGE_FILE" ]]; then
    dep_flag=""
    if [[ "$DEPENDS" != "none" ]]; then
      dep_flag="--depends $DEPENDS"
    fi
    KNOWLEDGE_ENTRIES=$(bash "$SCOPE_FILTER" "$KNOWLEDGE_FILE" "$MILESTONE_ID/$PHASE_ID" --type knowledge $dep_flag 2>/dev/null) || true
  fi
fi

if [[ -z "$KNOWLEDGE_ENTRIES" ]]; then
  KNOWLEDGE_ENTRIES="No knowledge entries in scope."
fi

# --- Scope-filtered decisions ---
DECISION_ENTRIES=""
if [[ "$CONTEXT_VERBOSITY" != "minimal" ]]; then
  DECISIONS_FILE="$MILESTONE_DIR/DECISIONS.md"
  if [[ -f "$DECISIONS_FILE" ]]; then
    dep_flag=""
    if [[ "$DEPENDS" != "none" ]]; then
      dep_flag="--depends $DEPENDS"
    fi
    DECISION_ENTRIES=$(bash "$SCOPE_FILTER" "$DECISIONS_FILE" "$MILESTONE_ID/$PHASE_ID" --type decisions $dep_flag 2>/dev/null) || true
  fi
fi

if [[ -z "$DECISION_ENTRIES" ]]; then
  DECISION_ENTRIES="No decision entries in scope."
fi

# --- Derive current state ---
CURRENT_STATE="executing"

# --- Read verification criteria from phase plan ---
VERIFICATION_CRITERIA=""
verification_cmds=$(config_read "verification_commands" "")
if [[ -n "$verification_cmds" && "$verification_cmds" != "null" ]]; then
  VERIFICATION_CRITERIA="$verification_cmds"
else
  VERIFICATION_CRITERIA="See phase plan must-haves"
fi

# --- Assemble the dispatch payload (following dispatch-prompt.md template) ---
PAYLOAD=$(cat <<DISPATCH_EOF
---
schema_version: "1.0"
type: dispatch-prompt
---

## State Context

- **Current State**: $CURRENT_STATE
- **Milestone**: $MILESTONE_ID
- **Phase**: $PHASE_ID
- **Task**: $TASK_ID
- **Tier**: $TIER

## Scope

$PHASE_EXCERPT

## Upstream Context

$UPSTREAM_SUMMARIES

## Knowledge

$KNOWLEDGE_ENTRIES

## Decisions

$DECISION_ENTRIES

## Task Plan

$TASK_PLAN_CONTENT

## Constraints

- **Verification Criteria**: $VERIFICATION_CRITERIA
- **Duration Budget**: $DURATION_BUDGET
- **Dispatch Budget**: $DISPATCH_BUDGET
- **Budget Enforcement**: $BUDGET_ENFORCEMENT
DISPATCH_EOF
)

# --- Output payload ---
echo "$PAYLOAD"

# --- Report context budget to stderr ---
PAYLOAD_BYTES=$(echo "$PAYLOAD" | wc -c | tr -d ' ')

# Calculate total artifact bytes (all files under milestone dir)
TOTAL_BYTES=0
while IFS= read -r f; do
  if [[ -f "$f" ]]; then
    file_size=$(wc -c < "$f" | tr -d ' ')
    TOTAL_BYTES=$((TOTAL_BYTES + file_size))
  fi
done < <(find "$MILESTONE_DIR" -type f -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" 2>/dev/null)

if [[ "$TOTAL_BYTES" -gt 0 ]]; then
  BUDGET_PCT=$((PAYLOAD_BYTES * 100 / TOTAL_BYTES))
else
  BUDGET_PCT=0
fi

echo "Context payload: $PAYLOAD_BYTES bytes (${BUDGET_PCT}% of total artifacts)" >&2
