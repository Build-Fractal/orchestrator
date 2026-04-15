#!/usr/bin/env bash
# scripts/lifecycle/rollback-phase.sh — Roll back a phase, archiving prior work
# Implements FR-057 (downstream dep flagging) and FR-058 (archive preservation).
#
# Usage: rollback-phase.sh <orchestrator-root> <milestone-id> <phase-id> <reason>
#
# Behavior:
#   - Verifies phase directory exists and has P##-SUMMARY.md
#   - Creates archive/ under the phase dir
#   - Moves P##-SUMMARY.md and T##-SUMMARY.md to archive/ with timestamp prefix
#   - Identifies downstream phases that depend on the rolled-back phase
#   - Appends a reversal decision to DECISIONS.md via append-decision.sh
#   - Outputs structured ROLLBACK: messages on stdout
#   - Reports errors to stderr with non-zero exit
#
# Bash 3.2 compatible (no declare -A per K001).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APPEND_DECISION="$PROJECT_ROOT/scripts/knowledge/append-decision.sh"
READ_ROADMAP="$PROJECT_ROOT/scripts/state/read-roadmap.sh"

usage() {
  cat <<'EOF'
Usage: rollback-phase.sh <orchestrator-root> <milestone-id> <phase-id> <reason>

Arguments:
  orchestrator-root  Path to .orchestrator (or equivalent state root)
  milestone-id       Milestone ID (e.g., M001)
  phase-id           Phase to roll back (e.g., P01)
  reason             Human-readable reason for the rollback

Archives phase and task summaries with timestamp prefix, flags downstream
dependent phases, and records a reversal decision in DECISIONS.md.
EOF
  exit 1
}

if [ $# -lt 4 ]; then
  echo "ERROR: rollback-phase.sh requires 4 arguments." >&2
  usage
fi

ORCH_ROOT="$1"
MILESTONE_ID="$2"
PHASE_ID="$3"
REASON="$4"

MILESTONE_DIR="$ORCH_ROOT/milestones/$MILESTONE_ID"
PHASE_DIR="$MILESTONE_DIR/phases/$PHASE_ID"
ROADMAP_FILE="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"
DECISIONS_FILE="$ORCH_ROOT/DECISIONS.md"

# Validate phase directory exists
if [ ! -d "$PHASE_DIR" ]; then
  echo "ERROR: Phase directory does not exist: $PHASE_DIR" >&2
  exit 1
fi

# Validate phase has a summary to roll back
SUMMARY_FILE="$PHASE_DIR/${PHASE_ID}-SUMMARY.md"
if [ ! -f "$SUMMARY_FILE" ]; then
  echo "ERROR: Phase $PHASE_ID has no summary to roll back: $SUMMARY_FILE" >&2
  exit 1
fi

# Create archive directory
ARCHIVE_DIR="$PHASE_DIR/archive"
mkdir -p "$ARCHIVE_DIR"

# Generate timestamp for archive prefix
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Move phase summary to archive
mv "$SUMMARY_FILE" "$ARCHIVE_DIR/${TIMESTAMP}-${PHASE_ID}-SUMMARY.md"

# Move task summaries to archive
task_count=0
for task_summary in "$PHASE_DIR"/T*-SUMMARY.md; do
  if [ -f "$task_summary" ]; then
    basename_file=$(basename "$task_summary")
    mv "$task_summary" "$ARCHIVE_DIR/${TIMESTAMP}-${basename_file}"
    task_count=$((task_count + 1))
  fi
done

# Identify downstream dependent phases using read-roadmap.sh
downstream_count=0
if [ -f "$ROADMAP_FILE" ] && [ -x "$READ_ROADMAP" ]; then
  # Get all phases and their dependencies
  phases_output=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" phases 2>/dev/null) || true

  # Find phases that depend on the rolled-back phase
  # IFS modification wrapped to avoid leaking into parent scope
  while IFS=' ' read -r pid pstatus prisk pdepends; do
    if [ -z "$pid" ]; then
      continue
    fi
    # Check if this phase depends on the rolled-back phase
    # pdepends is comma-separated list like "P01" or "P01,P02" or "none"
    if [ "$pdepends" != "none" ]; then
      # Check each dependency (subshell isolates IFS change)
      if (IFS=','; for dep in $pdepends; do
            dep=$(echo "$dep" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [ "$dep" = "$PHASE_ID" ]; then exit 0; fi
          done; exit 1); then
        echo "ROLLBACK: downstream $pid flagged for review"
        downstream_count=$((downstream_count + 1))
      fi
    fi
  done <<< "$phases_output"
fi

# Append reversal decision to DECISIONS.md
if [ -f "$DECISIONS_FILE" ] && [ -x "$APPEND_DECISION" ]; then
  bash "$APPEND_DECISION" "$DECISIONS_FILE" \
    "${MILESTONE_ID}/${PHASE_ID}" "lifecycle" \
    "Rollback ${PHASE_ID}?" "Rolled back" \
    "Reason: ${REASON}" "No" > /dev/null 2>&1 || true
fi

echo "ROLLBACK: $PHASE_ID rolled back, $downstream_count downstream phases flagged"
