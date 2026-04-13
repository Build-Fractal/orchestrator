#!/usr/bin/env bash
# scripts/util/detect-milestone-id.sh — Detect milestone ID from directory
# Single-script replacement for find|head|xargs|grep pipeline that triggers
# Claude Code harness safety heuristics (AD-19).
#
# Usage: detect-milestone-id.sh <milestone-dir>
#
# Output (stdout): M### (e.g., M001) or the directory basename as fallback.
# Exit 0 always.
# Bash 3.2 compatible.

set -euo pipefail

MILESTONE_DIR="${1:?Usage: detect-milestone-id.sh <milestone-dir>}"

# Try to find M###-*.md files
for f in "$MILESTONE_DIR"/M[0-9]*-*; do
  if [[ -e "$f" ]]; then
    base="$(basename "$f")"
    # Extract M### prefix
    id="${base%%-*}"
    if [[ "$id" =~ ^M[0-9]+ ]]; then
      echo "$id"
      exit 0
    fi
  fi
done

# Fallback to directory basename
echo "$(basename "$MILESTONE_DIR")"
