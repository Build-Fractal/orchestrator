#!/usr/bin/env bash
# scripts/lifecycle/sync-roadmap.sh — Cross-reference roadmap checkboxes with disk state
# Compares roadmap phase checkboxes ([x]/[ ]) with P##-SUMMARY.md existence.
# Reports mismatches and optionally updates checkboxes to match disk state.
#
# Usage: sync-roadmap.sh <roadmap-file> <milestone-dir> [--fix]
#
# Arguments:
#   <roadmap-file>     Path to M###-ROADMAP.md
#   <milestone-dir>    Path to milestone directory containing phases/
#   --fix              Update roadmap checkboxes to match disk state (default: report only)
#
# Structured output (stdout):
#   SYNC:OK                                              — all checkboxes match disk
#   SYNC:MISMATCH phase=P## roadmap=complete disk=incomplete  — checkbox [x] but no summary
#   SYNC:MISMATCH phase=P## roadmap=incomplete disk=complete  — checkbox [ ] but summary exists
#   SYNC:FIXED phase=P## old=complete new=incomplete     — checkbox updated (--fix mode)
#   SYNC:FIXED phase=P## old=incomplete new=complete     — checkbox updated (--fix mode)
#
# Always exits 0 (informational).
# Exits 1 only for missing arguments or missing files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROADMAP_SCRIPT="$(cd "$SCRIPT_DIR/../state" && pwd)/read-roadmap.sh"

# --- Argument parsing ---
if [[ $# -lt 2 ]]; then
  echo "sync-roadmap.sh: requires <roadmap-file> <milestone-dir> [--fix]" >&2
  echo "Usage: sync-roadmap.sh <roadmap-file> <milestone-dir> [--fix]" >&2
  exit 1
fi

ROADMAP_FILE="$1"
MILESTONE_DIR="$2"
FIX_MODE=false

if [[ $# -ge 3 && "$3" = "--fix" ]]; then
  FIX_MODE=true
fi

# --- Validate inputs ---
if [[ ! -f "$ROADMAP_FILE" ]]; then
  echo "sync-roadmap.sh: roadmap file not found: $ROADMAP_FILE" >&2
  exit 1
fi

if [[ ! -d "$MILESTONE_DIR" ]]; then
  echo "sync-roadmap.sh: milestone directory not found: $MILESTONE_DIR" >&2
  exit 1
fi

# --- Read phase data from roadmap ---
phases_data=$(bash "$ROADMAP_SCRIPT" "$ROADMAP_FILE" phases 2>/dev/null) || true

if [[ -z "$phases_data" ]]; then
  echo "SYNC:OK"
  exit 0
fi

# --- Compare each phase ---
has_mismatch=false

while IFS=' ' read -r pid pstatus prisk pdepends; do
  [[ -z "$pid" ]] && continue

  # Determine disk state: summary exists = complete
  phase_summary="$MILESTONE_DIR/phases/${pid}/${pid}-SUMMARY.md"
  if [[ -f "$phase_summary" ]]; then
    disk_state="complete"
  else
    disk_state="incomplete"
  fi

  # Compare roadmap state with disk state
  if [[ "$pstatus" = "complete" && "$disk_state" = "incomplete" ]]; then
    has_mismatch=true
    echo "SYNC:MISMATCH phase=$pid roadmap=complete disk=incomplete"
    if [[ "$FIX_MODE" = "true" ]]; then
      # Change [x] to [ ] for this phase
      sed -i.bak "s/- \[x\] \*\*${pid}\*\*/- [ ] **${pid}**/" "$ROADMAP_FILE"
      rm -f "${ROADMAP_FILE}.bak"
      echo "SYNC:FIXED phase=$pid old=complete new=incomplete"
    fi
  elif [[ "$pstatus" = "incomplete" && "$disk_state" = "complete" ]]; then
    has_mismatch=true
    echo "SYNC:MISMATCH phase=$pid roadmap=incomplete disk=complete"
    if [[ "$FIX_MODE" = "true" ]]; then
      # Change [ ] to [x] for this phase
      sed -i.bak "s/- \[ \] \*\*${pid}\*\*/- [x] **${pid}**/" "$ROADMAP_FILE"
      rm -f "${ROADMAP_FILE}.bak"
      echo "SYNC:FIXED phase=$pid old=incomplete new=complete"
    fi
  fi
done <<< "$phases_data"

if [[ "$has_mismatch" = "false" ]]; then
  echo "SYNC:OK"
fi
