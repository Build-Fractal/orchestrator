#!/usr/bin/env bash
# scripts/knowledge/promote-entry.sh — Move an entry from cold storage back to warm
# Usage: promote-entry.sh --id ID [--confidence CONF] [--category CAT]
#
# Moves knowledge/archive/{id}.md to knowledge/{category}/{id}.md, resets
# confidence and last_verified, clears superseded_by, and re-adds to
# KNOWLEDGE-INDEX.md. Idempotent: prints NOT_ARCHIVED if entry is not in archive.
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

# --- Check if entry is archived ---
is_archived() {
  local entry_id="$1"
  local root
  root="$(get_project_root)"
  [ -f "$root/knowledge/archive/${entry_id}.md" ]
}

# --- Argument parsing ---
entry_id=""
confidence="0.80"
category_override=""

while [ $# -gt 0 ]; do
  case "$1" in
    --id)
      entry_id="$2"
      shift 2
      ;;
    --confidence)
      confidence="$2"
      shift 2
      ;;
    --category)
      category_override="$2"
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

# --- Check if already in warm storage (not archived) ---
if find_warm_file "$entry_id" >/dev/null 2>&1; then
  echo "NOT_ARCHIVED: $entry_id is not in archive, nothing to promote"
  exit 0
fi

# --- Verify entry exists in archive ---
if ! is_archived "$entry_id"; then
  echo "ERROR: Entry $entry_id not found in warm or cold storage" >&2
  exit 1
fi

# --- Resolve paths ---
root="$(get_project_root)"
archive_file="$root/knowledge/archive/${entry_id}.md"

# --- Determine category ---
if [ -n "$category_override" ]; then
  category="$category_override"
else
  category="$(fm_field "$archive_file" "category")"
  if [ -z "$category" ]; then
    echo "ERROR: No category found in frontmatter and --category not provided" >&2
    exit 1
  fi
fi

# --- Create category directory ---
mkdir -p "$root/knowledge/$category"

# --- Move file to warm storage ---
detail_file="$root/knowledge/$category/${entry_id}.md"
mv "$archive_file" "$detail_file"

# --- Update frontmatter ---
today="$(date +%Y-%m-%d)"
sed_i "s/^confidence: .*/confidence: ${confidence}/" "$detail_file"
sed_i "s/^last_verified: .*/last_verified: ${today}/" "$detail_file"
sed_i "s/^superseded_by: .*/superseded_by: \"\"/" "$detail_file"
# Update category in frontmatter if overridden
if [ -n "$category_override" ]; then
  sed_i "s/^category: .*/category: ${category}/" "$detail_file"
fi

# --- Re-read frontmatter and add to index ---
id_val="$(fm_field "$detail_file" "id")"
scope_tags="$(fm_field "$detail_file" "scope_tags")"
cat_val="$(fm_field "$detail_file" "category")"
conf_val="$(fm_field "$detail_file" "confidence")"
created_at="$(fm_field "$detail_file" "created_at")"
last_verified="$(fm_field "$detail_file" "last_verified")"
hit_count="$(fm_field "$detail_file" "hit_count")"

# Extract description from the first H1 line (# MEM###: description)
description="$(grep "^# ${entry_id}:" "$detail_file" | head -1 | sed "s/^# ${entry_id}:[[:space:]]*//")"

index_line="$(format_index_entry "$id_val" "$scope_tags" "$cat_val" "$conf_val" "$created_at" "$last_verified" "$hit_count" "$description")"
index_add_entry "$index_line"

echo "PROMOTED: $entry_id moved to knowledge/$category/${entry_id}.md with confidence $confidence"
