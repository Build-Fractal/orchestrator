#!/usr/bin/env bash
# scripts/knowledge/update-entry.sh — Modify metadata on an existing knowledge entry
# Usage: update-entry.sh --id ID [--confidence CONF] [--last-verified DATE|now] [--hit-count N] [--increment-hits]
#
# Modifies the detail file's YAML frontmatter and atomically updates KNOWLEDGE-INDEX.md.
# Bash 3.2 compatible.

set -euo pipefail

# Resolve script directory and source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/detail-utils.sh
source "$SCRIPT_DIR/lib/detail-utils.sh"

# --- Argument parsing ---
entry_id=""
new_confidence=""
new_last_verified=""
new_hit_count=""
increment_hits=false

while [ $# -gt 0 ]; do
  case "$1" in
    --id)
      entry_id="$2"
      shift 2
      ;;
    --confidence)
      new_confidence="$2"
      shift 2
      ;;
    --last-verified)
      new_last_verified="$2"
      shift 2
      ;;
    --hit-count)
      new_hit_count="$2"
      shift 2
      ;;
    --increment-hits)
      increment_hits=true
      shift
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

if [ -z "$new_confidence" ] && [ -z "$new_last_verified" ] && [ -z "$new_hit_count" ] && [ "$increment_hits" = false ]; then
  echo "ERROR: No fields specified to update" >&2
  exit 1
fi

# --- Find the detail file ---
detail_file=""
detail_file="$(find_detail_file "$entry_id")" || {
  echo "ERROR: Entry $entry_id not found" >&2
  exit 1
}

# --- Track changed fields ---
changed_fields=""

# --- Update confidence ---
if [ -n "$new_confidence" ]; then
  sed_i "s/^confidence: .*/confidence: ${new_confidence}/" "$detail_file"
  changed_fields="${changed_fields}confidence, "
fi

# --- Update last_verified ---
if [ -n "$new_last_verified" ]; then
  if [ "$new_last_verified" = "now" ]; then
    new_last_verified="$(date +%Y-%m-%d)"
  fi
  sed_i "s/^last_verified: .*/last_verified: ${new_last_verified}/" "$detail_file"
  changed_fields="${changed_fields}last_verified, "
fi

# --- Update hit_count ---
if [ -n "$new_hit_count" ]; then
  sed_i "s/^hit_count: .*/hit_count: ${new_hit_count}/" "$detail_file"
  changed_fields="${changed_fields}hit_count, "
fi

# --- Increment hits ---
if [ "$increment_hits" = true ]; then
  current_hits="$(fm_field "$detail_file" "hit_count")"
  current_hits="${current_hits:-0}"
  new_hits=$((current_hits + 1))
  sed_i "s/^hit_count: .*/hit_count: ${new_hits}/" "$detail_file"
  changed_fields="${changed_fields}hit_count, "
fi

# Remove trailing ", "
changed_fields="$(echo "$changed_fields" | sed 's/, $//')"

# --- Re-read all fields from updated file and update the index ---
id_val="$(fm_field "$detail_file" "id")"
scope_tags="$(fm_field "$detail_file" "scope_tags")"
category="$(fm_field "$detail_file" "category")"
confidence="$(fm_field "$detail_file" "confidence")"
created_at="$(fm_field "$detail_file" "created_at")"
last_verified="$(fm_field "$detail_file" "last_verified")"
hit_count="$(fm_field "$detail_file" "hit_count")"

# Extract description from the first H1 line (# MEM###: description)
description="$(grep "^# ${entry_id}:" "$detail_file" | head -1 | sed "s/^# ${entry_id}:[[:space:]]*//")"

index_line="$(format_index_entry "$id_val" "$scope_tags" "$category" "$confidence" "$created_at" "$last_verified" "$hit_count" "$description")"
index_update_entry "$entry_id" "$index_line"

echo "UPDATED: $entry_id ($changed_fields)"
