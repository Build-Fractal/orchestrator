#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# knowledge.sh — Transform extracted knowledge TSV into detail files
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+
#
# Usage: knowledge.sh <intermediate_dir> <target_project_root>
#   intermediate_dir:    directory containing knowledge.dat (GSD2 adapter output)
#   target_project_root: where to write knowledge/ detail files
#
# For each ACTIVE entry:     creates knowledge/{category}/{id}.md
# For each SUPERSEDED entry: creates knowledge/archive/{category}/{id}.md
#
# Idempotent: existing detail files are skipped with a message.
# =============================================================================

# --- Resolve script directory and source dependencies ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
INTERFACE="${SCRIPT_DIR}/../adapter-interface.sh"

# Source adapter interface (provides unescape_field, KNOWLEDGE_FIELDS)
# shellcheck source=../adapter-interface.sh
source "$INTERFACE"

# Source library scripts
# shellcheck source=../lib/category-mapper.sh
source "${LIB_DIR}/category-mapper.sh"
# shellcheck source=../lib/scope-tag.sh
source "${LIB_DIR}/scope-tag.sh"
# shellcheck source=../lib/supersession-chain.sh
source "${LIB_DIR}/supersession-chain.sh"

# --- Parse arguments ---
intermediate_dir="${1:?Usage: knowledge.sh <intermediate_dir> <target_project_root>}"
target_root="${2:?Usage: knowledge.sh <intermediate_dir> <target_project_root>}"

knowledge_dat="${intermediate_dir}/knowledge.dat"
if [ ! -f "$knowledge_dat" ]; then
    echo "ERROR: knowledge.dat not found at $knowledge_dat" >&2
    exit 1
fi

# --- Migration date (today) ---
migration_date="$(date '+%Y-%m-%d')"

# --- Resolve supersession chains ---
resolve_supersession_chains "$knowledge_dat" "$intermediate_dir"

# --- Helper: write a knowledge detail file ---
# Usage: write_detail_file <output_path> <id> <scope_tag> <category> <confidence>
#        <created_at> <hit_count> <source_unit> <superseded_by> <content> <title>
write_detail_file() {
    local output_path="$1"
    local id="$2"
    local scope_tag="$3"
    local category="$4"
    local confidence="$5"
    local created_at="$6"
    local hit_count="$7"
    local source_unit="$8"
    local superseded_by="$9"
    shift 9
    local content="$1"
    local title="$2"

    # Create parent directory
    mkdir -p "$(dirname "$output_path")"

    # Write YAML frontmatter + content
    cat > "$output_path" <<FRONTMATTER
---
id: ${id}
scope_tags: "${scope_tag}"
category: ${category}
confidence: ${confidence}
created_at: ${created_at}
last_verified: ${migration_date}
hit_count: ${hit_count}
source_unit: "${source_unit}"
source_type: execution
migrated_from: gsd2
supersedes: ""
superseded_by: "${superseded_by}"
relates_to: []
content_hash: ""
---

# ${id}: ${title}

${content}
FRONTMATTER
}

# --- Process entries from a .dat file ---
# Usage: process_entries <dat_file> <base_dir> <entry_type>
#   entry_type: "active" or "superseded" (for logging)
process_entries() {
    local dat_file="$1"
    local base_dir="$2"
    local entry_type="$3"
    local count=0

    # Count data rows (skip header)
    local total_rows
    total_rows="$(tail -n +2 "$dat_file" | grep -c '.' || true)"

    if [ "$total_rows" -eq 0 ]; then
        echo "$count"
        return
    fi

    tail -n +2 "$dat_file" | while IFS= read -r line; do
        [ -z "$line" ] && continue

        # Parse TSV fields using awk
        local f_id f_category f_title f_content f_source_file f_priority
        local f_hit_count f_created_at f_updated_at f_superseded_by

        f_id="$(echo "$line" | awk -F'\t' '{print $1}')"
        f_category="$(echo "$line" | awk -F'\t' '{print $2}')"
        f_title="$(echo "$line" | awk -F'\t' '{print $3}')"
        f_content="$(echo "$line" | awk -F'\t' '{print $4}')"
        f_source_file="$(echo "$line" | awk -F'\t' '{print $5}')"
        f_priority="$(echo "$line" | awk -F'\t' '{print $6}')"
        f_hit_count="$(echo "$line" | awk -F'\t' '{print $7}')"
        f_created_at="$(echo "$line" | awk -F'\t' '{print $8}')"
        f_updated_at="$(echo "$line" | awk -F'\t' '{print $9}')"
        f_superseded_by="$(echo "$line" | awk -F'\t' '{print $10}')"

        # Skip entries with empty id or empty content
        if [ -z "$f_id" ]; then
            echo "WARNING: Skipping entry with empty id" >&2
            continue
        fi
        if [ -z "$f_content" ]; then
            echo "WARNING: Skipping entry $f_id with empty content" >&2
            continue
        fi

        # Unescape fields
        f_title="$(unescape_field "$f_title")"
        f_content="$(unescape_field "$f_content")"
        f_source_file="$(unescape_field "$f_source_file")"

        # Map category
        local mapped_category
        mapped_category="$(map_category "$f_category")"

        # Derive scope tag
        local scope_tag
        scope_tag="$(derive_scope_tag "$f_source_file")"

        # Default confidence
        if [ -z "$f_priority" ]; then
            f_priority="0.8"
        fi

        # Default hit_count
        if [ -z "$f_hit_count" ]; then
            f_hit_count="0"
        fi

        # Default created_at to migration date if missing
        if [ -z "$f_created_at" ]; then
            f_created_at="$migration_date"
        fi

        # Build output path
        local output_path="${base_dir}/${mapped_category}/${f_id}.md"

        # Idempotent: skip if file exists
        if [ -f "$output_path" ]; then
            echo "SKIP: $output_path already exists" >&2
            continue
        fi

        # Write the detail file
        write_detail_file "$output_path" \
            "$f_id" "$scope_tag" "$mapped_category" "$f_priority" \
            "$f_created_at" "$f_hit_count" "$f_source_file" \
            "$f_superseded_by" "$f_content" "$f_title"

        count=$((count + 1))
        echo "$count"
    done | tail -1
}

# --- Main execution ---
knowledge_dir="${target_root}/knowledge"
archive_dir="${target_root}/knowledge/archive"

# Ensure base directories exist
mkdir -p "$knowledge_dir"
mkdir -p "$archive_dir"

# Process active entries
active_count="$(process_entries "${intermediate_dir}/active_entries.dat" "$knowledge_dir" "active")"
if [ -z "$active_count" ]; then
    active_count=0
fi

# Process superseded entries
superseded_count="$(process_entries "${intermediate_dir}/superseded_entries.dat" "$archive_dir" "superseded")"
if [ -z "$superseded_count" ]; then
    superseded_count=0
fi

echo "TRANSFORMED: ${active_count} active, ${superseded_count} superseded knowledge entries"
