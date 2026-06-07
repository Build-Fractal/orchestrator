#!/usr/bin/env bash
# scripts/knowledge/resolve-entries.sh — Resolve entry IDs to their detail file content
# Given a list of entry IDs (one per line on stdin or as arguments), reads their
# detail files and outputs the content.
#
# Usage: echo "MEM042\nMEM015" | resolve-entries.sh
#    or: resolve-entries.sh MEM042 MEM015
#
# Output: full content of each resolved detail file, separated by blank lines.
# Warnings for unresolved IDs go to stderr.
# Exit 0 always.
#
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"

root="$(get_project_root)"

# --- Collect IDs from args or stdin ---
ids=""
if [ $# -gt 0 ]; then
  for arg in "$@"; do
    ids="$ids $arg"
  done
else
  while IFS= read -r line || [ -n "$line" ]; do
    # Trim whitespace
    line="$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    ids="$ids $line"
  done
fi

# --- Resolve each ID ---
first=true
for entry_id in $ids; do
  found=false
  for file in "$root"/knowledge/*/"${entry_id}.md"; do
    if [ -f "$file" ]; then
      # M044/FR-4: scope the archive skip to the knowledge/ subtree (relative
      # path), not the absolute path — preserve the genuine knowledge/archive/
      # exclusion (CON-4) without zeroing a project rooted under a dir named
      # `archive` (B-4).
      rel_knowledge="${file#$root/knowledge/}"
      case "$rel_knowledge" in
        archive/*|*/archive/*) continue ;;
      esac
      # Add blank line separator between entries (not before the first one)
      if [ "$first" = true ]; then
        first=false
      else
        echo ""
      fi
      cat "$file"
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    echo "WARNING: Entry $entry_id not found in knowledge/" >&2
  fi
done

exit 0
