#!/usr/bin/env bash
# scripts/migrate/lib/idempotency.sh — Check for existing orchestrator state
# =============================================================================
#
# Version: 1.1
# Compatibility: Bash 3.2+
#
# Provides two functions:
#   check_existing_state <target_root>
#     Returns "clean" or "has_state".
#     Detects orchestrator state under $target_root in two layouts:
#       (a) $target_root IS an orchestrator root (KNOWLEDGE-INDEX.md, DECISIONS.md,
#           knowledge/, milestones/ directly under it)
#       (b) $target_root is a project root containing .orchestrator/ or
#           .specify/orchestrator/ subdirectories
#   enforce_conflict_policy <target> <pol>  — abort/merge/force gating
# =============================================================================

# check_existing_state <target_root>
# Returns: "clean" | "has_state"
#
# Detects orchestrator state in two layouts:
#   (a) $target IS an orchestrator root — marker files directly under it
#   (b) $target is a project root containing .orchestrator/ or
#       .specify/orchestrator/ subdirectories (legacy / parent-dir mode)
check_existing_state() {
    local target="$1"

    # Layout (a): target is an orchestrator root
    if [ -f "$target/KNOWLEDGE-INDEX.md" ]; then
        echo "has_state"
        return
    fi
    if [ -f "$target/DECISIONS.md" ]; then
        echo "has_state"
        return
    fi
    if [ -d "$target/knowledge" ]; then
        # Any *.md directly under knowledge/ counts as state
        for f in "$target/knowledge"/*.md "$target/knowledge"/*/*.md; do
            if [ -f "$f" ]; then
                echo "has_state"
                return
            fi
        done
    fi
    if [ -d "$target/milestones" ]; then
        echo "has_state"
        return
    fi

    # Layout (b): target is a project root with orchestrator subdirs
    if [ -d "$target/.orchestrator" ] && [ -n "$(ls -A "$target/.orchestrator" 2>/dev/null)" ]; then
        echo "has_state"
        return
    fi
    if [ -d "$target/.specify/orchestrator" ] && [ -n "$(ls -A "$target/.specify/orchestrator" 2>/dev/null)" ]; then
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
