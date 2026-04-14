#!/usr/bin/env bash
# scripts/knowledge/lib/detail-utils.sh — Shared helpers for knowledge detail files
# Source this file to use find_detail_file, sed_i, and fm_field.
# Requires index-utils.sh to be sourced first (for get_project_root).
#
# Bash 3.2 compatible.

# --- Double-sourcing guard ---
[ -n "${_DETAIL_UTILS_SOURCED:-}" ] && return 0
_DETAIL_UTILS_SOURCED=1

# --- Portable sed -i helper (BSD/GNU compatible) ---
sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# --- Find detail file by scanning knowledge/*/ID.md (category-agnostic) ---
find_detail_file() {
  local entry_id="$1"
  local root
  root="$(get_project_root)"
  local file
  for file in "$root"/knowledge/*/"${entry_id}.md"; do
    if [ -f "$file" ]; then
      echo "$file"
      return 0
    fi
  done
  if [ -f "$root/knowledge/archive/${entry_id}.md" ]; then
    echo "$root/knowledge/archive/${entry_id}.md"
    return 0
  fi
  return 1
}

# --- Read a field from YAML frontmatter ---
fm_field() {
  local file="$1"
  local field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//' | sed 's/[[:space:]]*$//'
}
