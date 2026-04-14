#!/usr/bin/env bash
# scripts/knowledge/archive-entry.sh — Move an entry from warm to cold storage
# Usage: archive-entry.sh --id ID
#
# Moves knowledge/{category}/{id}.md to knowledge/archive/{id}.md and removes
# the entry from KNOWLEDGE-INDEX.md. Idempotent: prints ALREADY_ARCHIVED if
# the entry is already in archive/.
#
# Bash 3.2 compatible.

set -euo pipefail

# Resolve script directory and source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/detail-utils.sh
source "$SCRIPT_DIR/lib/detail-utils.sh"

# --- Find warm file (excludes archive/) ---
find_warm_file() {
  local entry_id="$1"
  local root
  root="$(get_project_root)"
  for file in "$root"/knowledge/*/"${entry_id}.md"; do
    if [ -f "$file" ]; then
      case "$file" in */archive/*) continue ;; esac
      echo "$file"
      return 0
    fi
  done
  return 1
}

# --- Check if entry is already archived ---
is_archived() {
  local entry_id="$1"
  local root
  root="$(get_project_root)"
  [ -f "$root/knowledge/archive/${entry_id}.md" ]
}

# --- Argument parsing ---
entry_id=""

while [ $# -gt 0 ]; do
  case "$1" in
    --id)
      entry_id="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# --- Validate ---
if [ -z "$entry_id" ]; then
  echo "ERROR: --id is required" >&2
  exit 1
fi

# --- Idempotency: already archived? ---
if is_archived "$entry_id"; then
  echo "ALREADY_ARCHIVED: $entry_id is already in knowledge/archive/"
  exit 0
fi

# --- Find warm file ---
warm_file=""
warm_file="$(find_warm_file "$entry_id")" || {
  echo "ERROR: Entry $entry_id not found in warm or cold storage" >&2
  exit 1
}

# --- Derive category dir for cleanup ---
category_dir="$(dirname "$warm_file")"

# --- Ensure archive directory exists ---
root="$(get_project_root)"
mkdir -p "$root/knowledge/archive"

# --- Move file to archive ---
mv "$warm_file" "$root/knowledge/archive/${entry_id}.md"

# --- Remove from index ---
index_remove_entry "$entry_id"

# --- Clean up empty category dir ---
rmdir "$category_dir" 2>/dev/null || true

echo "ARCHIVED: $entry_id moved to knowledge/archive/${entry_id}.md"
