#!/usr/bin/env bash
# scripts/util/start-state-markers.sh
#
# FR-20 / CON-6 sub-flow start-state marker primitives for M033
# (Project Onboarding Experience). Provides the read-side stdlib used by
# scripts/lifecycle/start.sh resume-on-partial-state, and the write-side
# primitive that P03/P04/P05 sub-flow real-implementation tasks call at
# completion.
#
# Marker layout (on-disk truth, MEM003):
#   <project-dir>/.orchestrator/start-state/<sub-flow-name>.complete
#
# The marker file body is the ISO 8601 UTC timestamp of the FIRST write
# (idempotent: re-write of an existing marker is a no-op so the
# first-completion timestamp is preserved as a recovery aid).
#
# Closed sub-flow-name enum (execution order):
#   1. init-invoked
#   2. ideation
#   3. materials-intake
#   4. ingest-codebase
#   5. migrate-routed
#   6. constitution-authored
#   7. customblock-drafted
#
# Subcommands:
#   write <sub-flow-name> <project-dir>    Write marker (idempotent).
#   read  <project-dir>                    List completed sub-flow names,
#                                          one per line, in execution order.
#   next  <project-dir>                    Print the first sub-flow whose
#                                          marker is absent (empty if all
#                                          present).
#   clear <sub-flow-name> <project-dir>    Remove a single named marker
#                                          (no-op if absent).
#
# The 7 sub-flow names are a closed enum. Unknown names exit non-zero
# with the enum echoed to stderr. The `.complete` filename suffix is
# load-bearing — downstream consumers (run-doctor.sh per spec) match it
# as a literal token; do NOT abbreviate.
#
# FR-7 alias mapping (M033/P03/T05 SSOT harmonization):
#   The closed sub-flow enum value is `ingest-codebase` (pre-completion
#   form). The FR-7 doc-prose at commands/ingest-codebase.md and
#   scripts/lifecycle/ingest-codebase.sh additionally references
#   `ingest-codebase-completed.complete` as a load-bearing semantic alias
#   (post-completion form). Both forms refer to the SAME on-disk marker
#   file at <project-dir>/.orchestrator/start-state/ingest-codebase.complete
#   — the alias is a documentation aid, not a second marker. Operators
#   and verifiers MUST treat them as identical.
#
# Bash 3.2 compatible (MEM001): no associative arrays, no process
# substitution, no $(...) containing pipes.
#
# spec ref: FR-20 (marker convention), CON-6 (resume on partial state)

set -e
set -u
set -o pipefail

# ---------------------------------------------------------------------------
# Closed sub-flow name enum (SSOT — fenced for grep parity)
# ---------------------------------------------------------------------------
#
# The fenced block below is the SSOT consumed by the T02 verifier and
# by start.sh resume-detection. All 7 names appear as literal tokens in
# execution order. Do NOT paraphrase.
#
# >>> subflow-names >>>
# init-invoked
# ideation
# materials-intake
# ingest-codebase
# migrate-routed
# constitution-authored
# customblock-drafted
# <<< subflow-names <<<

SUBFLOW_ENUM='init-invoked ideation materials-intake ingest-codebase migrate-routed constitution-authored customblock-drafted'

USAGE='usage: start-state-markers.sh write <sub-flow-name> <project-dir>
       start-state-markers.sh read <project-dir>
       start-state-markers.sh next <project-dir>
       start-state-markers.sh clear <sub-flow-name> <project-dir>'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

is_valid_subflow() {
    case "$1" in
        init-invoked|ideation|materials-intake|ingest-codebase|migrate-routed|constitution-authored|customblock-drafted)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

reject_unknown_subflow() {
    local subflow="$1"
    echo "unknown sub-flow name: $subflow" 1>&2
    echo "valid: $SUBFLOW_ENUM" 1>&2
    return 2
}

# ---------------------------------------------------------------------------
# Subcommand implementations
# ---------------------------------------------------------------------------

write_marker() {
    local subflow="$1"
    local project_dir="$2"
    if ! is_valid_subflow "$subflow"; then
        reject_unknown_subflow "$subflow"
        return 2
    fi
    local marker_dir="$project_dir/.orchestrator/start-state"
    local marker_path="$marker_dir/$subflow.complete"
    mkdir -p "$marker_dir"
    if [ ! -f "$marker_path" ]; then
        date -u +%Y-%m-%dT%H:%M:%SZ > "$marker_path"
    fi
    return 0
}

read_markers() {
    local project_dir="$1"
    local marker_dir="$project_dir/.orchestrator/start-state"
    local subflow
    for subflow in init-invoked ideation materials-intake ingest-codebase migrate-routed constitution-authored customblock-drafted; do
        if [ -f "$marker_dir/$subflow.complete" ]; then
            echo "$subflow"
        fi
    done
    return 0
}

next_marker() {
    local project_dir="$1"
    local marker_dir="$project_dir/.orchestrator/start-state"
    local subflow
    for subflow in init-invoked ideation materials-intake ingest-codebase migrate-routed constitution-authored customblock-drafted; do
        if [ ! -f "$marker_dir/$subflow.complete" ]; then
            echo "$subflow"
            return 0
        fi
    done
    echo ""
    return 0
}

clear_marker() {
    local subflow="$1"
    local project_dir="$2"
    if ! is_valid_subflow "$subflow"; then
        reject_unknown_subflow "$subflow"
        return 2
    fi
    local marker_path="$project_dir/.orchestrator/start-state/$subflow.complete"
    if [ -f "$marker_path" ]; then
        rm -f "$marker_path"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Top-level dispatcher
# ---------------------------------------------------------------------------

main() {
    if [ $# -lt 1 ]; then
        printf '%s\n' "$USAGE" 1>&2
        exit 2
    fi
    local cmd="$1"
    shift
    case "$cmd" in
        write)
            if [ $# -lt 2 ]; then
                printf '%s\n' "$USAGE" 1>&2
                exit 2
            fi
            write_marker "$1" "$2"
            ;;
        read)
            if [ $# -lt 1 ]; then
                printf '%s\n' "$USAGE" 1>&2
                exit 2
            fi
            read_markers "$1"
            ;;
        next)
            if [ $# -lt 1 ]; then
                printf '%s\n' "$USAGE" 1>&2
                exit 2
            fi
            next_marker "$1"
            ;;
        clear)
            if [ $# -lt 2 ]; then
                printf '%s\n' "$USAGE" 1>&2
                exit 2
            fi
            clear_marker "$1" "$2"
            ;;
        *)
            printf 'unknown subcommand: %s\n' "$cmd" 1>&2
            printf '%s\n' "$USAGE" 1>&2
            exit 2
            ;;
    esac
}

main "$@"
