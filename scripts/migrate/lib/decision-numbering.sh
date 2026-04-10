#!/usr/bin/env bash
[ -n "${_DECISION_NUMBERING_SOURCED:-}" ] && return 0
_DECISION_NUMBERING_SOURCED=1
# scripts/migrate/lib/decision-numbering.sh — Track max decision ID
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+
#
# Usage: source this file, then call get_max_decision_id <decisions_dat>
#
# Provides two functions:
#   get_max_decision_id <decisions_dat>  — find highest D### number
#   format_migration_header <max_id> <source_type> <migration_date>
# =============================================================================

# get_max_decision_id <decisions_dat>
#   Parse decisions.dat and return the highest numeric decision ID.
#   Decision IDs are expected in D### format (e.g., D001, D042, D153).
#   Uses awk to avoid subshell variable scoping issues.
get_max_decision_id() {
    local decisions_dat="$1"
    tail -n +2 "$decisions_dat" | awk -F'\t' '{
        id = $1
        gsub(/^D0*/, "", id)
        if (id+0 > max) max = id+0
    } END { print max+0 }'
}

# format_migration_header <max_id> <source_type> <migration_date>
#   Generate the migration provenance line for the DECISIONS.md header.
format_migration_header() {
    local max_id="$1"
    local source_type="$2"
    local migration_date="$3"
    local next_id=$((max_id + 1))
    printf 'Migrated from %s on %s. Entries D001-D%03d are historical imports. New decisions continue from D%03d.' \
        "$source_type" "$migration_date" "$max_id" "$next_id"
}
