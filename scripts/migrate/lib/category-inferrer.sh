#!/usr/bin/env bash
[ -n "${_CATEGORY_INFERRER_SOURCED:-}" ] && return 0
_CATEGORY_INFERRER_SOURCED=1
# scripts/migrate/lib/category-inferrer.sh — Infer knowledge category from content
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no ${var,,} lowercase)
#
# GSD v1 entries have no category field. This script infers one from content
# keywords using case-insensitive matching via tr.
#
# Usage: source this file, then call infer_category <content_text>
# =============================================================================

infer_category() {
    local content="$1"
    local lower
    # Convert to lowercase for matching (Bash 3.2 compatible -- use tr)
    lower="$(printf '%s' "$content" | tr '[:upper:]' '[:lower:]')"

    # Check for gotcha indicators
    case "$lower" in
        *"gotcha"*|*"trap"*|*"pitfall"*|*"watch out"*|*"careful"*|*"bug"*|*"workaround"*|*"issue"*|*"warning"*|*"avoid"*)
            echo "gotcha"
            return ;;
    esac

    # Check for convention indicators
    case "$lower" in
        *"convention"*|*"naming"*|*"style"*|*"format"*|*"must use"*|*"always"*|*"never"*|*"standard"*)
            echo "convention"
            return ;;
    esac

    # Check for infrastructure indicators
    case "$lower" in
        *"infrastructure"*|*"deploy"*|*"ci"*|*"pipeline"*|*"docker"*|*"server"*|*"config"*|*"environment"*)
            echo "infrastructure"
            return ;;
    esac

    # Check for global-rule indicators
    case "$lower" in
        *"global rule"*|*"global-rule"*|*"everywhere"*|*"all files"*|*"project-wide"*)
            echo "global-rule"
            return ;;
    esac

    # Default to pattern
    echo "pattern"
}
