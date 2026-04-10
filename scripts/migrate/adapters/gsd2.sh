#!/usr/bin/env bash
# scripts/migrate/adapters/gsd2.sh — GSD2 source adapter
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no pipe-ampersand)
#
# Implements the full adapter interface contract for GSD2 sources.
# Data source priority (AD-2):
#   1. SQLite gsd.db (preferred)
#   2. JSON fallback: memories-snapshot.json + state-manifest.json
#   3. Filesystem scan: milestone directories
#
# Prerequisites:
#   source adapter-interface.sh   (must be sourced before this file)
#   source lib/sqlite-reader.sh   (sourced below)
#   source lib/json-fallback.sh   (sourced below)
# =============================================================================
set -euo pipefail

# Resolve script directory and source dependencies
_GSD2_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_GSD2_SCRIPT_DIR}/../lib/sqlite-reader.sh"
source "${_GSD2_SCRIPT_DIR}/../lib/json-fallback.sh"

# Module-level state (set by _gsd2_resolve)
_gsd_dir=""
_gsd_db=""
_use_sqlite=false

# =============================================================================
# _gsd2_resolve <source_path> <output_dir>
#   Resolve GSD2 paths and determine which data source to use.
#   Sets module-level vars: _gsd_dir, _gsd_db, _use_sqlite
# =============================================================================
_gsd2_resolve() {
    local source_path="$1"
    local output_dir="$2"

    # Resolve the .gsd directory
    _gsd_dir="$(_resolve_gsd_dir "$source_path")" || true

    # Locate gsd.db — check both the resolved dir and common locations
    _gsd_db=""
    _use_sqlite=false

    if [ -f "${_gsd_dir}/gsd.db" ]; then
        _gsd_db="${_gsd_dir}/gsd.db"
    fi

    # If we found a database file, validate it
    if [ -n "$_gsd_db" ]; then
        if check_sqlite3 && is_valid_sqlite "$_gsd_db" 2>/dev/null; then
            _use_sqlite=true
        else
            # Database exists but is invalid — emit warning and fall back
            emit_warning "$output_dir" "INVALID_SQLITE" \
                "gsd.db exists but is not a valid SQLite database; falling back to JSON" \
                "$_gsd_db"
            _use_sqlite=false
        fi
    fi
}

# =============================================================================
# detect_source <path>
#   Echo "yes" if path contains a GSD2 project (gsd.db or
#   memories-snapshot.json), "no" otherwise.
# =============================================================================
detect_source() {
    local path="$1"
    local resolved
    resolved="$(_resolve_gsd_dir "$path")" || true

    # Check for gsd.db
    if [ -f "${resolved}/gsd.db" ]; then
        echo "yes"
        return 0
    fi

    # Check for JSON fallback files
    if [ -f "${resolved}/memories-snapshot.json" ]; then
        echo "yes"
        return 0
    fi

    # Check the path directly (in case it IS the .gsd dir)
    if [ -f "${path}/gsd.db" ]; then
        echo "yes"
        return 0
    fi
    if [ -f "${path}/memories-snapshot.json" ]; then
        echo "yes"
        return 0
    fi

    echo "no"
    return 0
}

# =============================================================================
# extract_knowledge <source_path> <output_dir>
#   Extract knowledge records. Prefers SQLite, falls back to JSON,
#   writes header-only file if neither is available.
# =============================================================================
extract_knowledge() {
    local source_path="$1"
    local output_dir="$2"

    init_output_dir "$output_dir"
    _gsd2_resolve "$source_path" "$output_dir"

    if [ "$_use_sqlite" = "true" ]; then
        sqlite_read_knowledge "$_gsd_db" "$output_dir"
        return 0
    fi

    if has_json_fallback "$source_path"; then
        json_read_knowledge "$source_path" "$output_dir"
        return 0
    fi

    # No data source available — write header-only file
    write_header "${output_dir}/knowledge.dat" "$KNOWLEDGE_FIELDS"
    emit_warning "$output_dir" "NO_SOURCE" \
        "No knowledge data source found (no gsd.db or memories-snapshot.json)" \
        "$source_path"
}

# =============================================================================
# extract_decisions <source_path> <output_dir>
#   Extract decision records. Prefers SQLite, falls back to JSON,
#   writes header-only file if neither is available.
# =============================================================================
extract_decisions() {
    local source_path="$1"
    local output_dir="$2"

    init_output_dir "$output_dir"
    _gsd2_resolve "$source_path" "$output_dir"

    if [ "$_use_sqlite" = "true" ]; then
        sqlite_read_decisions "$_gsd_db" "$output_dir"
        return 0
    fi

    if has_json_fallback "$source_path"; then
        json_read_decisions "$source_path" "$output_dir"
        return 0
    fi

    # No data source available — write header-only file
    write_header "${output_dir}/decisions.dat" "$DECISIONS_FIELDS"
    emit_warning "$output_dir" "NO_SOURCE" \
        "No decisions data source found (no gsd.db or state-manifest.json)" \
        "$source_path"
}

# =============================================================================
# extract_requirements <source_path> <output_dir>
#   Extract requirement records. Prefers SQLite, falls back to JSON,
#   writes header-only file if neither is available.
# =============================================================================
extract_requirements() {
    local source_path="$1"
    local output_dir="$2"

    init_output_dir "$output_dir"
    _gsd2_resolve "$source_path" "$output_dir"

    if [ "$_use_sqlite" = "true" ]; then
        sqlite_read_requirements "$_gsd_db" "$output_dir"
        return 0
    fi

    if has_json_fallback "$source_path"; then
        json_read_requirements "$source_path" "$output_dir"
        return 0
    fi

    # No data source available — write header-only file
    write_header "${output_dir}/requirements.dat" "$REQUIREMENTS_FIELDS"
    emit_warning "$output_dir" "NO_SOURCE" \
        "No requirements data source found (no gsd.db or state-manifest.json)" \
        "$source_path"
}

# =============================================================================
# extract_milestones <source_path> <output_dir>
#   Extract milestone, slice, and task records. Produces 3 files:
#     - milestones.dat
#     - slices.dat
#     - tasks.dat
#   Prefers SQLite, falls back to JSON + filesystem scan.
# =============================================================================
extract_milestones() {
    local source_path="$1"
    local output_dir="$2"

    init_output_dir "$output_dir"
    _gsd2_resolve "$source_path" "$output_dir"

    if [ "$_use_sqlite" = "true" ]; then
        sqlite_read_milestones "$_gsd_db" "$output_dir"
        sqlite_read_slices "$_gsd_db" "$output_dir"
        sqlite_read_tasks "$_gsd_db" "$output_dir"
        return 0
    fi

    if has_json_fallback "$source_path"; then
        json_read_milestones "$source_path" "$output_dir"
        json_read_slices "$source_path" "$output_dir"
        json_read_tasks "$source_path" "$output_dir"
        # Also scan filesystem to discover any milestones not in JSON
        scan_milestone_dirs "$source_path" "$output_dir"
        return 0
    fi

    # No structured data — write header-only files and scan filesystem
    write_header "${output_dir}/milestones.dat" "$MILESTONES_FIELDS"
    write_header "${output_dir}/slices.dat" "$SLICES_FIELDS"
    write_header "${output_dir}/tasks.dat" "$TASKS_FIELDS"

    # Attempt filesystem discovery even without JSON
    scan_milestone_dirs "$source_path" "$output_dir"

    emit_warning "$output_dir" "NO_SOURCE" \
        "No milestone data source found (no gsd.db or state-manifest.json); used filesystem scan only" \
        "$source_path"
}

# =============================================================================
# extract_telemetry <source_path> <output_dir>
#   Extract telemetry/verification records. Prefers SQLite, falls back to JSON,
#   writes header-only file if neither is available.
# =============================================================================
extract_telemetry() {
    local source_path="$1"
    local output_dir="$2"

    init_output_dir "$output_dir"
    _gsd2_resolve "$source_path" "$output_dir"

    if [ "$_use_sqlite" = "true" ]; then
        sqlite_read_telemetry "$_gsd_db" "$output_dir"
        return 0
    fi

    if has_json_fallback "$source_path"; then
        json_read_telemetry "$source_path" "$output_dir"
        return 0
    fi

    # No data source available — write header-only file
    write_header "${output_dir}/telemetry.dat" "$TELEMETRY_FIELDS"
    emit_warning "$output_dir" "NO_SOURCE" \
        "No telemetry data source found (no gsd.db or state-manifest.json)" \
        "$source_path"
}

# =============================================================================
# Self-validation — confirm all required adapter functions are defined
# Guard against re-entry when validate_adapter sources this file in subshells.
# =============================================================================
if [ -z "${_GSD2_VALIDATING:-}" ]; then
    _GSD2_VALIDATING=1
    export _GSD2_VALIDATING
    validate_adapter "${BASH_SOURCE[0]}"
    unset _GSD2_VALIDATING
fi
