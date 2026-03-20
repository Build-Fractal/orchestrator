#!/usr/bin/env bash
# scripts/knowledge/append-knowledge.sh — Append a scoped knowledge entry to KNOWLEDGE.md
# Usage: append-knowledge.sh <knowledge-file> <entry-text> <scope>
#
# Scope format per FR-062: project, milestone:M###, or phase:M###/P##
# Appends entry with scope tag and ISO 8601 date.
# Format: - **[<scope>]** [<date>] <entry-text>
#
# If the file doesn't exist, exits non-zero with error.
# Outputs "KNOWLEDGE: entry appended with scope [<scope>]" on success.
#
# Bash 3.2 compatible (no declare -A per K001).

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: append-knowledge.sh <knowledge-file> <entry-text> <scope>

Arguments:
  knowledge-file  Path to KNOWLEDGE.md (must exist)
  entry-text      The knowledge entry to record
  scope           Scope tag: project | milestone:M### | phase:M###/P##

Example:
  append-knowledge.sh .specify/orchestrator/KNOWLEDGE.md \
    "All state scripts must handle missing .specify/orchestrator/ dir" \
    "milestone:M001"
EOF
  exit 1
}

if [ $# -lt 3 ]; then
  echo "ERROR: append-knowledge.sh requires 3 arguments: <knowledge-file> <entry-text> <scope>" >&2
  usage
fi

KNOWLEDGE_FILE="$1"
ENTRY_TEXT="$2"
SCOPE="$3"

# File must exist
if [ ! -f "$KNOWLEDGE_FILE" ]; then
  echo "ERROR: Knowledge file does not exist: $KNOWLEDGE_FILE" >&2
  exit 1
fi

# Validate scope format
case "$SCOPE" in
  project) ;;
  milestone:M[0-9][0-9][0-9]) ;;
  phase:M[0-9][0-9][0-9]/P[0-9][0-9]) ;;
  *)
    echo "ERROR: Invalid scope '$SCOPE'. Must be 'project', 'milestone:M###', or 'phase:M###/P##'." >&2
    exit 1
    ;;
esac

# Get current date in ISO 8601 format
TODAY=$(date +%Y-%m-%d)

# Append entry (never modify existing content)
echo "- **[$SCOPE]** [$TODAY] $ENTRY_TEXT" >> "$KNOWLEDGE_FILE"

echo "KNOWLEDGE: entry appended with scope [$SCOPE]"
