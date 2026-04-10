#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# requirements.sh — Transform extracted requirements TSV into REQUIREMENTS.md
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+
#
# Usage: requirements.sh <intermediate_dir> <target_project_root>
#   intermediate_dir:    directory containing requirements.dat (adapter output)
#   target_project_root: where to write REQUIREMENTS.md and REQUIREMENTS-ARCHIVE.md
#
# Splits requirements into two files:
#   REQUIREMENTS.md         — active requirements (active, pending, blocked, deferred)
#   REQUIREMENTS-ARCHIVE.md — satisfied/completed/superseded requirements
#
# Idempotent: re-running overwrites the output files.
# =============================================================================

# --- Resolve script directory and source dependencies ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTERFACE="${SCRIPT_DIR}/../adapter-interface.sh"

# Source adapter interface (provides unescape_field, REQUIREMENTS_FIELDS)
# shellcheck source=../adapter-interface.sh
source "$INTERFACE"

# --- Parse arguments ---
intermediate_dir="${1:?Usage: requirements.sh <intermediate_dir> <target_project_root>}"
target_root="${2:?Usage: requirements.sh <intermediate_dir> <target_project_root>}"

requirements_dat="${intermediate_dir}/requirements.dat"
if [ ! -f "$requirements_dat" ]; then
    echo "ERROR: requirements.dat not found at $requirements_dat" >&2
    exit 1
fi

# --- Migration date (today) ---
migration_date="$(date '+%Y-%m-%d')"

# --- Truncate helper ---
truncate_field() {
    local val="$1"
    local max_len="$2"
    if [ "${#val}" -gt "$max_len" ]; then
        printf '%s...' "$(printf '%.'"$((max_len - 3))"'s' "$val")"
    else
        printf '%s' "$val"
    fi
}

# --- Escape pipes in markdown table cells ---
escape_pipes() {
    printf '%s' "$1" | sed 's/|/\&#124;/g'
}

# --- Classify status as active or archived ---
# Returns "active" for active/pending/blocked/deferred, "archive" for everything else
classify_status() {
    local status="$1"
    # Normalize to lowercase for comparison (Bash 3.2 compatible)
    local lower
    lower="$(printf '%s' "$status" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        active|pending|blocked|deferred|"")
            echo "active"
            ;;
        *)
            echo "archive"
            ;;
    esac
}

# --- Count data rows ---
total_rows="$(tail -n +2 "$requirements_dat" | grep -c '.' || true)"
if [ "$total_rows" -eq 0 ]; then
    echo "No requirements to transform (0 data rows in requirements.dat)"
    mkdir -p "$target_root"
    cat > "${target_root}/REQUIREMENTS.md" <<EOF
# Requirements

> Migrated from gsd2 on ${migration_date}. No active requirements found.

| ID | Class | Status | Description | Validation | Validated By |
|----|-------|--------|-------------|------------|--------------|
EOF
    exit 0
fi

# --- Build output in temp files ---
mkdir -p "$target_root"
tmp_active="$(mktemp "${target_root}/REQUIREMENTS.md.XXXXXX")"
tmp_archive="$(mktemp "${target_root}/REQUIREMENTS-ARCHIVE.md.XXXXXX")"

# Write active requirements header
cat > "$tmp_active" <<EOF
# Requirements

> Migrated from gsd2 on ${migration_date}. ${total_rows} total requirements imported.

| ID | Class | Status | Description | Validation | Validated By |
|----|-------|--------|-------------|------------|--------------|
EOF

# Write archive header
cat > "$tmp_archive" <<EOF
# Requirements Archive

> Migrated from gsd2 on ${migration_date}. Satisfied, completed, and superseded requirements.

| ID | Class | Status | Description | Satisfied By |
|----|-------|--------|-------------|-------------|
EOF

# --- Process each requirement row ---
# Fields (10 total):
#   1=id, 2=type(class), 3=priority(status), 4=title, 5=description,
#   6=acceptance_criteria(validation), 7=source,
#   8=validation_status, 9=validated_by, 10=superseded_by
active_count=0
archive_count=0

tail -n +2 "$requirements_dat" | while IFS= read -r line; do
    [ -z "$line" ] && continue

    # Parse TSV fields using awk
    f_id="$(printf '%s' "$line" | awk -F'\t' '{print $1}')"
    f_class="$(printf '%s' "$line" | awk -F'\t' '{print $2}')"
    f_status="$(printf '%s' "$line" | awk -F'\t' '{print $3}')"
    # f_title is $4 — we use description for the table
    f_desc="$(printf '%s' "$line" | awk -F'\t' '{print $5}')"
    f_validation="$(printf '%s' "$line" | awk -F'\t' '{print $6}')"
    # f_source is $7
    f_validation_status="$(printf '%s' "$line" | awk -F'\t' '{print $8}')"
    f_validated_by="$(printf '%s' "$line" | awk -F'\t' '{print $9}')"
    f_superseded_by="$(printf '%s' "$line" | awk -F'\t' '{print $10}')"

    # Skip entries with empty id
    if [ -z "$f_id" ]; then
        continue
    fi

    # Unescape fields
    f_desc="$(unescape_field "$f_desc")"
    f_class="$(unescape_field "$f_class")"
    f_status="$(unescape_field "$f_status")"
    f_validation="$(unescape_field "$f_validation")"
    f_validation_status="$(unescape_field "$f_validation_status")"
    f_validated_by="$(unescape_field "$f_validated_by")"
    f_superseded_by="$(unescape_field "$f_superseded_by")"

    # Use validation_status if available, otherwise fall back to validation field
    display_validation="$f_validation_status"
    if [ -z "$display_validation" ]; then
        display_validation="$f_validation"
    fi

    # Truncate long fields
    f_desc="$(truncate_field "$f_desc" 70)"
    display_validation="$(truncate_field "$display_validation" 40)"
    f_validated_by="$(truncate_field "$f_validated_by" 40)"

    # Escape pipes
    f_id="$(escape_pipes "$f_id")"
    f_class="$(escape_pipes "$f_class")"
    f_status="$(escape_pipes "$f_status")"
    f_desc="$(escape_pipes "$f_desc")"
    display_validation="$(escape_pipes "$display_validation")"
    f_validated_by="$(escape_pipes "$f_validated_by")"

    # Classify and write to appropriate file
    classification="$(classify_status "$f_status")"

    # Force superseded entries to archive
    if [ -n "$f_superseded_by" ]; then
        classification="archive"
    fi

    if [ "$classification" = "active" ]; then
        printf '| %s | %s | %s | %s | %s | %s |\n' \
            "$f_id" "$f_class" "$f_status" "$f_desc" "$display_validation" "$f_validated_by" >> "$tmp_active"
        active_count=$((active_count + 1))
    else
        # For archive, validated_by serves as "Satisfied By"
        satisfied_by="$f_validated_by"
        if [ -n "$f_superseded_by" ]; then
            satisfied_by="Superseded by ${f_superseded_by}"
        fi
        satisfied_by="$(escape_pipes "$satisfied_by")"
        printf '| %s | %s | %s | %s | %s |\n' \
            "$f_id" "$f_class" "$f_status" "$f_desc" "$satisfied_by" >> "$tmp_archive"
        archive_count=$((archive_count + 1))
    fi
done

# Atomic move
mv "$tmp_active" "${target_root}/REQUIREMENTS.md"
mv "$tmp_archive" "${target_root}/REQUIREMENTS-ARCHIVE.md"

# Count actual output rows (subtracting header lines)
active_count="$(tail -n +7 "${target_root}/REQUIREMENTS.md" | grep -c '^|' || true)"
archive_count="$(tail -n +7 "${target_root}/REQUIREMENTS-ARCHIVE.md" | grep -c '^|' || true)"

echo "TRANSFORMED: ${total_rows} requirements -> ${active_count} active (REQUIREMENTS.md), ${archive_count} archived (REQUIREMENTS-ARCHIVE.md)"
