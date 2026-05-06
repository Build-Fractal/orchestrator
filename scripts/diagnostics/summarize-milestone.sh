#!/usr/bin/env bash
# scripts/diagnostics/summarize-milestone.sh -- M029 / AD-4 milestone summary helper.
#
# Read-only deterministic helper that emits a fixed-order key=value block
# describing a milestone's progress: phase_count, phases_complete,
# tasks_remaining, intensity. Consumed by render-position.sh (T03) for the
# cross-milestone feature view and by P03's SC-8 oracle wrapper
# (predictive-surface.sh --milestone is amended at AD-4 to wrap this helper
# instead, since M027 is closed under CON-3's knowledge-layer boundary).
#
# Read-only (CON-1 / FR-14 / Principle XV): no writes, no log emission, no
# state mutation. The only file system mutation in any consumer is the
# verifier's /tmp/sm-out.$$ capture (allowed under run-probe.sh scope rule
# 4 — /tmp/ is the staged probe domain).
#
# Bash 3.2 compatible (MEM001): no associative arrays, no process
# substitution, no <<< herestrings, no $() containing pipes in the public
# surface. The metrics-rollup.sh MEM004 carve-out permits awk/sed/grep
# pipes inside the script body; Check: lines must remain straight-line
# bash per AD-19.
#
# Sourceable as a library AND runnable as a CLI (mirrors the
# metrics-rollup.sh / efficiency-footer.sh dual shape).
#
# CLI:
#   --milestone <M###>   Milestone ID; defaults to find-active-milestone.sh
#                        output's first token.
#   --format keys|text   Output format; default keys.
#   -h, --help           Print usage to stdout, exit 0.
#
# Output (--format=keys, fixed-order key=value, mirrors AD-1 resolver
# three-line convention):
#
#   phase_count=<integer>
#   phases_complete=<integer>
#   tasks_remaining=<integer>
#   intensity=<quick|standard|full|unknown>
#
# Output (--format=text, single human-readable line):
#
#   <milestone-name> — N/M phases complete, K tasks remaining, intensity=<...>
#
# `intensity` is read from `.orchestrator/milestones/M###/M###-EVALUATION.md`
# (the `intensity:` field in YAML frontmatter); `unknown` is the fallback
# when EVALUATION is absent or malformed.
#
# Exit codes:
#   0 — success (including empty milestone tree).
#   2 — usage / unknown flag / no milestone resolvable.

set -u

# Re-source guard.
if [ -n "${_SUMMARIZE_MILESTONE_SH_SOURCED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
_SUMMARIZE_MILESTONE_SH_SOURCED=1

_SM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SM_PROJECT_ROOT="$(cd "$_SM_SCRIPT_DIR/../.." && pwd)"

# --- Argument parser -----------------------------------------------------
_sm_format="keys"
_sm_milestone=""
while [ $# -gt 0 ]; do
    case "$1" in
        --milestone) shift; _sm_milestone="${1:-}"; shift || true ;;
        --milestone=*) _sm_milestone="${1#--milestone=}"; shift ;;
        --format) shift; _sm_format="${1:-}"; shift || true ;;
        --format=*) _sm_format="${1#--format=}"; shift ;;
        -h|--help)
            printf 'Usage: summarize-milestone.sh [--milestone <M###>] [--format keys|text]\n'
            printf '\n'
            printf 'Read-only milestone summary helper (M029 / AD-4 oracle interface).\n'
            printf '\n'
            printf 'Options:\n'
            printf '  --milestone <M###>   Milestone ID; defaults to find-active-milestone.sh.\n'
            printf '  --format keys|text   Output format; default keys.\n'
            printf '  -h, --help           Show this message.\n'
            exit 0
            ;;
        *)
            printf 'summarize-milestone.sh: unknown flag: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

# --- Default milestone resolution ---------------------------------------
if [ -z "$_sm_milestone" ]; then
    _sm_active_helper="$_SM_PROJECT_ROOT/scripts/state/find-active-milestone.sh"
    if [ -x "$_sm_active_helper" ]; then
        _sm_fa_out="$(bash "$_sm_active_helper" "$_SM_PROJECT_ROOT/.orchestrator" 2>/dev/null || true)"
        # find-active-milestone.sh emits "M### <state> <tier>"; take the first token.
        _sm_milestone="${_sm_fa_out%% *}"
    fi
fi
if [ -z "$_sm_milestone" ]; then
    printf 'summarize-milestone.sh: no milestone specified and no active milestone resolved\n' >&2
    exit 2
fi

# Sanity-check the milestone shape (M followed by digits).
case "$_sm_milestone" in
    M[0-9]*) ;;
    *)
        printf 'summarize-milestone.sh: invalid milestone id: %s (expected M###)\n' "$_sm_milestone" >&2
        exit 2
        ;;
esac

# --- Phase enumeration ---------------------------------------------------
_sm_milestone_dir="$_SM_PROJECT_ROOT/.orchestrator/milestones/$_sm_milestone"
_sm_phase_count=0
_sm_phases_complete=0
_sm_tasks_remaining=0

if [ -d "$_sm_milestone_dir/phases" ]; then
    for _phase_dir in "$_sm_milestone_dir"/phases/P*; do
        [ -d "$_phase_dir" ] || continue
        _sm_phase_count=$(( _sm_phase_count + 1 ))
        _phase_id="$(basename "$_phase_dir")"
        if [ -f "$_phase_dir/$_phase_id-SUMMARY.md" ]; then
            _sm_phases_complete=$(( _sm_phases_complete + 1 ))
        else
            # Count remaining tasks in this in-flight phase: any T##-*-PLAN.md
            # without a paired T##-*-SUMMARY.md is outstanding work.
            if [ -d "$_phase_dir/tasks" ]; then
                for _task_plan in "$_phase_dir/tasks"/T*-PLAN.md; do
                    [ -f "$_task_plan" ] || continue
                    _task_summary="${_task_plan%-PLAN.md}-SUMMARY.md"
                    if [ ! -f "$_task_summary" ]; then
                        _sm_tasks_remaining=$(( _sm_tasks_remaining + 1 ))
                    fi
                done
            fi
        fi
    done
fi

# --- Intensity read (from M###-EVALUATION.md frontmatter) ---------------
_sm_intensity="unknown"
_sm_eval_file="$_sm_milestone_dir/$_sm_milestone-EVALUATION.md"
if [ -f "$_sm_eval_file" ]; then
    _sm_line="$(grep -m1 -E '^intensity:' "$_sm_eval_file" 2>/dev/null || true)"
    if [ -n "$_sm_line" ]; then
        _sm_intensity="${_sm_line#intensity:}"
        _sm_intensity="${_sm_intensity# }"
        _sm_intensity="${_sm_intensity#\"}"
        _sm_intensity="${_sm_intensity%\"}"
        _sm_intensity="$(printf '%s' "$_sm_intensity" | tr '[:upper:]' '[:lower:]')"
        case "$_sm_intensity" in
            quick|standard|full) ;;
            *) _sm_intensity="unknown" ;;
        esac
    fi
fi

# --- Output --------------------------------------------------------------
case "$_sm_format" in
    keys)
        printf 'phase_count=%d\n' "$_sm_phase_count"
        printf 'phases_complete=%d\n' "$_sm_phases_complete"
        printf 'tasks_remaining=%d\n' "$_sm_tasks_remaining"
        printf 'intensity=%s\n' "$_sm_intensity"
        ;;
    text)
        # Read milestone name from M###-ROADMAP.md H1 if present, else fall
        # back to the milestone ID. (M029-ROADMAP.md has no H1 today; the
        # fallback path is the live one.)
        _sm_name="$_sm_milestone"
        _sm_roadmap="$_sm_milestone_dir/$_sm_milestone-ROADMAP.md"
        if [ -f "$_sm_roadmap" ]; then
            _sm_h1="$(grep -m1 -E '^# ' "$_sm_roadmap" 2>/dev/null || true)"
            if [ -n "$_sm_h1" ]; then
                _sm_name="${_sm_h1#\# }"
            fi
        fi
        printf '%s — %d/%d phases complete, %d tasks remaining, intensity=%s\n' \
            "$_sm_name" "$_sm_phases_complete" "$_sm_phase_count" \
            "$_sm_tasks_remaining" "$_sm_intensity"
        ;;
    *)
        printf 'summarize-milestone.sh: unknown --format value: %s\n' "$_sm_format" >&2
        exit 2
        ;;
esac

exit 0
