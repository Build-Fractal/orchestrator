#!/usr/bin/env bash
# scripts/dispatch/build-context.sh — Assemble dispatch payload for task execution
# Builds a complete context payload from orchestrator state, filtered by scope (R007 — <20% of artifacts).
#
# Usage: build-context.sh <orchestrator-root> <milestone-id> <phase-id> <task-id> [--config-defaults <file>]
#   orchestrator-root: the .specify/orchestrator/ directory (or fixture milestone dir)
#   milestone-id: M### (e.g., M001)
#   phase-id: P## (e.g., P02)
#   task-id: T## (e.g., T01) or PHASE_PLAN for planning payload
#   --config-defaults: optional config file for context_verbosity etc.
#
# When task-id is PHASE_PLAN, assembles a planning context payload instead of
# a task execution payload. Includes roadmap phase section, upstream summaries,
# feature spec references, context draft, decisions, and knowledge.
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
ROADMAP="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"
IS_PLANNING=false
if [[ "$TASK_ID" = "PHASE_PLAN" ]]; then
  IS_PLANNING=true
fi

if [[ ! -f "$ROADMAP" ]]; then
  echo "build-context.sh: roadmap not found: $ROADMAP" >&2
  exit 1
fi

if [[ "$IS_PLANNING" = "false" ]]; then
  TASK_PLAN="$PHASE_DIR/tasks/${TASK_ID}-PLAN.md"
  PHASE_PLAN="$PHASE_DIR/${PHASE_ID}-PLAN.md"

  if [[ ! -f "$TASK_PLAN" ]]; then
    echo "build-context.sh: task plan not found: $TASK_PLAN" >&2
    exit 1
  fi

  if [[ ! -f "$PHASE_PLAN" ]]; then
    echo "build-context.sh: phase plan not found: $PHASE_PLAN" >&2
    exit 1
  fi
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

# --- Gather upstream summaries (shared by both modes) ---
gather_upstream_summaries() {
  local summaries=""
  if [[ "$DEPENDS" != "none" && "$CONTEXT_VERBOSITY" != "minimal" ]]; then
    IFS=',' read -ra dep_list <<< "$DEPENDS"
    for dep in "${dep_list[@]}"; do
      dep=$(echo "$dep" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      local summary_file="$MILESTONE_DIR/phases/$dep/${dep}-SUMMARY.md"
      if [[ -f "$summary_file" ]]; then
        summaries="${summaries}
### ${dep} Summary
$(cat "$summary_file")
"
      fi
    done
  fi
  if [[ -z "$summaries" ]]; then
    echo "No upstream summaries available."
  else
    echo "$summaries"
  fi
}

# --- Scope-filtered knowledge (shared) ---
gather_knowledge() {
  local entries=""
  if [[ "$CONTEXT_VERBOSITY" != "minimal" ]]; then
    local knowledge_file="$MILESTONE_DIR/KNOWLEDGE.md"
    if [[ -f "$knowledge_file" ]]; then
      local dep_flag=""
      if [[ "$DEPENDS" != "none" ]]; then
        dep_flag="--depends $DEPENDS"
      fi
      entries=$(bash "$SCOPE_FILTER" "$knowledge_file" "$MILESTONE_ID/$PHASE_ID" --type knowledge $dep_flag 2>/dev/null) || true
    fi
  fi
  if [[ -z "$entries" ]]; then
    echo "No knowledge entries in scope."
  else
    echo "$entries"
  fi
}

# --- Scope-filtered decisions (shared) ---
gather_decisions() {
  local entries=""
  if [[ "$CONTEXT_VERBOSITY" != "minimal" ]]; then
    local decisions_file="$MILESTONE_DIR/DECISIONS.md"
    if [[ -f "$decisions_file" ]]; then
      local dep_flag=""
      if [[ "$DEPENDS" != "none" ]]; then
        dep_flag="--depends $DEPENDS"
      fi
      entries=$(bash "$SCOPE_FILTER" "$decisions_file" "$MILESTONE_ID/$PHASE_ID" --type decisions $dep_flag 2>/dev/null) || true
    fi
  fi
  if [[ -z "$entries" ]]; then
    echo "No decision entries in scope."
  else
    echo "$entries"
  fi
}

UPSTREAM_SUMMARIES=$(gather_upstream_summaries)
KNOWLEDGE_ENTRIES=$(gather_knowledge)
DECISION_ENTRIES=$(gather_decisions)

# ============================================================================
# PHASE_PLAN mode — planning context payload
# ============================================================================
if [[ "$IS_PLANNING" = "true" ]]; then
  # --- Extract roadmap section for this phase ---
  ROADMAP_SECTION=""
  if [[ -f "$ROADMAP" ]]; then
    # Extract the phase block from roadmap (from phase heading to next phase or section)
    ROADMAP_SECTION=$(sed -n "/\\*\\*${PHASE_ID}\\*\\*/,/\\*\\*P[0-9]/p" "$ROADMAP" | sed '$d' || true)
    if [[ -z "$ROADMAP_SECTION" ]]; then
      # Try: last phase (no following phase heading)
      ROADMAP_SECTION=$(sed -n "/\\*\\*${PHASE_ID}\\*\\*/,\$p" "$ROADMAP" || true)
    fi
  fi
  if [[ -z "$ROADMAP_SECTION" ]]; then
    ROADMAP_SECTION="Phase section not found in roadmap."
  fi

  # --- Read context draft if it exists ---
  CONTEXT_DRAFT=""
  CONTEXT_FILE="$ORCH_ROOT/CONTEXT.md"
  if [[ -f "$CONTEXT_FILE" ]]; then
    CONTEXT_DRAFT=$(cat "$CONTEXT_FILE")
  fi
  # Also check milestone-level context
  if [[ -z "$CONTEXT_DRAFT" && -f "$MILESTONE_DIR/CONTEXT.md" ]]; then
    CONTEXT_DRAFT=$(cat "$MILESTONE_DIR/CONTEXT.md")
  fi
  if [[ -z "$CONTEXT_DRAFT" ]]; then
    CONTEXT_DRAFT="No context draft available."
  fi

  # --- Find feature spec ---
  FEATURE_SPEC=""
  # Look for spec.md in specs/ directories at the project root level
  # Walk up from ORCH_ROOT to find the project root (parent of .specify/)
  PROJECT_DIR=""
  candidate="$ORCH_ROOT"
  while [[ "$candidate" != "/" ]]; do
    if [[ "$(basename "$candidate")" = ".specify" ]]; then
      PROJECT_DIR="$(dirname "$candidate")"
      break
    fi
    # Check if .specify/ is a child
    if [[ -d "$candidate/.specify" ]]; then
      PROJECT_DIR="$candidate"
      break
    fi
    candidate="$(dirname "$candidate")"
  done
  if [[ -n "$PROJECT_DIR" ]]; then
    spec_file=$(find "$PROJECT_DIR/specs" -name "spec.md" -type f 2>/dev/null | head -1)
    if [[ -n "$spec_file" && -f "$spec_file" ]]; then
      FEATURE_SPEC=$(cat "$spec_file")
    fi
  fi
  if [[ -z "$FEATURE_SPEC" ]]; then
    FEATURE_SPEC="Feature spec not found."
  fi

  PAYLOAD=$(cat <<PLANNING_EOF
---
schema_version: "1.0"
type: planning-prompt
---

## State Context

- **Current State**: planning
- **Milestone**: $MILESTONE_ID
- **Phase**: $PHASE_ID
- **Tier**: $TIER

## Phase Roadmap Section

$ROADMAP_SECTION

## Upstream Context

$UPSTREAM_SUMMARIES

## Knowledge

$KNOWLEDGE_ENTRIES

## Decisions

$DECISION_ENTRIES

## Context Draft

$CONTEXT_DRAFT

## Feature Spec

$FEATURE_SPEC

## Instructions

Plan phase $PHASE_ID for milestone $MILESTONE_ID following the speckit.orchestrator.plan-phase command.
Produce a phase plan (${PHASE_ID}-PLAN.md) with goal, demo, must-haves, and task breakdown.
Each task plan should be self-contained with zero-context assumptions.
PLANNING_EOF
)

else
# ============================================================================
# Normal task dispatch mode
# ============================================================================

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

fi  # end IS_PLANNING branch

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
