#!/usr/bin/env bash
# jsonl-event-emitter.sh
#
# FR-22 observability record emitter for M033 (Project Onboarding
# Experience). Spec: 036-project-onboarding-experience.
#
# Appends a single JSON-line record to
#   <PROJECT_DIR>/.orchestrator/execution-log.jsonl
# (created if absent) with the documented schema:
#
#   {
#     "schema_version": "1.0",
#     "event_type":     "<one of 12 closed-enum tokens>",
#     "timestamp":      "<ISO 8601 UTC, date -u +%Y-%m-%dT%H:%M:%SZ>",
#     "payload":        <opaque JSON object supplied by caller>
#   }
#
# Schema version is fixed at 1.0 for M033. Bumping to 1.1 requires a
# follow-up M033 D-row (M020 D024 reversibility-clause precedent).
#
# The 12 documented event types (FR-22 closed enum, extended 11 -> 12 in
# M033/P03/T04 to add imported_context_loaded for the FR-8 / MIT-005
# rich-context import path; SSOT count harmonized in T05 per #Q-11):
#   - start_branch_detected
#   - start_init_invoked
#   - constitution_authored
#   - ingest_codebase_completed
#   - materials_intake_completed
#   - ideation_completed
#   - migrate_routed
#   - customblock_drafted
#   - wiki_init_invoked
#   - github_init_invoked
#   - friendly_tester_report_validated
#   - imported_context_loaded
#
# Bash 3.2 compatible (MEM001) — no `declare -A`, no process
# substitution, no `$(...)` containing pipes.
#
# Append atomicity (Constitution VI State On Disk Is Truth):
#   The script formats the entire JSON line in memory via a single
#   `printf`, then appends via `>>`. POSIX guarantees atomic append
#   for writes <= PIPE_BUF (macOS 512). The emitter REFUSES payloads
#   that, after formatting, exceed 480 bytes per record (well under
#   macOS PIPE_BUF), exiting non-zero with `payload too large for
#   atomic append` to stderr. This makes Ctrl+C mid-write incapable
#   of corrupting the JSONL surface.
#
# Usage:
#   bash scripts/util/jsonl-event-emitter.sh emit <event_type> <payload_json>
#
# Project base directory:
#   PROJECT_DIR env override is honored. Falls back to $PWD when unset.
#   Calling commands SHOULD set PROJECT_DIR explicitly (matches the
#   start.sh convention from P01).
#
# Reserved for future (out of T01 scope, demand-driven):
#   - `validate <log-path>` — read-side / log-shape parser. Would
#     consume scripts/util/json-field.sh for parse-side discipline.
#     M027 / M019 currently consume the JSONL surface programmatically
#     without a dedicated CLI parser.

set -e -u -o pipefail

# >>> event-types >>>
# start_branch_detected
# start_init_invoked
# constitution_authored
# ingest_codebase_completed
# materials_intake_completed
# ideation_completed
# migrate_routed
# customblock_drafted
# wiki_init_invoked
# github_init_invoked
# friendly_tester_report_validated
# imported_context_loaded
# <<< event-types <<<

emit() {
    if [ "$#" -lt 2 ]; then
        echo "usage: jsonl-event-emitter.sh emit <event_type> <payload_json>" >&2
        return 2
    fi
    local event_type="$1"
    local payload_json="$2"

    # Validate event_type against closed enum.
    case "$event_type" in
        start_branch_detected|start_init_invoked|constitution_authored|\
ingest_codebase_completed|materials_intake_completed|ideation_completed|\
migrate_routed|customblock_drafted|wiki_init_invoked|github_init_invoked|\
friendly_tester_report_validated|imported_context_loaded)
            # M033/P03/T04 #Q-11: imported_context_loaded is the FR-8 / MIT-005
            # rich-context import event emitted by scripts/lifecycle/ingest-codebase.sh
            # when DR-/MILESTONE-AUDIT/CLAUDE custom-block signals fire. Additive
            # extension of the closed enum — no behavior change for existing
            # callers. T05 will harmonize the SSOT documentation in P02 references.
            ;;
        *)
            echo "unknown event_type: $event_type" >&2
            echo "valid: start_branch_detected start_init_invoked constitution_authored ingest_codebase_completed materials_intake_completed ideation_completed migrate_routed customblock_drafted wiki_init_invoked github_init_invoked friendly_tester_report_validated imported_context_loaded" >&2
            return 2
            ;;
    esac

    # Validate payload_json is a JSON object (starts with `{`, ends with `}`).
    case "$payload_json" in
        \{*\}) ;;
        *)
            echo "payload_json must be a JSON object: $payload_json" >&2
            return 2
            ;;
    esac

    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Determine project_dir: env override PROJECT_DIR, else $PWD.
    local project_dir="${PROJECT_DIR:-$PWD}"
    local log_dir="$project_dir/.orchestrator"
    local log_path="$log_dir/execution-log.jsonl"
    mkdir -p "$log_dir"

    # Format the single JSON line.
    local line
    line="$(printf '{"schema_version":"1.0","event_type":"%s","timestamp":"%s","payload":%s}' \
        "$event_type" "$timestamp" "$payload_json")"

    # Atomic-append size guard (max 480 bytes per record, under macOS PIPE_BUF 512).
    local linelen=${#line}
    if [ "$linelen" -gt 480 ]; then
        echo "payload too large for atomic append: $linelen > 480 bytes" >&2
        return 2
    fi

    printf '%s\n' "$line" >> "$log_path"
    return 0
}

# Top-level dispatcher.
case "${1:-}" in
    emit)
        shift
        emit "$@"
        ;;
    -h|--help|help)
        echo "usage: jsonl-event-emitter.sh emit <event_type> <payload_json>"
        exit 0
        ;;
    *)
        echo "unknown subcommand: ${1:-}" >&2
        echo "usage: jsonl-event-emitter.sh emit <event_type> <payload_json>" >&2
        exit 2
        ;;
esac
