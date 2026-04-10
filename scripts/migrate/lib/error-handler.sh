#!/usr/bin/env bash
[ -n "${_ERROR_HANDLER_SOURCED:-}" ] && return 0
_ERROR_HANDLER_SOURCED=1
# scripts/migrate/lib/error-handler.sh — Skip-and-warn error handling
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+
#
# Provides handle_malformed_entry() for graceful skip-and-warn on bad data.
# Preserves raw data in archive/migration-errors/ for post-migration review.
# =============================================================================

# handle_malformed_entry <output_dir> <entry_id> <error_message> <raw_data>
# Preserves raw data in archive/migration-errors/ and emits a warning
handle_malformed_entry() {
    local output_dir="$1"
    local entry_id="$2"
    local error_msg="$3"
    local raw_data="${4:-}"

    # Create error archive
    local error_dir="${output_dir}/archive/migration-errors"
    mkdir -p "$error_dir"

    # Save raw data
    if [ -n "$raw_data" ]; then
        echo "$raw_data" > "$error_dir/${entry_id}.raw"
    fi

    # Emit warning (uses adapter-interface.sh's emit_warning if available)
    if type emit_warning >/dev/null 2>&1; then
        emit_warning "$output_dir" "malformed" "$error_msg" "$entry_id"
    else
        echo "WARNING: [$entry_id] $error_msg" >&2
    fi
}
