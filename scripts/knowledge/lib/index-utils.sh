#!/usr/bin/env bash
# scripts/knowledge/lib/index-utils.sh — Shared index read/write utilities
# Source this file to use index helper functions.
#
# Index format (AD-2, FR-101):
#   MEM### | [scope_tags] | category | confidence | created_at | verified:date | hits:N | description
#
# The index file (KNOWLEDGE-INDEX.md) has a header section (lines starting with # or |)
# followed by data lines (one per entry). Data lines use pipe delimiters.
#
# All index writes use the atomic temp-file-then-mv pattern (FR-109).
# Bash 3.2 compatible.

# Default index path relative to project root
DEFAULT_INDEX_PATH="KNOWLEDGE-INDEX.md"

# Get the project root (walk up from script location to find extension.yml)
get_project_root() {
  local dir
  if [ -n "${PROJECT_ROOT:-}" ]; then
    echo "$PROJECT_ROOT"
    return
  fi
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  # Walk up to find extension.yml
  local candidate="$dir"
  while [ "$candidate" != "/" ]; do
    if [ -f "$candidate/extension.yml" ]; then
      echo "$candidate"
      return
    fi
    candidate="$(dirname "$candidate")"
  done
  # Fallback: two levels up from lib/
  echo "$dir"
}

# Get the index file path
get_index_path() {
  local root
  root="$(get_project_root)"
  echo "$root/$DEFAULT_INDEX_PATH"
}

# Initialize the index file if it doesn't exist
# Creates the header with format documentation
init_index() {
  local index_path
  index_path="$(get_index_path)"

  if [ -f "$index_path" ]; then
    return 0
  fi

  cat > "$index_path" <<'HEADER'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
HEADER
}

# Add an entry line to the index atomically
# Usage: index_add_entry <entry_line>
# The entry_line should be pre-formatted: MEM### | [tags] | cat | conf | date | verified:date | hits:N | desc
index_add_entry() {
  local entry_line="$1"
  local index_path
  index_path="$(get_index_path)"

  init_index

  local tmp_file="${index_path}.tmp.$$"
  # Copy existing index and append new entry
  cp "$index_path" "$tmp_file"
  echo "$entry_line" >> "$tmp_file"
  mv "$tmp_file" "$index_path"
}

# Remove an entry from the index by ID atomically
# Usage: index_remove_entry <entry_id>
index_remove_entry() {
  local entry_id="$1"
  local index_path
  index_path="$(get_index_path)"

  if [ ! -f "$index_path" ]; then
    return 0
  fi

  local tmp_file="${index_path}.tmp.$$"
  # Copy everything except lines starting with the entry ID
  grep -v "^${entry_id} |" "$index_path" > "$tmp_file" || true
  mv "$tmp_file" "$index_path"
}

# Update an entry in the index atomically (remove old, add new)
# Usage: index_update_entry <entry_id> <new_entry_line>
index_update_entry() {
  local entry_id="$1"
  local new_entry_line="$2"
  local index_path
  index_path="$(get_index_path)"

  if [ ! -f "$index_path" ]; then
    index_add_entry "$new_entry_line"
    return
  fi

  local tmp_file="${index_path}.tmp.$$"
  # Remove old entry and add new one
  grep -v "^${entry_id} |" "$index_path" > "$tmp_file" || true
  echo "$new_entry_line" >> "$tmp_file"
  mv "$tmp_file" "$index_path"
}

# Check if an entry exists in the index
# Usage: index_has_entry <entry_id>
# Returns 0 if found, 1 if not
index_has_entry() {
  local entry_id="$1"
  local index_path
  index_path="$(get_index_path)"

  if [ ! -f "$index_path" ]; then
    return 1
  fi

  grep -q "^${entry_id} |" "$index_path"
}

# Read an entry line from the index
# Usage: index_get_entry <entry_id>
# Outputs the full pipe-delimited line to stdout
index_get_entry() {
  local entry_id="$1"
  local index_path
  index_path="$(get_index_path)"

  if [ ! -f "$index_path" ]; then
    return 1
  fi

  grep "^${entry_id} |" "$index_path"
}

# Format an index entry line from individual fields
# Usage: format_index_entry <id> <scope_tags> <category> <confidence> <created_at> <last_verified> <hit_count> <description>
format_index_entry() {
  local id="$1"
  local scope_tags="$2"
  local category="$3"
  local confidence="$4"
  local created_at="$5"
  local last_verified="$6"
  local hit_count="$7"
  local description="$8"

  echo "${id} | ${scope_tags} | ${category} | ${confidence} | ${created_at} | verified:${last_verified} | hits:${hit_count} | ${description}"
}

# Get the next available MEM### ID by scanning the index
# Usage: next_entry_id
# Output: MEM### where ### is the next sequential number
next_entry_id() {
  local index_path
  index_path="$(get_index_path)"

  local max_num=0
  if [ -f "$index_path" ]; then
    # Extract all MEM### IDs and find the highest number
    local num
    while IFS= read -r line; do
      num=$(echo "$line" | grep -oE '^MEM[0-9]+' | sed 's/MEM//')
      if [ -n "$num" ]; then
        # Remove leading zeros for arithmetic
        num=$(echo "$num" | sed 's/^0*//')
        num="${num:-0}"
        if [ "$num" -gt "$max_num" ] 2>/dev/null; then
          max_num="$num"
        fi
      fi
    done < "$index_path"
  fi

  # Also scan detail files in case index is out of date
  local root
  root="$(get_project_root)"
  if [ -d "$root/knowledge" ]; then
    local file num
    for file in "$root"/knowledge/*/MEM*.md "$root"/knowledge/archive/MEM*.md; do
      if [ -f "$file" ]; then
        num=$(basename "$file" .md | sed 's/MEM//')
        num=$(echo "$num" | sed 's/^0*//')
        num="${num:-0}"
        if [ "$num" -gt "$max_num" ] 2>/dev/null; then
          max_num="$num"
        fi
      fi
    done
  fi

  local next_num=$((max_num + 1))
  printf "MEM%03d\n" "$next_num"
}

# Write the complete index from scratch (used by rebuild-index.sh)
# Usage: write_full_index <entries_string>
# entries_string: newline-separated entry lines
write_full_index() {
  local entries="$1"
  local index_path
  index_path="$(get_index_path)"

  local tmp_file="${index_path}.tmp.$$"

  cat > "$tmp_file" <<'HEADER'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
HEADER

  if [ -n "$entries" ]; then
    echo "$entries" >> "$tmp_file"
  fi

  mv "$tmp_file" "$index_path"
}
