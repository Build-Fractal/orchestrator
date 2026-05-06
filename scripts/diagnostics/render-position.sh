#!/usr/bin/env bash
# scripts/diagnostics/render-position.sh -- M029 / FR-5 at-rest tree renderer.
#
# At-rest tree renderer for orchestrator:where. Composes M013/M018/M019/M027
# read-only surfaces into a feature -> milestone -> phase -> task tree using
# the canonical glyph alphabet from references/cross-milestone-feature-shape.md.
#
# Glyph alphabet (pinned by AD-6 / cross-milestone-feature-shape.md):
#   ✓  phase / task complete
#   ▶  phase / task currently executing
#   ◇  phase / task pending (not yet started)
#   ✗  phase / task failed (last verify result was `fail`)
#   ▽  savings marker -- P03 --live mode ONLY; the at-rest renderer NEVER
#      emits this glyph itself. The canonical compact form is `▽ saved Nk`
#      (#Q-G8 resolution); any verbose suffix that appends provenance after
#      the magnitude is reserved for a future --verbose mode and MUST NOT
#      appear in v1 deliverables -- see references/cross-milestone-feature-shape.md.
#
# Read-only (CON-1 / FR-14): no writes to .orchestrator/. The only allowed
# write site is ${TMPDIR:-/tmp}/m029-rp.$$/ for transient resolver capture
# (per run-probe.sh scope rule 4 -- /tmp/ is the staged probe domain). The
# trap on EXIT removes that directory.
#
# No GitHub API (CON-4 / FR-11): the renderer MUST NOT invoke `gh` or any
# GitHub HTTP API; the M013 sidecar (the github.json file under the
# integrations subtree of .orchestrator/) is NOT read in v1. SC-13 enforces
# this anti-coupling invariant with a grep guard against the renderer body.
#
# AD-1 single-resolve discipline (Principle XI): invocation context is read
# exclusively from scripts/state/detect-invocation-context.sh's emitted env
# block. This renderer never re-derives TTY / CI / runtime detection.
#
# AD-6 cross-milestone data model: feature spec frontmatter declares either
#   `milestone: M###` (singular legacy form) OR `milestones: [M###, ...]`
#   (plural AD-6 form). Exactly-one-of; both is a schema violation and a
#   stderr WARN: is emitted then plural is preferred.
#
# Reverse-lookup advisory (T01 contract): enumerate
# .orchestrator/milestones/M*/M*-EVALUATION.md, group by feature_ref:; on
# mismatch with the spec's declaration, emit `WARN: feature <slug> spec
# frontmatter declares <set>; reverse-lookup discovered <set>; using spec`
# to stderr. Render proceeds from the spec's declaration (Principle XI).
#
# FR-6 cost-column graceful degradation (CON-3): per-row token/cost column
# is populated by `metrics-rollup.sh --granularity task ...` ONLY when the
# milestone's execution-log.jsonl carries M019 Tier 1 dispatch_usage records.
# When absent, the cost column is OMITTED ENTIRELY -- no blank column, no
# stderr warning. Detection probe is a single grep -m1 -F for the literal
# token `dispatch_usage`.
#
# Bash 3.2 compatible (MEM001): no associative arrays, no process
# substitution, no <<< herestrings, no $(cmd | ...) in the public surface.
# MEM004 carve-out: awk / sed / grep pipes inside the script body are
# permitted; AD-19 verifier-shape rules apply only to Check: commands at
# the task / phase plan level.
#
# AD-19 reminder: this script is the IMPLEMENTATION; verifier scripts in
# tools/verify/m029-p02-render-position-shape.sh keep AD-19 single-script
# straight-line bash discipline.
#
# Cross-references:
#   - references/cross-milestone-feature-shape.md  (AD-6 schema, glyph set)
#   - scripts/state/detect-invocation-context.sh    (AD-1 single-resolve)
#   - scripts/state/find-active-milestone.sh        (active-milestone resolver)
#   - scripts/state/read-roadmap.sh                 (roadmap parser)
#   - scripts/diagnostics/summarize-milestone.sh    (AD-4 SC-8 oracle)
#   - scripts/diagnostics/metrics-rollup.sh         (M027 cost column source)
#   - .orchestrator/milestones/M029/M029-CONTEXT.md (AD-1 / AD-6 / AD-9)
#   - specs/037-roadmap-visibility-cli-ux/spec.md   (FR-5 / FR-6 / FR-11
#                                                    / FR-13 / FR-14 /
#                                                    CON-1 / CON-3 / CON-4)
#
# CLI:
#   --milestone <M###>  Render only the named milestone (active-only view).
#                       Default behavior is the FULL feature view per FR-13.
#   --expand-all        Expand every milestone's full phase tree (default:
#                       inactive milestones are collapsed). #Q-5 resolution.
#   --feature <slug>    Override the active feature; used by SC-5 fixtures.
#   --no-cost           Operator-side cost-column suppression. FR-6's
#                       pre-M019 detection is automatic and silent.
#   --root <path>       Override .orchestrator/ root (fixturing). Required
#                       by SC-5 / SC-6 / SC-14 fixtures.
#   -h, --help          Print usage to stdout, exit 0.
#
# Exit codes:
#   0 -- success (including degraded-but-rendered states).
#   2 -- usage / unknown flag.

set -u

# Re-source guard -- mirrors metrics-rollup.sh / efficiency-footer.sh.
if [ -n "${_RENDER_POSITION_SH_SOURCED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
_RENDER_POSITION_SH_SOURCED=1

_RP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_RP_PROJECT_ROOT="$(cd "$_RP_SCRIPT_DIR/../.." && pwd)"

# --- Argument parser -------------------------------------------------------

_rp_print_usage() {
    cat <<'EOF'
Usage: render-position.sh [--milestone <M###>] [--expand-all] [--feature <slug>]
                          [--no-cost] [--root <path>] [-h|--help]

At-rest tree renderer for orchestrator:where (M029 / FR-5).

Read-only (CON-1 / FR-14). No GitHub API (CON-4 / FR-11). AD-1 single-resolve.

Options:
  --milestone <M###>   Render only the named milestone.
  --expand-all         Expand every milestone's full phase tree.
  --feature <slug>     Override the active feature (testing).
  --no-cost            Suppress per-row cost column (operator override).
  --root <path>        Override the .orchestrator/ root (fixturing).
  -h, --help           Show this message.
EOF
}

_RP_FILTER_MILESTONE=""
_RP_EXPAND_ALL=0
_RP_FEATURE_SLUG=""
_RP_NO_COST=0
_RP_ROOT_OVERRIDE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --milestone) shift; _RP_FILTER_MILESTONE="${1:-}"; shift || true ;;
        --milestone=*) _RP_FILTER_MILESTONE="${1#--milestone=}"; shift ;;
        --expand-all) _RP_EXPAND_ALL=1; shift ;;
        --feature) shift; _RP_FEATURE_SLUG="${1:-}"; shift || true ;;
        --feature=*) _RP_FEATURE_SLUG="${1#--feature=}"; shift ;;
        --no-cost) _RP_NO_COST=1; shift ;;
        --root) shift; _RP_ROOT_OVERRIDE="${1:-}"; shift || true ;;
        --root=*) _RP_ROOT_OVERRIDE="${1#--root=}"; shift ;;
        -h|--help) _rp_print_usage; exit 0 ;;
        *)
            printf 'render-position.sh: unknown flag: %s\n' "$1" >&2
            _rp_print_usage >&2
            exit 2
            ;;
    esac
done

# --- Orchestrator root resolution -----------------------------------------

if [ -n "$_RP_ROOT_OVERRIDE" ]; then
    _RP_ORCH_ROOT="$_RP_ROOT_OVERRIDE"
else
    _RP_ORCH_ROOT="$_RP_PROJECT_ROOT/.orchestrator"
fi

# --- Transient capture directory (allowed write site under /tmp) -----------

_RP_TMP="${TMPDIR:-/tmp}/m029-rp.$$"
mkdir -p "$_RP_TMP" 2>/dev/null || true
trap 'rm -rf "$_RP_TMP" 2>/dev/null || true' EXIT

# --- AD-1 single-resolve invocation context --------------------------------
#
# Capture the resolver's three-line env block to a temp file (no $(...) pipe
# in the public surface). Then parse line-by-line via grep -E.

_RP_DIC="$_RP_PROJECT_ROOT/scripts/state/detect-invocation-context.sh"
_RP_RENDERER="plain"
_RP_EXIT_CODE_SCHEME="governance"
_RP_DEFAULT_PROVIDER=""

if [ -x "$_RP_DIC" ]; then
    _RP_DIC_OUT="$_RP_TMP/dic.out"
    bash "$_RP_DIC" >"$_RP_DIC_OUT" 2>/dev/null || true
    if [ -s "$_RP_DIC_OUT" ]; then
        _line="$(grep -E '^renderer=' "$_RP_DIC_OUT" 2>/dev/null || true)"
        [ -n "$_line" ] && _RP_RENDERER="${_line#renderer=}"
        _line="$(grep -E '^exit_code_scheme=' "$_RP_DIC_OUT" 2>/dev/null || true)"
        [ -n "$_line" ] && _RP_EXIT_CODE_SCHEME="${_line#exit_code_scheme=}"
        _line="$(grep -E '^default_provider=' "$_RP_DIC_OUT" 2>/dev/null || true)"
        [ -n "$_line" ] && _RP_DEFAULT_PROVIDER="${_line#default_provider=}"
    fi
fi

# --- Helpers ---------------------------------------------------------------

# Read the value of a YAML scalar field from a frontmatter block. Stops at
# the closing `---` line. Returns empty if the field is absent.
_rp_yaml_scalar() {
    _file="$1"
    _key="$2"
    awk -v k="$_key" '
        BEGIN { in_fm = 0; depth = 0 }
        /^---[[:space:]]*$/ {
            if (in_fm == 0) { in_fm = 1; next }
            else { exit }
        }
        in_fm == 1 {
            if ($0 ~ "^"k":") {
                v = $0
                sub("^"k":[[:space:]]*", "", v)
                gsub(/^"|"$/, "", v)
                print v
                exit
            }
        }
    ' "$_file" 2>/dev/null
}

# Read a YAML inline-list value (e.g. milestones: [M036a, M036b]) into
# space-separated tokens on stdout.
_rp_yaml_inline_list() {
    _file="$1"
    _key="$2"
    awk -v k="$_key" '
        BEGIN { in_fm = 0 }
        /^---[[:space:]]*$/ {
            if (in_fm == 0) { in_fm = 1; next }
            else { exit }
        }
        in_fm == 1 {
            if ($0 ~ "^"k":") {
                v = $0
                sub("^"k":[[:space:]]*", "", v)
                gsub(/^\[|\][[:space:]]*$/, "", v)
                gsub(/,/, " ", v)
                gsub(/"/, "", v)
                print v
                exit
            }
        }
    ' "$_file" 2>/dev/null
}

# Resolve the active feature slug. Returns empty if no spec carries the
# active milestone in its frontmatter.
_rp_resolve_feature_slug() {
    if [ -n "$_RP_FEATURE_SLUG" ]; then
        printf '%s\n' "$_RP_FEATURE_SLUG"
        return 0
    fi
    _active="$1"
    [ -z "$_active" ] && return 0
    _specs_dir="$_RP_PROJECT_ROOT/specs"
    [ -d "$_specs_dir" ] || return 0
    for _spec_dir in "$_specs_dir"/*/; do
        [ -d "$_spec_dir" ] || continue
        _spec="$_spec_dir/spec.md"
        [ -f "$_spec" ] || continue
        _sing="$(_rp_yaml_scalar "$_spec" milestone)"
        _plur="$(_rp_yaml_inline_list "$_spec" milestones)"
        for _m in $_sing $_plur; do
            # Strip annotations like "M036 (split: ...)" -> M036.
            _m="${_m%% *}"
            _m="${_m%(*}"
            if [ "$_m" = "$_active" ]; then
                _slug="$(basename "$_spec_dir")"
                printf '%s\n' "$_slug"
                return 0
            fi
        done
    done
    return 0
}

# Resolve milestone list for a feature slug (singular OR plural per AD-6).
# Emits space-separated milestone IDs on stdout. Stripping any annotation.
_rp_milestones_for_feature() {
    _slug="$1"
    _spec="$_RP_PROJECT_ROOT/specs/$_slug/spec.md"
    [ -f "$_spec" ] || return 0
    _sing="$(_rp_yaml_scalar "$_spec" milestone)"
    _plur="$(_rp_yaml_inline_list "$_spec" milestones)"
    if [ -n "$_sing" ] && [ -n "$_plur" ]; then
        printf 'WARN: feature %s declares both milestone: and milestones: -- preferring plural\n' \
            "$_slug" >&2
        _sing=""
    fi
    _list="$_plur $_sing"
    _out=""
    for _m in $_list; do
        _m="${_m%% *}"
        _m="${_m%(*}"
        case "$_m" in
            M[0-9]*) ;;
            *) continue ;;
        esac
        _out="$_out $_m"
    done
    printf '%s' "${_out# }"
}

# Reverse-lookup advisory: enumerate every milestone EVALUATION.md, read
# feature_ref:, group, and emit a stderr WARN on mismatch with the spec's
# declared set. Render always proceeds from the spec's declaration.
_rp_reverse_lookup_advisory() {
    _slug="$1"
    _declared="$2"
    _milestones_dir="$_RP_ORCH_ROOT/milestones"
    [ -d "$_milestones_dir" ] || return 0
    _discovered=""
    for _md in "$_milestones_dir"/M[0-9]*; do
        [ -d "$_md" ] || continue
        _mid="$(basename "$_md")"
        _eval="$_md/$_mid-EVALUATION.md"
        [ -f "$_eval" ] || continue
        _ref="$(_rp_yaml_scalar "$_eval" feature_ref)"
        if [ "$_ref" = "$_slug" ]; then
            _discovered="$_discovered $_mid"
        fi
    done
    _discovered="${_discovered# }"
    if [ -z "$_discovered" ]; then
        return 0
    fi
    # Sort both lists for set comparison (no order requirement).
    _decl_sorted="$(printf '%s\n' $_declared | sort | tr '\n' ' ')"
    _disc_sorted="$(printf '%s\n' $_discovered | sort | tr '\n' ' ')"
    if [ "$_decl_sorted" != "$_disc_sorted" ]; then
        printf 'WARN: feature %s spec frontmatter declares { %s }; reverse-lookup discovered { %s }; using spec\n' \
            "$_slug" "$_decl_sorted" "$_disc_sorted" >&2
    fi
}

# Read the H1 milestone name from M###-ROADMAP.md or fall back to the ID.
_rp_milestone_name() {
    _mid="$1"
    _roadmap="$_RP_ORCH_ROOT/milestones/$_mid/$_mid-ROADMAP.md"
    if [ -f "$_roadmap" ]; then
        _h1="$(grep -m1 -E '^# ' "$_roadmap" 2>/dev/null || true)"
        if [ -n "$_h1" ]; then
            _h1="${_h1#\# }"
            printf '%s\n' "$_h1"
            return 0
        fi
    fi
    printf '%s\n' "$_mid"
}

# State-derive a phase: ✓ (P##-SUMMARY.md exists), ▶ (tasks dir without
# SUMMARY OR P##-PLAN.md without SUMMARY), ◇ (no plan), ✗ (last verify=fail).
_rp_phase_glyph() {
    _mdir="$1"
    _pid="$2"
    _pdir="$_mdir/phases/$_pid"
    if [ -f "$_pdir/$_pid-SUMMARY.md" ]; then
        printf '✓\n'
        return 0
    fi
    # Failed-state probe: scan execution-log.jsonl for the most-recent
    # verify_result record for this phase. We use a literal grep pattern
    # against the raw JSONL line; sufficient for at-rest rendering.
    _log="$_mdir/execution-log.jsonl"
    if [ -f "$_log" ]; then
        _last_fail="$(grep -F "\"phase\":\"$_pid\"" "$_log" 2>/dev/null \
            | grep -F '"record_type":"verify_result"' \
            | grep -F '"result":"fail"' \
            | tail -n 1 || true)"
        if [ -n "$_last_fail" ]; then
            printf '✗\n'
            return 0
        fi
    fi
    if [ -f "$_pdir/$_pid-PLAN.md" ] || [ -d "$_pdir/tasks" ]; then
        printf '▶\n'
        return 0
    fi
    printf '◇\n'
}

# State-derive a task: ✓ (T##-*-SUMMARY.md exists), ▶ (PLAN without SUMMARY
# AND last task-verify NOT fail), ◇ (no plan), ✗ (last task-verify=fail).
_rp_task_glyph() {
    _plan="$1"
    _summary="${_plan%-PLAN.md}-SUMMARY.md"
    if [ -f "$_summary" ]; then
        printf '✓\n'
        return 0
    fi
    if [ -f "$_plan" ]; then
        printf '▶\n'
        return 0
    fi
    printf '◇\n'
}

# Detect whether a milestone has M019 Tier 1 dispatch_usage records. FR-6
# detection probe: a single grep -m1 -F. Returns 0 (yes) / 1 (no).
_rp_has_m019_tier1() {
    _mdir="$1"
    _log="$_mdir/execution-log.jsonl"
    [ -s "$_log" ] || return 1
    grep -m1 -F '"record_type":"dispatch_usage"' "$_log" >/dev/null 2>&1
}

# Per-row cost column. Invokes metrics-rollup.sh; returns the cost cell or
# empty string if the milestone is pre-M019 OR if the operator passed
# --no-cost. FR-6 / CON-3 silent suppression: never emit a stderr warning
# from this path.
_rp_cost_column() {
    _mid="$1"
    _pid="$2"
    _tid="$3"
    [ "$_RP_NO_COST" -eq 1 ] && return 0
    _mdir="$_RP_ORCH_ROOT/milestones/$_mid"
    if ! _rp_has_m019_tier1 "$_mdir"; then
        return 0
    fi
    _mr="$_RP_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
    [ -x "$_mr" ] || return 0
    _mr_out="$_RP_TMP/mr.$_mid.$_pid.$_tid.out"
    bash "$_mr" --granularity task --milestone "$_mid" --phase "$_pid" --task "$_tid" \
        >"$_mr_out" 2>/dev/null || true
    # Extract the cost cell. metrics-rollup emits a tabular block; we look
    # for the matching task-grain row and pick the estimated_cost_usd-style
    # numeric token (first decimal) for the inline cell.
    _row="$(grep -F "$_tid" "$_mr_out" 2>/dev/null | head -n 1 || true)"
    [ -z "$_row" ] && return 0
    # Pull the first decimal-looking token from the row (cost USD).
    _num="$(printf '%s' "$_row" | grep -oE '[0-9]+\.[0-9]+' | head -n 1 || true)"
    [ -z "$_num" ] && return 0
    printf '  $%s' "$_num"
}

# Progress-bar string for an inactive milestone. Reads summarize-milestone.sh
# for phase_count / phases_complete / intensity and renders the canonical
# `▓░ X% (k/n phases)` tail.
_rp_progress_bar() {
    _mid="$1"
    _sm="$_RP_PROJECT_ROOT/scripts/diagnostics/summarize-milestone.sh"
    [ -x "$_sm" ] || { printf '\n'; return 0; }
    _sm_out="$_RP_TMP/sm.$_mid.out"
    bash "$_sm" --milestone "$_mid" --format=keys >"$_sm_out" 2>/dev/null || true
    _pc=0; _pcmp=0
    _line="$(grep -E '^phase_count=' "$_sm_out" 2>/dev/null || true)"
    [ -n "$_line" ] && _pc="${_line#phase_count=}"
    _line="$(grep -E '^phases_complete=' "$_sm_out" 2>/dev/null || true)"
    [ -n "$_line" ] && _pcmp="${_line#phases_complete=}"
    _pct=0
    if [ "$_pc" -gt 0 ] 2>/dev/null; then
        _pct=$(( _pcmp * 100 / _pc ))
    fi
    printf '▓░ %d%% (%d/%d phases)\n' "$_pct" "$_pcmp" "$_pc"
}

# --- Active milestone resolution ------------------------------------------

_RP_FAM="$_RP_PROJECT_ROOT/scripts/state/find-active-milestone.sh"
_RP_ACTIVE_MILESTONE=""
if [ -x "$_RP_FAM" ]; then
    _RP_FAM_OUT="$(bash "$_RP_FAM" "$_RP_ORCH_ROOT" 2>/dev/null || true)"
    case "$_RP_FAM_OUT" in
        NONE|"") _RP_ACTIVE_MILESTONE="" ;;
        *) _RP_ACTIVE_MILESTONE="${_RP_FAM_OUT%% *}" ;;
    esac
fi

# When --milestone is given, that becomes the focus -- and (for the FR-13
# active-only view) the only milestone we render.
_RP_FOCUS_MILESTONE="$_RP_ACTIVE_MILESTONE"
if [ -n "$_RP_FILTER_MILESTONE" ]; then
    _RP_FOCUS_MILESTONE="$_RP_FILTER_MILESTONE"
fi

# --- Feature resolution ----------------------------------------------------

_RP_FEATURE="$(_rp_resolve_feature_slug "$_RP_FOCUS_MILESTONE")"

# When the operator passed --milestone, treat that as a single-milestone
# active-only view -- we do NOT pull the cross-milestone feature group.
if [ -n "$_RP_FILTER_MILESTONE" ]; then
    _RP_MILESTONES="$_RP_FILTER_MILESTONE"
elif [ -n "$_RP_FEATURE" ]; then
    _RP_MILESTONES="$(_rp_milestones_for_feature "$_RP_FEATURE")"
    _rp_reverse_lookup_advisory "$_RP_FEATURE" "$_RP_MILESTONES"
elif [ -n "$_RP_FOCUS_MILESTONE" ]; then
    _RP_MILESTONES="$_RP_FOCUS_MILESTONE"
else
    _RP_MILESTONES=""
fi

# --- Render ---------------------------------------------------------------

if [ -z "$_RP_MILESTONES" ]; then
    if [ -z "$_RP_FOCUS_MILESTONE" ]; then
        printf 'no active milestone\n'
    else
        printf 'feature <unknown> declares no milestone; nothing to render\n'
    fi
    exit 0
fi

if [ -n "$_RP_FEATURE" ] && [ -z "$_RP_FILTER_MILESTONE" ]; then
    printf 'feature: %s\n' "$_RP_FEATURE"
fi

for _mid in $_RP_MILESTONES; do
    _mname="$(_rp_milestone_name "$_mid")"
    _is_active=0
    if [ "$_mid" = "$_RP_ACTIVE_MILESTONE" ]; then
        _is_active=1
    fi

    # Inactive milestones are collapsed by default (#Q-5).
    _do_expand=0
    if [ "$_is_active" -eq 1 ] || [ "$_RP_EXPAND_ALL" -eq 1 ] || \
       [ -n "$_RP_FILTER_MILESTONE" ]; then
        _do_expand=1
    fi

    # Top-of-milestone glyph: derive from phase rollup. We treat a
    # milestone as ✓ if all phases complete, ▶ if any in-flight, ◇ if no
    # phases yet, ✗ if any phase failed.
    _mglyph="◇"
    _mdir="$_RP_ORCH_ROOT/milestones/$_mid"
    _has_failed=0
    _has_in_flight=0
    _has_complete=0
    _has_pending=0
    _phase_count=0
    if [ -d "$_mdir/phases" ]; then
        for _pdir in "$_mdir"/phases/P*; do
            [ -d "$_pdir" ] || continue
            _phase_count=$(( _phase_count + 1 ))
            _pid="$(basename "$_pdir")"
            _pg="$(_rp_phase_glyph "$_mdir" "$_pid")"
            case "$_pg" in
                ✓) _has_complete=1 ;;
                ▶) _has_in_flight=1 ;;
                ◇) _has_pending=1 ;;
                ✗) _has_failed=1 ;;
            esac
        done
    fi
    if [ "$_has_failed" -eq 1 ]; then
        _mglyph="✗"
    elif [ "$_has_in_flight" -eq 1 ]; then
        _mglyph="▶"
    elif [ "$_phase_count" -gt 0 ] && [ "$_has_pending" -eq 0 ]; then
        _mglyph="✓"
    elif [ "$_phase_count" -gt 0 ]; then
        _mglyph="▶"
    fi

    if [ "$_do_expand" -eq 0 ]; then
        # Collapsed inactive line per AD-6 #Q-5 shape.
        _bar="$(_rp_progress_bar "$_mid")"
        printf '%s %s %s  %s\n' "$_mglyph" "$_mid" "$_mname" "$_bar"
        continue
    fi

    # Expanded: header line + per-phase rows + per-task rows for in-flight.
    _bar="$(_rp_progress_bar "$_mid")"
    printf '%s %s %s  %s\n' "$_mglyph" "$_mid" "$_mname" "$_bar"

    if [ ! -d "$_mdir/phases" ]; then
        continue
    fi
    for _pdir in "$_mdir"/phases/P*; do
        [ -d "$_pdir" ] || continue
        _pid="$(basename "$_pdir")"
        _pg="$(_rp_phase_glyph "$_mdir" "$_pid")"
        # Phase header label: try P##-PLAN.md H1, fall back to phase ID.
        _plabel="$_pid"
        _pplan="$_pdir/$_pid-PLAN.md"
        if [ -f "$_pplan" ]; then
            _h1="$(grep -m1 -E '^# ' "$_pplan" 2>/dev/null || true)"
            if [ -n "$_h1" ]; then
                _plabel="${_h1#\# }"
            fi
        fi
        printf '  %s %s %s\n' "$_pg" "$_pid" "$_plabel"

        # Task rows -- render only for in-flight (▶) phases to keep tree
        # focused on actionable work.
        if [ "$_pg" = "▶" ] && [ -d "$_pdir/tasks" ]; then
            for _tplan in "$_pdir"/tasks/T*-PLAN.md; do
                [ -f "$_tplan" ] || continue
                _tname="$(basename "$_tplan")"
                _tid="${_tname%%-*}"
                _tlabel="${_tname#*-}"
                _tlabel="${_tlabel%-PLAN.md}"
                _tg="$(_rp_task_glyph "$_tplan")"
                _cost="$(_rp_cost_column "$_mid" "$_pid" "$_tid")"
                printf '    %s %s %s%s\n' "$_tg" "$_tid" "$_tlabel" "$_cost"
            done
        fi
    done
done

exit 0
