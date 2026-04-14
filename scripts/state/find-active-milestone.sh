#!/usr/bin/env bash
# scripts/state/find-active-milestone.sh — Find the milestone eligible for auto mode
# Scans all milestone directories and returns the first one in a state
# compatible with autonomous execution (executing, planning, summarizing,
# validating, completing).
#
# Usage: find-active-milestone.sh <orchestrator-root>
#        find-active-milestone.sh <orchestrator-root> --all
#
# Default: outputs one line — the first auto-eligible milestone:
#   M### <state> <tier>
#
# --all: outputs one line per milestone with state and tier:
#   M### <state> <tier>
#
# Exit: 0 if found, 1 if no eligible milestone, 2 on error.
#
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DERIVE_PHASE="$SCRIPT_DIR/derive-phase.sh"
READ_ROADMAP="$SCRIPT_DIR/read-roadmap.sh"

SHOW_ALL=false

if [[ $# -lt 1 ]]; then
  echo "find-active-milestone.sh: missing orchestrator-root argument" >&2
  echo "Usage: find-active-milestone.sh <orchestrator-root> [--all]" >&2
  exit 2
fi

ORCH_ROOT="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) SHOW_ALL=true; shift ;;
    *) echo "find-active-milestone.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

MILESTONES_DIR="$ORCH_ROOT/milestones"
if [[ ! -d "$MILESTONES_DIR" ]]; then
  echo "ERROR: milestones directory not found: $MILESTONES_DIR" >&2
  exit 2
fi

# Auto-eligible states (ordered by priority)
auto_states="executing planning summarizing validating completing"

found_eligible=false

# Process milestones in sorted order
for milestone_dir in "$MILESTONES_DIR"/M[0-9]*; do
  [[ -d "$milestone_dir" ]] || continue
  mid=$(basename "$milestone_dir")

  # Derive state
  state=$(bash "$DERIVE_PHASE" "$milestone_dir" 2>/dev/null) || state="error"

  # Get tier from roadmap (if exists)
  roadmap="$milestone_dir/${mid}-ROADMAP.md"
  if [[ -f "$roadmap" ]]; then
    tier=$(bash "$READ_ROADMAP" "$roadmap" tier 2>/dev/null) || tier="unknown"
  else
    tier="none"
  fi

  if [[ "$SHOW_ALL" = "true" ]]; then
    echo "$mid $state $tier"
    continue
  fi

  # Check if this state is auto-eligible and tier is C
  if [[ "$tier" = "C" ]]; then
    for s in $auto_states; do
      if [[ "$state" = "$s" ]]; then
        echo "$mid $state $tier"
        found_eligible=true
        break 2
      fi
    done
  fi
done

if [[ "$SHOW_ALL" = "true" ]]; then
  exit 0
fi

if [[ "$found_eligible" = "false" ]]; then
  echo "NONE"
  exit 1
fi
