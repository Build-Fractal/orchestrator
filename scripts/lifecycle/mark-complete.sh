#!/usr/bin/env bash
# scripts/lifecycle/mark-complete.sh — Create milestone validation marker
# Implements milestone validation per D003 (M###-VALIDATED marker file).
#
# Usage: mark-complete.sh <orchestrator-root> <milestone-id>
#
# Behavior:
#   - Verifies all phases in the roadmap have P##-SUMMARY.md
#   - Creates M###-VALIDATED marker file with milestone ID, timestamp, phase list
#   - Idempotent: if marker already exists, outputs "already validated" and exits 0
#   - Outputs structured VALIDATE: messages on stdout
#   - Reports errors to stderr with non-zero exit
#
# Bash 3.2 compatible (no declare -A per K001).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
READ_ROADMAP="$PROJECT_ROOT/scripts/state/read-roadmap.sh"

usage() {
  cat <<'EOF'
Usage: mark-complete.sh <orchestrator-root> <milestone-id>

Arguments:
  orchestrator-root  Path to .orchestrator (or equivalent state root)
  milestone-id       Milestone ID (e.g., M001)

Creates M###-VALIDATED marker file when all phases are complete.
Idempotent — re-running on a validated milestone exits 0.
EOF
  exit 1
}

if [ $# -lt 2 ]; then
  echo "ERROR: mark-complete.sh requires 2 arguments." >&2
  usage
fi

ORCH_ROOT="$1"
MILESTONE_ID="$2"

MILESTONE_DIR="$ORCH_ROOT/milestones/$MILESTONE_ID"
ROADMAP_FILE="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"
MARKER_FILE="$MILESTONE_DIR/${MILESTONE_ID}-VALIDATED"

# Validate milestone directory exists
if [ ! -d "$MILESTONE_DIR" ]; then
  echo "ERROR: Milestone directory does not exist: $MILESTONE_DIR" >&2
  exit 1
fi

# Idempotent check — already validated
if [ -f "$MARKER_FILE" ]; then
  echo "VALIDATE: $MILESTONE_ID already validated"
  exit 0
fi

# Validate roadmap exists
if [ ! -f "$ROADMAP_FILE" ]; then
  echo "ERROR: Roadmap not found: $ROADMAP_FILE" >&2
  exit 1
fi

# Get all phases from roadmap
phases_output=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" phases 2>/dev/null) || {
  echo "ERROR: Failed to read roadmap: $ROADMAP_FILE" >&2
  exit 1
}

# Verify all phases have summaries
phase_count=0
incomplete_phases=""
phase_list=""

while IFS=' ' read -r pid pstatus prisk pdepends; do
  if [ -z "$pid" ]; then
    continue
  fi
  phase_count=$((phase_count + 1))

  phase_dir="$MILESTONE_DIR/phases/$pid"
  summary_file="$phase_dir/${pid}-SUMMARY.md"

  if [ -f "$summary_file" ]; then
    phase_list="${phase_list}${pid}: complete\n"
  else
    incomplete_phases="${incomplete_phases} $pid"
    phase_list="${phase_list}${pid}: incomplete\n"
  fi
done <<< "$phases_output"

# Exit non-zero if any phase is incomplete
if [ -n "$incomplete_phases" ]; then
  echo "ERROR: Incomplete phases:${incomplete_phases}" >&2
  exit 1
fi

# Create validation marker
VALIDATION_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$MARKER_FILE" <<EOF
# Milestone Validation Marker

milestone: $MILESTONE_ID
validated_at: $VALIDATION_TIMESTAMP
phase_count: $phase_count

## Phase Results

$(printf "%b" "$phase_list")
EOF

echo "VALIDATE: $MILESTONE_ID validated with $phase_count phases complete"
