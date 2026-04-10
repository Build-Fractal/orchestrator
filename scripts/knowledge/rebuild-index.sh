#!/usr/bin/env bash
# scripts/knowledge/rebuild-index.sh — Regenerate KNOWLEDGE-INDEX.md from detail files
# Usage: rebuild-index.sh [--root <project-root>]
#
# Scans all detail files in knowledge/*/ (excluding knowledge/archive/) and
# regenerates KNOWLEDGE-INDEX.md atomically via write_full_index().
#
# Bash 3.2 compatible.

set -euo pipefail

# Resolve script directory and source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"

# --- Argument parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      export PROJECT_ROOT="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# --- Helper: extract a YAML frontmatter field value ---
# Usage: fm_field <file> <field_name>
# Extracts the value after "field_name: " from YAML frontmatter (between --- delimiters).
fm_field() {
  local file="$1"
  local field="$2"
  # Extract frontmatter (lines between first and second ---), then grab the field
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"//;s/"$//' | sed "s/^'//;s/'$//"
}

# --- Resolve project root ---
root="$(get_project_root)"
knowledge_dir="$root/knowledge"

if [ ! -d "$knowledge_dir" ]; then
  echo "ERROR: knowledge/ directory not found at $root" >&2
  exit 1
fi

# --- Scan detail files and build entries ---
entries=""
entry_count=0

for file in "$knowledge_dir"/*/*.md; do
  # Skip if glob didn't match anything
  if [ ! -f "$file" ]; then
    continue
  fi

  # Skip archive directory
  case "$file" in
    */archive/*)
      continue
      ;;
  esac

  # Skip .gitkeep or non-MEM files
  basename_file="$(basename "$file" .md)"
  case "$basename_file" in
    MEM*)
      ;;
    *)
      continue
      ;;
  esac

  # Extract frontmatter fields
  id="$(fm_field "$file" "id")"
  scope_tags="$(fm_field "$file" "scope_tags")"
  category="$(fm_field "$file" "category")"
  confidence="$(fm_field "$file" "confidence")"
  created_at="$(fm_field "$file" "created_at")"
  last_verified="$(fm_field "$file" "last_verified")"
  hit_count="$(fm_field "$file" "hit_count")"
  superseded_by="$(fm_field "$file" "superseded_by")"

  # Skip superseded entries (non-empty superseded_by)
  if [ -n "$superseded_by" ]; then
    continue
  fi

  # Extract description from heading: # MEM###: <description>
  description="$(grep "^# ${id}:" "$file" | head -1 | sed "s/^# ${id}:[[:space:]]*//")"

  # Use ID as fallback if no description found
  if [ -z "$description" ]; then
    description="$id"
  fi

  # Format the entry line
  entry_line="$(format_index_entry "$id" "$scope_tags" "$category" "$confidence" "$created_at" "$last_verified" "$hit_count" "$description")"

  if [ -z "$entries" ]; then
    entries="$entry_line"
  else
    entries="$entries
$entry_line"
  fi

  entry_count=$((entry_count + 1))
done

# --- Sort entries by ID ---
if [ -n "$entries" ]; then
  entries="$(echo "$entries" | sort)"
fi

# --- Write the full index ---
write_full_index "$entries"

echo "REBUILT: KNOWLEDGE-INDEX.md with $entry_count entries"
