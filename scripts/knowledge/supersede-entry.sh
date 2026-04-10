#!/usr/bin/env bash
# scripts/knowledge/supersede-entry.sh — Mark an old entry as superseded by a new entry
# Usage: supersede-entry.sh --old-id ID --new-id ID
#
# Sets superseded_by on the old entry, supersedes on the new entry,
# and removes the old entry from KNOWLEDGE-INDEX.md.
# Idempotent: if already superseded by the same new-id, prints ALREADY_SUPERSEDED.
# Bash 3.2 compatible.

set -euo pipefail

# Resolve script directory and source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"

# --- Portable sed -i helper (BSD/GNU compatible) ---
sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# --- Find detail file by scanning knowledge/*/ID.md ---
find_detail_file() {
  local entry_id="$1"
  local root
  root="$(get_project_root)"
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

# --- Argument parsing ---
old_id=""
new_id=""

while [ $# -gt 0 ]; do
  case "$1" in
    --old-id)
      old_id="$2"
      shift 2
      ;;
    --new-id)
      new_id="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# --- Validate ---
if [ -z "$old_id" ]; then
  echo "ERROR: --old-id is required" >&2
  exit 1
fi

if [ -z "$new_id" ]; then
  echo "ERROR: --new-id is required" >&2
  exit 1
fi

# --- Find both detail files ---
old_file=""
old_file="$(find_detail_file "$old_id")" || {
  echo "ERROR: Old entry $old_id not found" >&2
  exit 1
}

new_file=""
new_file="$(find_detail_file "$new_id")" || {
  echo "ERROR: New entry $new_id not found" >&2
  exit 1
}

# --- Idempotency check ---
current_superseded_by="$(fm_field "$old_file" "superseded_by")"
if [ "$current_superseded_by" = "$new_id" ]; then
  echo "ALREADY_SUPERSEDED"
  exit 0
fi

# --- Set superseded_by on the old entry ---
sed_i "s/^superseded_by: .*/superseded_by: \"${new_id}\"/" "$old_file"

# --- Set supersedes on the new entry ---
sed_i "s/^supersedes: .*/supersedes: \"${old_id}\"/" "$new_file"

# --- Remove old entry from the index ---
index_remove_entry "$old_id"

echo "SUPERSEDED: $old_id by $new_id"
