#!/usr/bin/env bash
# scripts/knowledge/supersede-entry.sh — Mark an old entry as superseded by a new entry
# Usage: supersede-entry.sh --old-id ID --new-id ID
#
# Sets superseded_by on the old entry, supersedes on the new entry,
# and removes the old entry from KNOWLEDGE-INDEX.md.
# Idempotent: if already superseded by the same new-id, prints ALREADY_SUPERSEDED.
# The old detail file stays in place (not moved to archive) for audit trail.
# Bash 3.2 compatible.

set -euo pipefail

# Resolve script directory and source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/detail-utils.sh
source "$SCRIPT_DIR/lib/detail-utils.sh"

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
  echo "ALREADY_SUPERSEDED: $old_id by $new_id"
  exit 0
fi

# --- Set superseded_by on the old entry ---
sed_i "s/^superseded_by: .*/superseded_by: \"${new_id}\"/" "$old_file"

# --- Set supersedes on the new entry (if not already set) ---
current_supersedes="$(fm_field "$new_file" "supersedes")"
if [ "$current_supersedes" != "$old_id" ]; then
  sed_i "s/^supersedes: .*/supersedes: \"${old_id}\"/" "$new_file"
fi

# --- Remove old entry from the index ---
index_remove_entry "$old_id"

echo "SUPERSEDED: $old_id by $new_id"
