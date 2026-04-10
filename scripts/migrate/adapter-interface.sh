#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# adapter-interface.sh — Adapter Interface Contract & Intermediate Data Format
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no pipe-ampersand, no lowercase expansion)
#
# This file defines the contract that every source adapter must implement,
# the intermediate data format (TSV) used between extraction and import,
# and shared utility functions used by adapters and the migration pipeline.
#
# Source this file in adapters and pipeline scripts:
#   source "$(dirname "$0")/adapter-interface.sh"
#
# =============================================================================
# !! READ-ONLY CONSTRAINT !!
# =============================================================================
# Adapters MUST NEVER modify the source project. All operations on the source
# path are strictly READ-ONLY. Adapters extract data; they never write back.
# The migration tool is NON-DESTRUCTIVE — the source remains untouched.
# =============================================================================

ADAPTER_INTERFACE_VERSION="1.0"

# -----------------------------------------------------------------------------
# SECTION_ADAPTER_CONTRACT — Required Functions
# -----------------------------------------------------------------------------
#
# Every adapter script placed in scripts/migrate/adapters/ must implement
# all 6 of the following functions. The validate_adapter() utility below
# checks for their existence at runtime.
#
# 1. detect_source <path>
#    Inspect <path> and echo "yes" if this adapter can handle it, "no" otherwise.
#    Must not modify <path>. Exit 0 in both cases.
#
# 2. extract_knowledge <src> <out>
#    Read knowledge artifacts from <src> and write knowledge.dat to <out>.
#    Fields: KNOWLEDGE_FIELDS (see below).
#
# 3. extract_decisions <src> <out>
#    Read decision records from <src> and write decisions.dat to <out>.
#    Fields: DECISIONS_FIELDS (see below).
#
# 4. extract_requirements <src> <out>
#    Read requirements from <src> and write requirements.dat to <out>.
#    Fields: REQUIREMENTS_FIELDS (see below).
#
# 5. extract_milestones <src> <out>
#    Read milestone/slice/task data from <src> and write:
#      - milestones.dat  (fields: MILESTONES_FIELDS)
#      - slices.dat      (fields: SLICES_FIELDS)
#      - tasks.dat       (fields: TASKS_FIELDS)
#
# 6. extract_telemetry <src> <out>
#    Read telemetry/metrics from <src> and write telemetry.dat to <out>.
#    Fields: TELEMETRY_FIELDS (see below).
#

# Required adapter function names
ADAPTER_REQUIRED_FUNCTIONS="detect_source extract_knowledge extract_decisions extract_requirements extract_milestones extract_telemetry"

# -----------------------------------------------------------------------------
# SECTION_DATA_FORMAT — Intermediate Data Format (TSV)
# -----------------------------------------------------------------------------
#
# All .dat files use tab-separated values (TSV):
#   - First line is always the header (field names separated by tabs)
#   - One record per line after the header
#   - Newlines within values are escaped as literal two-char sequence: \n
#   - Tabs within values are escaped as literal two-char sequence: \t
#   - Empty fields are represented as adjacent tabs (no placeholder)
#   - Files use Unix line endings (LF only)
#

# -----------------------------------------------------------------------------
# SECTION_KNOWLEDGE — Knowledge Field Definitions
# -----------------------------------------------------------------------------
KNOWLEDGE_FIELDS="id	category	title	content	source_file	priority	hit_count	created_at	updated_at	superseded_by"

# -----------------------------------------------------------------------------
# SECTION_DECISIONS — Decision Field Definitions
# -----------------------------------------------------------------------------
DECISIONS_FIELDS="id	title	status	date	context	decision	consequences	revisable	made_by	superseded_by"

# -----------------------------------------------------------------------------
# SECTION_REQUIREMENTS — Requirement Field Definitions
# -----------------------------------------------------------------------------
REQUIREMENTS_FIELDS="id	type	priority	title	description	acceptance_criteria	source	validation_status	validated_by	superseded_by"

# -----------------------------------------------------------------------------
# SECTION_MILESTONES — Milestone Field Definitions
# -----------------------------------------------------------------------------
MILESTONES_FIELDS="id	title	status	description	start_date	end_date"

# -----------------------------------------------------------------------------
# SECTION_SLICES — Slice Field Definitions
# -----------------------------------------------------------------------------
SLICES_FIELDS="id	milestone_id	title	status	description	order"

# -----------------------------------------------------------------------------
# SECTION_TASKS — Task Field Definitions
# -----------------------------------------------------------------------------
TASKS_FIELDS="id	slice_id	milestone_id	title	status	description	assignee	depends_on"

# -----------------------------------------------------------------------------
# SECTION_TELEMETRY — Telemetry Field Definitions
# -----------------------------------------------------------------------------
TELEMETRY_FIELDS="id	timestamp	event_type	entity_id	entity_type	details	source_file	milestone_id	slice_id"

# -----------------------------------------------------------------------------
# SECTION_UTILITIES — Shared Utility Functions
# -----------------------------------------------------------------------------

# escape_field <value>
#   Escape tabs and newlines in a field value for TSV storage.
#   Tabs become literal \t, newlines become literal \n.
escape_field() {
    local val="$1"
    # Escape backslashes first to avoid double-escaping
    val="$(printf '%s' "$val" | sed 's/\\/\\\\/g')"
    # Escape tabs
    val="$(printf '%s' "$val" | sed $'s/\t/\\\\t/g')"
    # Escape newlines — use tr to convert, then sed to mark
    val="$(printf '%s' "$val" | tr '\n' '\x01' | sed 's/\x01/\\n/g')"
    printf '%s' "$val"
}

# unescape_field <value>
#   Reverse the escaping done by escape_field.
#   Literal \n becomes newline, literal \t becomes tab.
unescape_field() {
    local val="$1"
    # Unescape \n to newline and \t to tab, then \\\\ back to backslash
    # Process in reverse order of escape_field
    val="$(printf '%s' "$val" | sed 's/\\n/\
/g')"
    val="$(printf '%s' "$val" | sed $'s/\\\\t/\t/g')"
    val="$(printf '%s' "$val" | sed 's/\\\\/\\/g')"
    printf '%s' "$val"
}

# write_header <file> <fields_string>
#   Write the TSV header line to a file. Overwrites existing content.
#   <fields_string> is a tab-separated string of field names.
write_header() {
    local file="$1"
    local fields="$2"
    printf '%s\n' "$fields" > "$file"
}

# append_record <file> <field1> [<field2> ...]
#   Append a TSV record to a file. Each argument is one field value.
#   Fields are escaped automatically.
append_record() {
    local file="$1"
    shift

    local line=""
    local first=1
    for field_val in "$@"; do
        local escaped
        escaped="$(escape_field "$field_val")"
        if [ "$first" -eq 1 ]; then
            line="$escaped"
            first=0
        else
            line="${line}	${escaped}"
        fi
    done
    printf '%s\n' "$line" >> "$file"
}

# validate_adapter <adapter_script>
#   Source the adapter and verify it implements all required functions.
#   Returns 0 if valid, 1 if any function is missing.
#   Prints missing function names to stderr.
validate_adapter() {
    local adapter_script="$1"

    if [ ! -f "$adapter_script" ]; then
        echo "ERROR: Adapter file not found: $adapter_script" >&2
        return 1
    fi

    # Source the adapter in a subshell to avoid polluting current scope
    local missing=""
    local valid=0
    for func_name in $ADAPTER_REQUIRED_FUNCTIONS; do
        # Check if function is defined after sourcing
        if ! ( source "$adapter_script" && type "$func_name" >/dev/null 2>&1 ); then
            missing="${missing} ${func_name}"
            valid=1
        fi
    done

    if [ "$valid" -ne 0 ]; then
        echo "ERROR: Adapter '$adapter_script' is missing required functions:${missing}" >&2
        return 1
    fi

    return 0
}

# init_output_dir <dir>
#   Create the output directory if it does not exist.
#   Returns 0 on success, 1 on failure.
init_output_dir() {
    local dir="$1"
    if [ -z "$dir" ]; then
        echo "ERROR: init_output_dir requires a directory path" >&2
        return 1
    fi
    mkdir -p "$dir"
}

# emit_warning <output_dir> <code> <message> [<source_file>]
#   Append a structured warning to warnings.dat in the output directory.
#   Creates the file with header if it does not exist.
emit_warning() {
    local output_dir="$1"
    local code="$2"
    local message="$3"
    local source_file="${4:-}"
    local warnings_file="${output_dir}/warnings.dat"

    if [ ! -f "$warnings_file" ]; then
        write_header "$warnings_file" "timestamp	code	message	source_file"
    fi

    local ts
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    append_record "$warnings_file" "$ts" "$code" "$message" "$source_file"
}
