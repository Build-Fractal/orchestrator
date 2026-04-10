#!/usr/bin/env bash
[ -n "${_SCOPE_TAG_SOURCED:-}" ] && return 0
_SCOPE_TAG_SOURCED=1
set -euo pipefail

# =============================================================================
# scope-tag.sh — Derive scope tags from source unit IDs
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+
#
# Usage: source this file, then call derive_scope_tag <source_unit_id>
# Returns scope tag to stdout.
#
# Mapping rules:
#   "M008/S02" → "[milestone:M008]"  (milestone scope from milestone/slice pair)
#   "M008"     → "[milestone:M008]"  (milestone scope from milestone only)
#   ""         → "[project]"          (no source = project-wide)
#   "global"   → "[project]"          (global entries = project-wide)
# =============================================================================

derive_scope_tag() {
    local source_unit="$1"

    if [ -z "$source_unit" ] || [ "$source_unit" = "global" ]; then
        echo "[project]"
        return
    fi

    # Extract milestone ID (first component before /)
    local milestone_id
    milestone_id="$(echo "$source_unit" | cut -d'/' -f1)"

    # Validate it looks like M###
    case "$milestone_id" in
        M[0-9]*)
            echo "[milestone:${milestone_id}]"
            ;;
        *)
            echo "[project]"
            ;;
    esac
}
