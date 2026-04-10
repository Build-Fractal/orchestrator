#!/usr/bin/env bash
# scripts/knowledge/traverse-graph.sh — Traverse knowledge entry relationship graph
# Given an entry ID, returns related entry IDs (1-hop by default, max 5, cycle-safe).
#
# Usage: traverse-graph.sh --id MEM042 [--max-depth 1] [--max-entries 5]
#
# Output: one related entry ID per line to stdout
# Warnings go to stderr. Exit 0 always (no related entries is valid).
#
# Bash 3.2 compatible (no associative arrays, no mapfile).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"

# --- Defaults ---
entry_id=""
max_depth=1
max_entries=5

# --- Argument parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --id)
      entry_id="$2"
      shift 2
      ;;
    --max-depth)
      max_depth="$2"
      shift 2
      ;;
    --max-entries)
      max_entries="$2"
      shift 2
      ;;
    *)
      echo "traverse-graph.sh: unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

if [ -z "$entry_id" ]; then
  echo "traverse-graph.sh: --id is required" >&2
  exit 1
fi

# --- Temp files for cycle safety and BFS ---
visited_file="$(mktemp)"
current_frontier="$(mktemp)"
next_frontier="$(mktemp)"
output_file="$(mktemp)"
trap 'rm -f "$visited_file" "$current_frontier" "$next_frontier" "$output_file"' EXIT

# --- Helper: find detail file for an ID (skips archive) ---
find_detail_file() {
  local fid="$1"
  local root
  root="$(get_project_root)"
  for file in "$root"/knowledge/*/"${fid}.md"; do
    if [ -f "$file" ]; then
      case "$file" in
        */archive/*) continue ;;
      esac
      echo "$file"
      return 0
    fi
  done
  return 1
}

# --- Helper: extract relates_to IDs from a detail file's YAML frontmatter ---
get_related_ids() {
  local file="$1"
  local relates_line
  relates_line="$(sed -n '/^---$/,/^---$/p' "$file" | grep '^relates_to:' | head -1)" || true
  if [ -z "$relates_line" ]; then
    return 0
  fi
  # Extract IDs from YAML inline list: relates_to: [ID1, ID2]
  echo "$relates_line" | sed 's/relates_to:[[:space:]]*//' | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | grep -v '^$' || true
}

# --- Helper: check if an ID is in the visited file ---
is_visited() {
  local check_id="$1"
  grep -qx "$check_id" "$visited_file" 2>/dev/null
}

# --- BFS traversal ---
# Mark the starting entry as visited (don't output it)
echo "$entry_id" >> "$visited_file"
echo "$entry_id" > "$current_frontier"

output_count=0
current_depth=0
truncated=false

while [ "$current_depth" -lt "$max_depth" ] && [ "$truncated" = false ]; do
  # Clear next frontier
  > "$next_frontier"

  # Read current frontier line by line (avoid subshell from pipe)
  while IFS= read -r frontier_id || [ -n "$frontier_id" ]; do
    [ -z "$frontier_id" ] && continue

    # Find detail file for this frontier ID
    local_file=""
    local_file="$(find_detail_file "$frontier_id" 2>/dev/null)" || continue

    # Get related IDs into a temp variable
    related_ids="$(get_related_ids "$local_file")"
    if [ -z "$related_ids" ]; then
      continue
    fi

    # Process each related ID (use here-string alternative for Bash 3.2)
    while IFS= read -r rel_id; do
      [ -z "$rel_id" ] && continue

      # Skip if already visited
      if is_visited "$rel_id"; then
        continue
      fi

      # Mark as visited
      echo "$rel_id" >> "$visited_file"

      # Check if this ID resolves to a knowledge file
      if find_detail_file "$rel_id" >/dev/null 2>&1; then
        # Check max_entries limit
        if [ "$output_count" -ge "$max_entries" ]; then
          truncated=true
          break
        fi
        echo "$rel_id" >> "$output_file"
        echo "$rel_id" >> "$next_frontier"
        output_count=$((output_count + 1))
      fi
    done <<EOF_RELATED
$related_ids
EOF_RELATED

    if [ "$truncated" = true ]; then
      break
    fi

  done < "$current_frontier"

  # Swap frontiers for next depth level
  cp "$next_frontier" "$current_frontier"

  # Check if frontier is empty (no more to traverse)
  if [ ! -s "$current_frontier" ]; then
    break
  fi

  current_depth=$((current_depth + 1))
done

# Output results
if [ -s "$output_file" ]; then
  cat "$output_file"
fi

if [ "$truncated" = true ]; then
  echo "WARNING: max-entries limit ($max_entries) reached, results truncated" >&2
fi

exit 0
