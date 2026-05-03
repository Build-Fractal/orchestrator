#!/usr/bin/env bash
# scripts/knowledge/rebuild-index.sh — Regenerate KNOWLEDGE-INDEX.md from detail files
# Usage: rebuild-index.sh [--root <project-root>]
#
# Scans all detail files in knowledge/*/ and knowledge/*/*/ (including nested
# spec/ subdirectories, excluding knowledge/archive/) and regenerates
# KNOWLEDGE-INDEX.md atomically via write_full_index().
#
# Bash 3.2 compatible.

set -euo pipefail

# Resolve script directory and source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/graph-db.sh
source "$SCRIPT_DIR/lib/graph-db.sh"

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
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//' | sed 's/[[:space:]]*$//' || true
}

# --- Resolve project root ---
root="$(get_project_root)"
knowledge_dir="$root/knowledge"

if [ ! -d "$knowledge_dir" ]; then
  echo "ERROR: knowledge/ directory not found at $root" >&2
  exit 1
fi

# --- Initialize SQLite graph database ---
db_path="$(get_db_path)"
tmp_db="${db_path}.tmp.$$"
trap 'rm -f "$tmp_db"' EXIT
rm -f "$tmp_db"
db_init "$tmp_db"
db_entry_count=0
db_edge_count=0
db_tag_count=0

# --- Scan detail files and build entries ---
entries=""
entry_count=0

for file in "$knowledge_dir"/*/*.md "$knowledge_dir"/*/*/*.md; do
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
    *.text|*.structured)
      continue
      ;;
    MEM*|SPEC-*|REF-*)
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
  source_unit="$(fm_field "$file" "source_unit")"
  source_type="$(fm_field "$file" "source_type")"
  supersedes="$(fm_field "$file" "supersedes")"
  content_hash="$(fm_field "$file" "content_hash")"
  relates_to_raw="$(fm_field "$file" "relates_to")"
  cites_raw="$(fm_field "$file" "cites")"
  derived_from_raw="$(fm_field "$file" "derived_from")"
  applies_to_field_raw="$(fm_field "$file" "applies_to_field")"

  # Extract description from heading: # MEM###: <description>
  description="$(grep "^# ${id}:" "$file" | head -1 | sed "s/^# ${id}:[[:space:]]*//")"

  # Use ID as fallback if no description found
  if [ -z "$description" ]; then
    description="$id"
  fi

  # --- Populate SQLite database (all entries, including superseded) ---
  rel_path="${file#$root/}"
  db_insert_entry "$tmp_db" "$id" "$category" "$confidence" "$created_at" \
    "$last_verified" "$hit_count" "$source_unit" "$source_type" \
    "$supersedes" "$superseded_by" "$content_hash" "$description" "$rel_path"
  db_entry_count=$((db_entry_count + 1))

  # --- Insert edges for relates_to ---
  if [ -n "$relates_to_raw" ] && [ "$relates_to_raw" != "[]" ]; then
    relates_clean="$(printf '%s' "$relates_to_raw" | tr -d '[]' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    if [ -n "$relates_clean" ]; then
      old_ifs="$IFS"
      IFS=','
      for rel_target in $relates_clean; do
        rel_target="$(printf '%s' "$rel_target" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
        if [ -n "$rel_target" ]; then
          db_insert_edge "$tmp_db" "$id" "$rel_target" "relates_to"
          db_edge_count=$((db_edge_count + 1))
        fi
      done
      IFS="$old_ifs"
    fi
  fi

  # --- Insert edge for supersedes ---
  if [ -n "$supersedes" ]; then
    db_insert_edge "$tmp_db" "$id" "$supersedes" "supersedes"
    db_edge_count=$((db_edge_count + 1))
  fi

  # --- Insert edges for cites (M036/P05) ---
  if [ -n "$cites_raw" ] && [ "$cites_raw" != "[]" ]; then
    cites_clean="$(printf '%s' "$cites_raw" | tr -d '[]' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    if [ -n "$cites_clean" ]; then
      old_ifs="$IFS"
      IFS=','
      for cite_target in $cites_clean; do
        cite_target="$(printf '%s' "$cite_target" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
        if [ -n "$cite_target" ]; then
          db_insert_edge "$tmp_db" "$id" "$cite_target" "cites"
          db_edge_count=$((db_edge_count + 1))
        fi
      done
      IFS="$old_ifs"
    fi
  fi

  # --- Insert edges for derived_from (M036/P05) ---
  if [ -n "$derived_from_raw" ] && [ "$derived_from_raw" != "[]" ]; then
    derived_clean="$(printf '%s' "$derived_from_raw" | tr -d '[]' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    if [ -n "$derived_clean" ]; then
      old_ifs="$IFS"
      IFS=','
      for derived_target in $derived_clean; do
        derived_target="$(printf '%s' "$derived_target" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
        if [ -n "$derived_target" ]; then
          db_insert_edge "$tmp_db" "$id" "$derived_target" "derived_from"
          db_edge_count=$((db_edge_count + 1))
        fi
      done
      IFS="$old_ifs"
    fi
  fi

  # --- Insert edges for applies_to_field (M036/P05) ---
  # target_id is a field name string (opaque to the edge layer).
  if [ -n "$applies_to_field_raw" ] && [ "$applies_to_field_raw" != "[]" ]; then
    field_clean="$(printf '%s' "$applies_to_field_raw" | tr -d '[]' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    if [ -n "$field_clean" ]; then
      old_ifs="$IFS"
      IFS=','
      for field_target in $field_clean; do
        field_target="$(printf '%s' "$field_target" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
        if [ -n "$field_target" ]; then
          db_insert_edge "$tmp_db" "$id" "$field_target" "applies_to_field"
          db_edge_count=$((db_edge_count + 1))
        fi
      done
      IFS="$old_ifs"
    fi
  fi

  # --- Insert scope_tags ---
  if [ -n "$scope_tags" ]; then
    tags_clean="$(printf '%s' "$scope_tags" | sed 's/^"//;s/"$//')"
    tag_list="$(printf '%s' "$tags_clean" | sed 's/\],* *\[/]\
[/g')"
    while IFS= read -r single_tag; do
      single_tag="$(printf '%s' "$single_tag" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
      if [ -n "$single_tag" ]; then
        db_insert_scope_tag "$tmp_db" "$id" "$single_tag"
        db_tag_count=$((db_tag_count + 1))
      fi
    done <<EOF_TAGS
$tag_list
EOF_TAGS
  fi

  # Skip superseded entries for flat index only (non-empty superseded_by)
  if [ -n "$superseded_by" ]; then
    continue
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

# --- Additive emit: append flat `## Spec Chunks` section (FR-9, D014).
# Runs after write_full_index so the existing pipe-table body remains
# byte-identical for downstream consumers. No-op when knowledge/spec/ is absent.
emit_spec_chunks_section "$knowledge_dir" "$(get_index_path)"

# --- Finalize SQLite database (atomic move) ---
mv "$tmp_db" "$db_path"

echo "REBUILT: KNOWLEDGE-INDEX.md with $entry_count entries"
echo "REBUILT: knowledge.db with $db_entry_count entries, $db_edge_count edges, $db_tag_count scope_tags"
