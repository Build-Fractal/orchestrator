#!/usr/bin/env bash
# scripts/migrate/lib/idempotency.sh — Check for existing orchestrator state
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+
#
# Provides two functions:
#   check_existing_state <target_root>     — returns "clean" or "has_state"
#   enforce_conflict_policy <target> <pol>  — abort/merge/force gating
# =============================================================================

# check_existing_state <target_root>
# Returns: "clean" | "has_state"
check_existing_state() {
    local target="$1"

    if [ -d "$target/.specify/orchestrator" ]; then
        echo "has_state"
        return
    fi
    if [ -d "$target/knowledge" ] && [ -n "$(ls "$target/knowledge/"*.md 2>/dev/null)" ]; then
        echo "has_state"
        return
    fi
    if [ -f "$target/DECISIONS.md" ]; then
        echo "has_state"
        return
    fi
    if [ -f "$target/KNOWLEDGE-INDEX.md" ]; then
        echo "has_state"
        return
    fi

    echo "clean"
}

# enforce_conflict_policy <target_root> <policy>
# policy: abort | merge | force
# Returns 0 if OK to proceed, exits 4 if abort
enforce_conflict_policy() {
    local target="$1"
    local policy="$2"

    local state
    state="$(check_existing_state "$target")"

    if [ "$state" = "clean" ]; then
        return 0
    fi

    case "$policy" in
        abort)
            echo "ERROR: Orchestrator state already exists at $target" >&2
            echo "Options: --merge (add new, skip existing), --force (overwrite), --abort (cancel)" >&2
            exit 4
            ;;
        force)
            echo "WARNING: Force mode — existing state will be overwritten" >&2
            return 0
            ;;
        merge)
            echo "INFO: Merge mode — new entries will be added, existing skipped" >&2
            return 0
            ;;
    esac
}
