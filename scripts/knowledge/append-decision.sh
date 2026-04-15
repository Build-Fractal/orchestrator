#!/usr/bin/env bash
# scripts/knowledge/append-decision.sh — Append a decision row to DECISIONS.md
# Usage: append-decision.sh <decisions-file> <when> <scope> <decision> <choice> <rationale> [revisable]
#
# Reads existing DECISIONS.md, finds the highest D### ID, assigns the next sequential ID.
# Appends a new markdown table row. Never modifies existing rows (append-only per FR-025).
# Column order: #, When, Scope, Decision, Choice, Rationale, Revisable?
#
# If the file doesn't exist, exits non-zero with error.
# Outputs "DECISION: D### appended" on success.
#
# Bash 3.2 compatible (no declare -A per K001).

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: append-decision.sh <decisions-file> <when> <scope> <decision> <choice> <rationale> [revisable]

Arguments:
  decisions-file  Path to DECISIONS.md (must exist)
  when            Unit scope (e.g., M001/P01/T01)
  scope           Decision scope (arch|pattern|library|data|api|scope|convention)
  decision        The question being decided
  choice          The answer/choice made
  rationale       Why this choice was made
  revisable       Optional. Default: "Yes". Use "No" or "Yes — <condition>"

Example:
  append-decision.sh .orchestrator/DECISIONS.md \
    "M001/P01/T01" "arch" "State derivation mechanism?" \
    "File-presence-based" "Crash recovery derives state from what exists" "No"
EOF
  exit 1
}

if [ $# -lt 6 ]; then
  echo "ERROR: append-decision.sh requires at least 6 arguments." >&2
  usage
fi

DECISIONS_FILE="$1"
WHEN="$2"
SCOPE="$3"
DECISION="$4"
CHOICE="$5"
RATIONALE="$6"
REVISABLE="${7:-Yes}"

# File must exist
if [ ! -f "$DECISIONS_FILE" ]; then
  echo "ERROR: Decisions file does not exist: $DECISIONS_FILE" >&2
  exit 1
fi

# Find the highest existing D### ID
# Look for patterns like "| D001 " or "| D123 " in table rows
highest_id=0
while IFS= read -r line; do
  # Match lines that contain a D### pattern in a table cell
  if echo "$line" | grep -qE '^\|[[:space:]]*D[0-9]+'; then
    # Extract the number after D
    d_num=$(echo "$line" | sed -E 's/^\|[[:space:]]*D0*([0-9]+).*/\1/')
    if [ "$d_num" -gt "$highest_id" ] 2>/dev/null; then
      highest_id=$d_num
    fi
  fi
done < "$DECISIONS_FILE"

# Compute next ID
next_num=$((highest_id + 1))
next_id=$(printf "D%03d" "$next_num")

# Append the new row (never modify existing content)
echo "| $next_id | $WHEN | $SCOPE | $DECISION | $CHOICE | $RATIONALE | $REVISABLE |" >> "$DECISIONS_FILE"

echo "DECISION: $next_id appended"
