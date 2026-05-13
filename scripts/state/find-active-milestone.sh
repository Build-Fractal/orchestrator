#!/usr/bin/env bash
# scripts/state/find-active-milestone.sh — Find the milestone eligible for auto mode
# Scans all milestone directories and returns the first one in a state
# compatible with autonomous execution (executing, planning, summarizing,
# validating, completing).
#
# Usage: find-active-milestone.sh <orchestrator-root>
#        find-active-milestone.sh <orchestrator-root> --all
#        find-active-milestone.sh <orchestrator-root> --milestone M###
#
# Default: outputs one line — the first auto-eligible milestone:
#   M### <state> <tier>
#
# --all: outputs one line per milestone with state and tier:
#   M### <state> <tier>
#
# --milestone M###: targets a specific milestone. Validates that it exists
#   on disk, is tier C, and is in an auto-eligible state. Fails loud with
#   a specific reason if any condition isn't met — use this path from
#   orchestrator:auto when the caller named a particular milestone rather
#   than accepting the numerically-first planning milestone.
#
# Exit: 0 if found, 1 if no eligible milestone, 2 on error.
#
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DERIVE_PHASE="$SCRIPT_DIR/derive-phase.sh"
READ_ROADMAP="$SCRIPT_DIR/read-roadmap.sh"

SHOW_ALL=false
TARGET_MILESTONE=""

if [[ $# -lt 1 ]]; then
  echo "find-active-milestone.sh: missing orchestrator-root argument" >&2
  echo "Usage: find-active-milestone.sh <orchestrator-root> [--all | --milestone M###]" >&2
  exit 2
fi

ORCH_ROOT="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) SHOW_ALL=true; shift ;;
    --milestone)
      TARGET_MILESTONE="$2"; shift 2
      if [[ ! "$TARGET_MILESTONE" =~ ^M[A-Za-z0-9-]+$ ]]; then
        echo "find-active-milestone.sh: --milestone expects M-prefixed identifier (e.g. M001, M2a-min, M-Reporter-scope), got '$TARGET_MILESTONE'" >&2
        exit 2
      fi
      ;;
    --milestone=*)
      TARGET_MILESTONE="${1#--milestone=}"; shift
      if [[ ! "$TARGET_MILESTONE" =~ ^M[A-Za-z0-9-]+$ ]]; then
        echo "find-active-milestone.sh: --milestone expects M-prefixed identifier (e.g. M001, M2a-min, M-Reporter-scope), got '$TARGET_MILESTONE'" >&2
        exit 2
      fi
      ;;
    *) echo "find-active-milestone.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

if [[ "$SHOW_ALL" = "true" && -n "$TARGET_MILESTONE" ]]; then
  echo "find-active-milestone.sh: --all and --milestone are mutually exclusive" >&2
  exit 2
fi

MILESTONES_DIR="$ORCH_ROOT/milestones"
if [[ ! -d "$MILESTONES_DIR" ]]; then
  echo "ERROR: milestones directory not found: $MILESTONES_DIR" >&2
  exit 2
fi

# Auto-eligible states (ordered by priority)
auto_states="executing planning summarizing validating completing"

# --milestone path: validate the named target, fail loud with a specific
# reason if it isn't auto-eligible.
if [[ -n "$TARGET_MILESTONE" ]]; then
  milestone_dir="$MILESTONES_DIR/$TARGET_MILESTONE"
  if [[ ! -d "$milestone_dir" ]]; then
    echo "ERROR: milestone '$TARGET_MILESTONE' not found under $MILESTONES_DIR" >&2
    exit 1
  fi
  mid="$TARGET_MILESTONE"
  state=$(bash "$DERIVE_PHASE" "$milestone_dir" 2>/dev/null) || state="error"

  evaluation="$milestone_dir/${mid}-EVALUATION.md"
  roadmap="$milestone_dir/${mid}-ROADMAP.md"
  if [[ -f "$evaluation" ]]; then
    tier=$(bash "$READ_ROADMAP" "$evaluation" tier 2>/dev/null) || tier="unknown"
  elif [[ -f "$roadmap" ]]; then
    tier=$(bash "$READ_ROADMAP" "$roadmap" tier 2>/dev/null) || tier="unknown"
  else
    tier="none"
  fi

  if [[ "$tier" != "C" ]]; then
    echo "ERROR: milestone '$mid' is tier '$tier' — auto mode is Tier C only" >&2
    exit 1
  fi

  for s in $auto_states; do
    if [[ "$state" = "$s" ]]; then
      echo "$mid $state $tier"
      exit 0
    fi
  done

  echo "ERROR: milestone '$mid' is in state '$state' — not auto-eligible (need one of: $auto_states)" >&2
  exit 1
fi

found_eligible=false

# Process milestones in sorted order. Iterator includes both numeric (M001)
# and non-numeric (M2a-min, M-Reporter-scope) forms. `M[0-9]*` previously
# silently skipped M-prefixed-hyphen milestones like M-Spike-A.
for milestone_dir in "$MILESTONES_DIR"/M*; do
  [[ -d "$milestone_dir" ]] || continue
  mid=$(basename "$milestone_dir")
  # Skip sentinel directories (e.g. _imported-context). Milestones never
  # start with an underscore — the M* glob already filters them, but a
  # belt-and-suspenders skip keeps the loop tolerant of future renames.
  [[ "$mid" == _* ]] && continue

  # Derive state
  state=$(bash "$DERIVE_PHASE" "$milestone_dir" 2>/dev/null) || state="error"

  # Get tier — EVALUATION.md is the tier authority (per commands/evaluate.md);
  # fall back to ROADMAP.md for milestones that predate evaluation artifacts.
  evaluation="$milestone_dir/${mid}-EVALUATION.md"
  roadmap="$milestone_dir/${mid}-ROADMAP.md"
  if [[ -f "$evaluation" ]]; then
    tier=$(bash "$READ_ROADMAP" "$evaluation" tier 2>/dev/null) || tier="unknown"
  elif [[ -f "$roadmap" ]]; then
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
