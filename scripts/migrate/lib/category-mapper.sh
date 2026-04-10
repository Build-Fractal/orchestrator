#!/usr/bin/env bash
[ -n "${_CATEGORY_MAPPER_SOURCED:-}" ] && return 0
_CATEGORY_MAPPER_SOURCED=1
set -euo pipefail

# =============================================================================
# category-mapper.sh — Map source categories to orchestrator categories
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+
#
# Usage: source this file, then call map_category <source_category>
# Returns the mapped category to stdout.
#
# GSD2 categories map 1:1 to orchestrator (per spec 003, US3):
#   gotcha → gotcha
#   convention → convention
#   pattern → pattern
#   infrastructure → infrastructure
#   global-rule → global-rule
#
# Unknown categories default to "pattern" with a warning.
# =============================================================================

map_category() {
    local source_cat="$1"
    case "$source_cat" in
        gotcha|convention|pattern|infrastructure|global-rule)
            echo "$source_cat"
            ;;
        "")
            echo "pattern"
            ;;
        *)
            echo "pattern"
            echo "WARNING: Unknown category '$source_cat', mapped to 'pattern'" >&2
            ;;
    esac
}
