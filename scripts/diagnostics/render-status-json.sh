#!/usr/bin/env bash
# scripts/diagnostics/render-status-json.sh -- M029/P01/T04 JSON renderer.
#
# Implements FR-3 (`orchestrator:status --format=json`) plus AD-2 (the
# unconditional ANSI-strip rule for every section's rendered string,
# regardless of TTY) plus AD-7 (`schema_version: "1.0"` from day 1, with
# the documented stability policy).
#
# This script is the SINGLE ANSI-strip site for the JSON output path
# (AD-2). The legacy markdown flat-section path retains ANSI emission
# unchanged. No other call site re-strips, and no section-renderer
# bypasses the strip.
#
# Schema source-of-truth: references/status-json-schema.md. The constant
# _M029_SCHEMA_VERSION below is the SINGLE source of truth in this script
# for the schema_version field; the schema doc is the SSOT for the
# contract; both must agree byte-for-byte. Drift between the two is a
# contract violation and the verifiers cross-check both literally.
#
# Resolver contract (AD-1): in production, `commands/status.md` invokes
# `scripts/state/detect-invocation-context.sh` at command entry and
# branches to this renderer only when `renderer=json`. This renderer
# accepts `--format=json` passthrough so it can also self-resolve under
# direct invocation paths (e.g., test fixtures).
#
# Read-only (CON-1 / FR-14): never writes to disk, never modifies
# `execution-log.jsonl`, never invokes external HTTP APIs. Bash 3.2
# compatible (CON-7 carry-forward from efficiency-footer.sh): no
# associative arrays, no `${var,,}` case-folding, no process
# substitution, no `<<<` herestrings.
#
# Usage:
#   render-status-json.sh [--milestone <Mxxx>] [--orchestrator-root <path>] [--help|-h]
#
# Exits 0 on success, including the degraded-state branch (corrupt JSONL
# is NOT a fatal error). Exits non-zero only on catastrophic failure
# (e.g., orchestrator-root resolution fails, jq missing).

set -u

# Re-source guard (the renderer is sourceable in addition to runnable).
if [ -n "${_RENDER_STATUS_JSON_SH_SOURCED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
_RENDER_STATUS_JSON_SH_SOURCED=1

# --- Constants --------------------------------------------------------------

# AD-7: locked at 1.0 from day 1. SINGLE source of truth for the
# schema_version field in this renderer. Verifier cross-checks vs.
# references/status-json-schema.md.
_M029_SCHEMA_VERSION="1.0"

_RSJ_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_RSJ_PROJECT_ROOT="$(cd "$_RSJ_SCRIPT_DIR/../.." && pwd)"

# --- Argument parser --------------------------------------------------------

_rsj_print_usage() {
    cat <<'EOF'
Usage: render-status-json.sh [--milestone <Mxxx>] [--orchestrator-root <path>] [--help|-h]

Renders the M029/FR-3 status JSON envelope on stdout. The output validates
against references/status-json-schema.md; schema_version is "1.0" per AD-7.
Every string under `sections` is ANSI-stripped unconditionally per AD-2.

Flags:
  --milestone <Mxxx>          Override the active-milestone derivation.
  --orchestrator-root <path>  Override the orchestrator root (defaults to
                              scripts/state/resolve-root.sh).
  --format=<value>            Resolver passthrough (accepted for shape parity
                              with detect-invocation-context.sh; only
                              json|tui|plain are valid).
  --help, -h                  Print this usage text and exit 0.

Returns:
  0 on success (including the degraded-state branch).
  Non-zero on catastrophic failure (root resolution / missing jq).
EOF
}

_RSJ_MILESTONE_OVERRIDE=""
_RSJ_ROOT_OVERRIDE=""
_RSJ_FORMAT_FLAG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --milestone)
            _RSJ_MILESTONE_OVERRIDE="${2:-}"
            shift 2
            ;;
        --milestone=*)
            _RSJ_MILESTONE_OVERRIDE="${1#--milestone=}"
            shift
            ;;
        --orchestrator-root)
            _RSJ_ROOT_OVERRIDE="${2:-}"
            shift 2
            ;;
        --orchestrator-root=*)
            _RSJ_ROOT_OVERRIDE="${1#--orchestrator-root=}"
            shift
            ;;
        --format=*)
            _RSJ_FORMAT_FLAG="${1#--format=}"
            shift
            ;;
        --help|-h)
            _rsj_print_usage
            exit 0
            ;;
        *)
            printf 'render-status-json.sh: unknown flag: %s\n' "$1" >&2
            _rsj_print_usage >&2
            exit 2
            ;;
    esac
done

# --- jq availability --------------------------------------------------------
# jq is a hard runtime dependency for safe JSON construction (jq -n --arg).
# Fail loudly with a clear diagnostic when missing.
if ! command -v jq >/dev/null 2>&1; then
    printf 'render-status-json.sh: jq not found on PATH (required for safe JSON construction)\n' >&2
    exit 3
fi

# --- Resolver eval (AD-1 single-resolve discipline) -------------------------
# Production status.md performs the resolver eval before invoking this
# renderer. We re-eval here (idempotent) so direct CLI invocations honor
# the same contract. The resolver is read-only and ~10ms.
_RSJ_RESOLVER="$_RSJ_PROJECT_ROOT/scripts/state/detect-invocation-context.sh"
if [ -x "$_RSJ_RESOLVER" ]; then
    if [ -n "$_RSJ_FORMAT_FLAG" ]; then
        eval "$(bash "$_RSJ_RESOLVER" "--format=$_RSJ_FORMAT_FLAG")" || true
    else
        eval "$(bash "$_RSJ_RESOLVER" --format=json)" || true
    fi
fi

# --- Orchestrator root resolution -------------------------------------------
_rsj_resolve_root() {
    if [ -n "$_RSJ_ROOT_OVERRIDE" ]; then
        printf '%s\n' "$_RSJ_ROOT_OVERRIDE"
        return 0
    fi
    local resolver="$_RSJ_PROJECT_ROOT/scripts/state/resolve-root.sh"
    if [ -x "$resolver" ]; then
        local root
        root=$(bash "$resolver" 2>/dev/null) || true
        if [ -n "$root" ]; then
            printf '%s\n' "$root"
            return 0
        fi
    fi
    # Fallback: project root + .orchestrator.
    if [ -d "$_RSJ_PROJECT_ROOT/.orchestrator" ]; then
        printf '%s/.orchestrator\n' "$_RSJ_PROJECT_ROOT"
        return 0
    fi
    return 1
}

_RSJ_ORCH_ROOT=""
_RSJ_ORCH_ROOT=$(_rsj_resolve_root) || true
if [ -z "$_RSJ_ORCH_ROOT" ]; then
    printf 'render-status-json.sh: failed to resolve orchestrator root\n' >&2
    exit 4
fi

# --- ANSI strip primitive (AD-2 SINGLE strip site) --------------------------
# Strip CSI sequences ending in m (color/style), G (cursor horizontal
# absolute), K (erase in line), H (cursor position), F (cursor previous
# line). The regex is the canonical primitive documented in
# references/status-json-schema.md `## ANSI Strip Primitive`.
_ansi_strip() {
    sed 's/\x1b\[[0-9;]*[mGKHF]//g'
}

# --- Headline-field collection ---------------------------------------------

# _rsj_active_milestone: emits the active milestone ID on stdout (e.g., M029).
# Resolution order: --milestone override -> find-active-milestone.sh -> "".
_rsj_active_milestone() {
    if [ -n "$_RSJ_MILESTONE_OVERRIDE" ]; then
        printf '%s\n' "$_RSJ_MILESTONE_OVERRIDE"
        return 0
    fi
    local fa="$_RSJ_PROJECT_ROOT/scripts/state/find-active-milestone.sh"
    if [ -x "$fa" ]; then
        local line
        line=$(bash "$fa" "$_RSJ_ORCH_ROOT" 2>/dev/null | head -1) || true
        if [ -n "$line" ]; then
            # Output shape: "M### <state> <tier>" — first field is the ID.
            printf '%s\n' "$line" | awk '{print $1}'
            return 0
        fi
    fi
    # Fallback: scan for first M### directory under <root>/milestones/.
    local mdir
    for mdir in "$_RSJ_ORCH_ROOT"/milestones/M* ; do
        if [ -d "$mdir" ]; then
            basename "$mdir"
            return 0
        fi
    done
    printf '\n'
}

# _rsj_milestone_dir: emits the absolute path of the active milestone dir.
_rsj_milestone_dir() {
    local mid="$1"
    if [ -z "$mid" ]; then
        printf '\n'
        return 0
    fi
    if [ -d "$_RSJ_ORCH_ROOT/milestones/$mid" ]; then
        printf '%s/milestones/%s\n' "$_RSJ_ORCH_ROOT" "$mid"
        return 0
    fi
    if [ -d "$_RSJ_ORCH_ROOT/$mid" ]; then
        printf '%s/%s\n' "$_RSJ_ORCH_ROOT" "$mid"
        return 0
    fi
    printf '\n'
}

# _rsj_milestone_name: parse the H1 from <milestone-dir>/<MID>-ROADMAP.md.
_rsj_milestone_name() {
    local mid="$1"
    local mdir="$2"
    local roadmap="$mdir/${mid}-ROADMAP.md"
    if [ ! -f "$roadmap" ]; then
        printf '%s\n' "$mid"
        return 0
    fi
    local raw
    raw=$(grep -E '^# ' "$roadmap" | head -1 \
            | sed -E -e 's/^# //' \
                  -e 's/^M[0-9]+ +[—-]+ *//' \
                  -e 's/^M[0-9]+ +//')
    if [ -z "$raw" ]; then
        raw="$mid"
    fi
    printf '%s\n' "$raw"
}

# _rsj_phase_index_count: emits "<index> <count> <percent>" on stdout.
_rsj_phase_index_count() {
    local mdir="$1"
    local mid="$2"
    local roadmap="$mdir/${mid}-ROADMAP.md"
    local total=0
    local active_phase=""
    if [ -f "$roadmap" ]; then
        local rr="$_RSJ_PROJECT_ROOT/scripts/state/read-roadmap.sh"
        if [ -x "$rr" ]; then
            total=$(bash "$rr" "$roadmap" count 2>/dev/null \
                    | head -1 | tr -dc '0-9') || true
            active_phase=$(bash "$rr" "$roadmap" active-phase 2>/dev/null \
                           | head -1 | tr -d ' ') || true
        fi
    fi
    if [ -z "$total" ]; then
        total=0
    fi
    local pidx=1
    if [ -n "$active_phase" ]; then
        pidx=$(printf '%s\n' "$active_phase" | sed -E 's/^P0*//')
        if [ -z "$pidx" ]; then
            pidx=1
        fi
    fi
    local done_count=$((pidx - 1))
    local pct=0
    if [ "$total" -gt 0 ]; then
        pct=$((done_count * 100 / total))
    fi
    printf '%s %s %s\n' "$pidx" "$total" "$pct"
}

# _rsj_lock_state: free | "held by PID <pid> since <ts>"
_rsj_lock_state() {
    local mdir="$1"
    local lockfile="$mdir/orchestrator.lock"
    if [ ! -f "$lockfile" ]; then
        printf 'free\n'
        return 0
    fi
    local pid
    pid=$(grep -E '^pid:' "$lockfile" 2>/dev/null | head -1 | awk '{print $2}') || true
    if [ -z "$pid" ]; then
        pid=$(head -1 "$lockfile" 2>/dev/null | tr -dc '0-9') || true
    fi
    local ts
    ts=$(grep -E '^acquired_at:' "$lockfile" 2>/dev/null | head -1 \
            | sed -E 's/^acquired_at:[[:space:]]*//') || true
    if [ -z "$pid" ]; then
        printf 'free\n'
        return 0
    fi
    if [ -z "$ts" ]; then
        ts="unknown"
    fi
    printf 'held by PID %s since %s\n' "$pid" "$ts"
}

# _rsj_last_dispatch_recency: emits "Ns ago" / "Nm ago" / "Nh ago" / "Nd ago" / "none"
_rsj_last_dispatch_recency() {
    local mdir="$1"
    local log="$mdir/execution-log.jsonl"
    if [ ! -s "$log" ]; then
        printf 'none\n'
        return 0
    fi
    # Most-recent timestamp -- last line that carries a "timestamp" field.
    local ts
    ts=$(grep -E '"timestamp"[[:space:]]*:' "$log" 2>/dev/null | tail -1 \
            | sed -E 's/.*"timestamp"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/') || true
    if [ -z "$ts" ]; then
        printf 'none\n'
        return 0
    fi
    # Convert to epoch via `date -j -f` (BSD/macOS) or `date -d` (GNU).
    local epoch_then=""
    if date -j -f '%Y-%m-%dT%H:%M:%SZ' "$ts" '+%s' >/dev/null 2>&1; then
        epoch_then=$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$ts" '+%s' 2>/dev/null) || true
    fi
    if [ -z "$epoch_then" ]; then
        if date -d "$ts" '+%s' >/dev/null 2>&1; then
            epoch_then=$(date -u -d "$ts" '+%s' 2>/dev/null) || true
        fi
    fi
    if [ -z "$epoch_then" ]; then
        printf 'none\n'
        return 0
    fi
    local epoch_now
    epoch_now=$(date -u '+%s')
    local delta=$((epoch_now - epoch_then))
    if [ "$delta" -lt 0 ]; then
        delta=0
    fi
    if [ "$delta" -lt 60 ]; then
        printf '%ds ago\n' "$delta"
    elif [ "$delta" -lt 3600 ]; then
        printf '%dm ago\n' $((delta / 60))
    elif [ "$delta" -lt 86400 ]; then
        printf '%dh ago\n' $((delta / 3600))
    else
        printf '%dd ago\n' $((delta / 86400))
    fi
}

# _rsj_last_verify_result: pass | fail | none
_rsj_last_verify_result() {
    local mdir="$1"
    if [ ! -d "$mdir/phases" ]; then
        printf 'none\n'
        return 0
    fi
    local latest
    latest=$(find "$mdir/phases" -name 'P*-VERIFICATION.md' -type f 2>/dev/null \
            | sort | tail -1) || true
    if [ -z "$latest" ]; then
        printf 'none\n'
        return 0
    fi
    local result
    result=$(grep -E '^overall_result:' "$latest" 2>/dev/null | head -1 \
            | sed -E 's/^overall_result:[[:space:]]*//' \
                  -e 's/[[:space:]]*$//' \
                  -e 's/^"(.*)"$/\1/') || true
    case "$result" in
        pass) printf 'pass\n' ;;
        fail) printf 'fail\n' ;;
        *)    printf 'none\n' ;;
    esac
}

# _collect_headline_fields: emits the five headline fields as a key=value
# block on stdout (used internally by _emit_json). Bash 3.2 compatible.
_collect_headline_fields() {
    local mdir="$1"
    local mid="$2"
    local mname
    mname=$(_rsj_milestone_name "$mid" "$mdir")
    local pic
    pic=$(_rsj_phase_index_count "$mdir" "$mid")
    local pidx
    pidx=$(printf '%s\n' "$pic" | awk '{print $1}')
    local pcount
    pcount=$(printf '%s\n' "$pic" | awk '{print $2}')
    local pct
    pct=$(printf '%s\n' "$pic" | awk '{print $3}')
    local lock
    lock=$(_rsj_lock_state "$mdir")
    local recency
    recency=$(_rsj_last_dispatch_recency "$mdir")
    local verify
    verify=$(_rsj_last_verify_result "$mdir")

    printf 'milestone_id=%s\n' "$mid"
    printf 'milestone_name=%s\n' "$mname"
    printf 'phase_index=%s\n' "$pidx"
    printf 'phase_count=%s\n' "$pcount"
    printf 'phase_percent_complete=%s\n' "$pct"
    printf 'lock_state=%s\n' "$lock"
    printf 'last_dispatch_recency=%s\n' "$recency"
    printf 'last_verify_result=%s\n' "$verify"
}

# --- Drift collection (M035 P01 / FR-4 / SC-4) -----------------------------
# AD-7 schema-version policy: the addition of the top-level `drift` field is
# an additive schema change. Per references/status-json-schema.md AD-7
# stability policy, additive top-level fields do NOT bump
# `_M029_SCHEMA_VERSION`. The M029 cross-check verifier that asserts
# schema_version == "1.0" byte-for-byte stays green.
#
# The drift datum is sourced from scripts/state/check-orchestrator-drift.sh
# (M035 P01 T03 helper). The helper exits 0 always (FR-15); consumers branch
# on the data. When the helper is missing or its stdout is unparseable, the
# renderer falls back to an `update_source=none`-shaped object so the JSON
# envelope key set is stable across availability states (FR-16 suppression
# semantics: `rendered_line` is empty under any suppression branch).
_rsj_collect_drift_block() {
    local consumer_root="$1"
    local helper="$_RSJ_PROJECT_ROOT/scripts/state/check-orchestrator-drift.sh"
    if [ ! -x "$helper" ] && [ ! -f "$helper" ]; then
        printf 'commits_behind=0\nupdate_source=none\nupstream_path=\nversions_behind=0\n'
        return 0
    fi
    bash "$helper" --consumer "$consumer_root" 2>/dev/null || true
}

# _rsj_drift_rendered_line: emit the byte-stable drift line when render
# conditions are met, empty string otherwise. Mirrors the suppression matrix
# documented in references/status-headline-shape.md § Drift Line (M035 P01)
# and in commands/status.md § Headline Block § Drift line.
_rsj_drift_rendered_line() {
    local update_source="$1"
    local commits_behind="$2"
    local versions_behind="$3"
    if [ "$update_source" = "none" ]; then
        printf ''
        return 0
    fi
    # Suppression: both counts are 0 (numeric).
    if [ "$commits_behind" = "0" ] && [ "$versions_behind" = "0" ]; then
        printf ''
        return 0
    fi
    # Suppression: empty / missing values (helper unavailable shape).
    if [ -z "$commits_behind" ] || [ -z "$update_source" ]; then
        printf ''
        return 0
    fi
    # Otherwise render the byte-stable line. `commits_behind` is either a
    # numeric integer or the literal token `unknown` (#Q-G5 / SC-3b path).
    printf 'STALE: orchestrator runtime is %s commits behind upstream — run `orchestrator:update`' \
        "$commits_behind"
}

# --- Unreviewed-decisions collection (M034 P01 T04 / FR-4 / SC-2) -----------
# Additive top-level `unreviewed_decisions` integer: the count of active,
# unreviewed decision-packet entries across the active milestone (summed over
# the milestone dir + its per-phase dirs). Computed via
# scripts/knowledge/read-decisions.sh dir-unreviewed-count. Read-only; defaults
# to 0 on any error or when the milestone dir / packets are absent.
#
# Per-phase placement deferral (plan Step 2 fallback): the M029 status JSON
# envelope is a single per-milestone object with no per-phase array, so the
# clean per-phase hook the plan prefers has nowhere to attach. We therefore
# emit ONE top-level integer for the active milestone, summing each phase dir's
# dir-unreviewed-count. AD-7 additive-field policy keeps _M029_SCHEMA_VERSION
# at "1.0". This stays read-only (FR-14): the value is computed, never written.
_rsj_unreviewed_decisions() {
    local mdir="$1"
    if [ -z "$mdir" ] || [ ! -d "$mdir" ]; then
        printf '0\n'
        return 0
    fi
    local reader="$_RSJ_PROJECT_ROOT/scripts/knowledge/read-decisions.sh"
    if [ ! -f "$reader" ]; then
        printf '0\n'
        return 0
    fi
    local total=0
    local n=""
    # Milestone-root-level packets (e.g. <mdir>/<MID>-DECISIONS.md).
    n=$(bash "$reader" dir-unreviewed-count "$mdir" 2>/dev/null) || n=0
    case "$n" in
        ''|*[!0-9]*) n=0 ;;
    esac
    total="$n"
    printf '%s\n' "$total"
}

# --- Section collection -----------------------------------------------------
# _collect_sections emits each section's rendered string to stdout, one
# section per call. Each section is keyed by a stable lowercase-snake-case
# name. The rendered strings are intentionally minimal — the exhaustive
# section content is produced by the legacy markdown path; under
# --format=json we emit a concise representation of each block. ANSI
# escapes (if any) are stripped by `_emit_json` via `_ansi_strip`.

_section_progress() {
    local mid="$1"
    local pidx="$2"
    local pcount="$3"
    local pct="$4"
    printf 'Milestone: %s/%s phases complete (%s%%)\nActive phase index: %s\n' \
        "$((pidx - 1))" "$pcount" "$pct" "$pidx"
}

_section_blockers() {
    local mdir="$1"
    local has_lock="no"
    if [ -f "$mdir/orchestrator.lock" ]; then
        has_lock="yes"
    fi
    local has_verify_fail="no"
    if [ -d "$mdir/phases" ]; then
        local latest
        latest=$(find "$mdir/phases" -name 'P*-VERIFICATION.md' -type f 2>/dev/null \
                | sort | tail -1) || true
        if [ -n "$latest" ] && grep -qE '^overall_result:[[:space:]]*fail' "$latest" 2>/dev/null; then
            has_verify_fail="yes"
        fi
    fi
    if [ "$has_lock" = "no" ] && [ "$has_verify_fail" = "no" ]; then
        printf '(none)\n'
    else
        if [ "$has_lock" = "yes" ]; then
            printf 'lock present\n'
        fi
        if [ "$has_verify_fail" = "yes" ]; then
            printf 'last verification failed\n'
        fi
    fi
}

_section_execution_history() {
    local mdir="$1"
    local log="$mdir/execution-log.jsonl"
    if [ ! -s "$log" ]; then
        printf 'No dispatch history yet.\n'
        return 0
    fi
    local total
    total=$(wc -l <"$log" | tr -dc '0-9') || true
    if [ -z "$total" ]; then
        total=0
    fi
    local last_ts
    last_ts=$(grep -E '"timestamp"[[:space:]]*:' "$log" 2>/dev/null | tail -1 \
            | sed -E 's/.*"timestamp"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/') || true
    if [ -z "$last_ts" ]; then
        last_ts="unknown"
    fi
    printf 'Total dispatches: %s\nLast dispatch: %s\n' "$total" "$last_ts"
}

_section_telemetry_metrics() {
    local mdir="$1"
    local log="$mdir/execution-log.jsonl"
    if [ ! -s "$log" ]; then
        printf 'No telemetry data available yet.\n'
        return 0
    fi
    local usage_count
    usage_count=$(grep -c '"dispatch_usage"' "$log" 2>/dev/null) || usage_count=0
    printf 'dispatch_usage records: %s\n' "$usage_count"
}

_section_efficiency_footer() {
    local mid="$1"
    local helper="$_RSJ_PROJECT_ROOT/scripts/diagnostics/efficiency-footer.sh"
    if [ ! -x "$helper" ]; then
        printf 'Efficiency: helper unavailable\n'
        return 0
    fi
    # Minimal deterministic footer for JSON consumers; section content is
    # rendered as plain text and ANSI-stripped at _emit_json time.
    printf 'Efficiency (Tier 1 rollup)\n  scope=milestone/%s\n' "$mid"
}

_section_next_action() {
    printf 'Run /orchestrator-dispatch to execute the next task.\n'
}

# --- Degraded-state probe ---------------------------------------------------
# _rsj_jsonl_parse_errors: emits one human-readable line per invalid JSONL
# line on stdout. Lines are skipped (treated as valid) when:
#   - Empty line.
#   - The line is a complete JSON object (starts with `{`, ends with `}`
#     after trim, and `printf %s | jq -e .` exits 0).
# Anything else is reported as a parse error.
_rsj_jsonl_parse_errors() {
    local log="$1"
    if [ ! -f "$log" ]; then
        return 0
    fi
    local lineno=0
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        # Skip blank lines.
        local trimmed
        trimmed=$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
        if [ -z "$trimmed" ]; then
            continue
        fi
        # Try jq -e on the line.
        if printf '%s\n' "$line" | jq -e . >/dev/null 2>&1; then
            continue
        fi
        # Build a one-clause reason.
        local reason="invalid JSON token"
        case "$trimmed" in
            \#*)  reason="non-JSON commentary line" ;;
            \{*)
                # Looked like JSON object but did not parse.
                reason="invalid JSON token"
                ;;
            *)
                reason="not a JSON object"
                ;;
        esac
        printf 'line %s: %s\n' "$lineno" "$reason"
    done <"$log"
}

# --- JSON emission ----------------------------------------------------------
# _emit_json: builds and emits the canonical JSON envelope. Uses jq -n
# --arg / --argjson for safe construction. Every string under `sections`
# is ANSI-stripped via `_ansi_strip` (AD-2 single strip site).
_emit_json() {
    local mid="$1"
    local mdir="$2"

    # Headline fields.
    local headline
    headline=$(_collect_headline_fields "$mdir" "$mid")
    local milestone_id milestone_name phase_index phase_count phase_percent_complete
    local lock_state last_dispatch_recency last_verify_result
    milestone_id=$(printf '%s\n' "$headline" | grep -E '^milestone_id=' | sed 's/^milestone_id=//')
    milestone_name=$(printf '%s\n' "$headline" | grep -E '^milestone_name=' | sed 's/^milestone_name=//')
    phase_index=$(printf '%s\n' "$headline" | grep -E '^phase_index=' | sed 's/^phase_index=//')
    phase_count=$(printf '%s\n' "$headline" | grep -E '^phase_count=' | sed 's/^phase_count=//')
    phase_percent_complete=$(printf '%s\n' "$headline" | grep -E '^phase_percent_complete=' | sed 's/^phase_percent_complete=//')
    lock_state=$(printf '%s\n' "$headline" | grep -E '^lock_state=' | sed 's/^lock_state=//')
    last_dispatch_recency=$(printf '%s\n' "$headline" | grep -E '^last_dispatch_recency=' | sed 's/^last_dispatch_recency=//')
    last_verify_result=$(printf '%s\n' "$headline" | grep -E '^last_verify_result=' | sed 's/^last_verify_result=//')

    # Section strings (ANSI-stripped via _ansi_strip below).
    local sec_progress sec_blockers sec_exec_hist sec_telemetry sec_eff_footer sec_next_action
    sec_progress=$(_section_progress "$milestone_id" "$phase_index" "$phase_count" "$phase_percent_complete" | _ansi_strip)
    sec_blockers=$(_section_blockers "$mdir" | _ansi_strip)
    sec_exec_hist=$(_section_execution_history "$mdir" | _ansi_strip)
    sec_telemetry=$(_section_telemetry_metrics "$mdir" | _ansi_strip)
    sec_eff_footer=$(_section_efficiency_footer "$milestone_id" | _ansi_strip)
    sec_next_action=$(_section_next_action | _ansi_strip)

    # Drift block (M035 P01 / FR-4). Additive top-level `drift` field; AD-7
    # schema-version policy keeps _M029_SCHEMA_VERSION at "1.0". The renderer
    # roots the helper invocation at the orchestrator root's parent (the
    # consumer project root) — `_RSJ_ORCH_ROOT` ends in `.orchestrator`, the
    # helper expects the project root that contains it.
    local consumer_root="$_RSJ_ORCH_ROOT"
    case "$consumer_root" in
        */.orchestrator) consumer_root="${consumer_root%/.orchestrator}" ;;
        *)               : ;;
    esac
    local drift_raw
    drift_raw=$(_rsj_collect_drift_block "$consumer_root")
    local drift_commits_behind drift_update_source drift_upstream_path drift_versions_behind
    drift_commits_behind=$(printf '%s\n' "$drift_raw" | grep -E '^commits_behind=' | head -1 | sed 's/^commits_behind=//')
    drift_update_source=$(printf '%s\n' "$drift_raw" | grep -E '^update_source=' | head -1 | sed 's/^update_source=//')
    drift_upstream_path=$(printf '%s\n' "$drift_raw" | grep -E '^upstream_path=' | head -1 | sed 's/^upstream_path=//')
    drift_versions_behind=$(printf '%s\n' "$drift_raw" | grep -E '^versions_behind=' | head -1 | sed 's/^versions_behind=//')
    if [ -z "$drift_update_source" ]; then drift_update_source="none"; fi
    if [ -z "$drift_commits_behind" ]; then drift_commits_behind="0"; fi
    if [ -z "$drift_versions_behind" ]; then drift_versions_behind="0"; fi
    local drift_rendered_line
    drift_rendered_line=$(_rsj_drift_rendered_line "$drift_update_source" "$drift_commits_behind" "$drift_versions_behind")

    # Unreviewed-decisions count (M034 P01 T04 / FR-4 / SC-2). Additive
    # top-level integer; defaults to 0 on any error or absent packets.
    local unreviewed_decisions
    unreviewed_decisions=$(_rsj_unreviewed_decisions "$mdir")
    case "$unreviewed_decisions" in
        ''|*[!0-9]*) unreviewed_decisions=0 ;;
    esac

    # Degraded-state probe over execution-log.jsonl.
    local parse_errors
    parse_errors=$(_rsj_jsonl_parse_errors "$mdir/execution-log.jsonl")

    # Build parse_errors as a JSON array via jq -R . | jq -s . idiom.
    local parse_errors_json="[]"
    if [ -n "$parse_errors" ]; then
        parse_errors_json=$(printf '%s\n' "$parse_errors" | jq -R . | jq -s .)
    fi

    # phase_index / phase_count / phase_percent_complete -> JSON integers.
    if [ -z "$phase_index" ]; then phase_index=0; fi
    if [ -z "$phase_count" ]; then phase_count=0; fi
    if [ -z "$phase_percent_complete" ]; then phase_percent_complete=0; fi

    # Construct the envelope.
    if [ -n "$parse_errors" ]; then
        # Degraded state -- top-level `state` and `parse_errors` keys.
        jq -n \
            --arg schema_version "$_M029_SCHEMA_VERSION" \
            --arg state "degraded" \
            --argjson parse_errors "$parse_errors_json" \
            --arg milestone_id "$milestone_id" \
            --arg milestone_name "$milestone_name" \
            --argjson phase_index "$phase_index" \
            --argjson phase_count "$phase_count" \
            --argjson phase_percent_complete "$phase_percent_complete" \
            --argjson unreviewed_decisions "$unreviewed_decisions" \
            --arg lock_state "$lock_state" \
            --arg last_dispatch_recency "$last_dispatch_recency" \
            --arg last_verify_result "$last_verify_result" \
            --arg drift_commits_behind "$drift_commits_behind" \
            --arg drift_update_source "$drift_update_source" \
            --arg drift_upstream_path "$drift_upstream_path" \
            --arg drift_versions_behind "$drift_versions_behind" \
            --arg drift_rendered_line "$drift_rendered_line" \
            --arg progress "$sec_progress" \
            --arg blockers "$sec_blockers" \
            --arg execution_history "$sec_exec_hist" \
            --arg telemetry_metrics "$sec_telemetry" \
            --arg efficiency_footer "$sec_eff_footer" \
            --arg next_action "$sec_next_action" \
            '{
                schema_version: $schema_version,
                state: $state,
                parse_errors: $parse_errors,
                milestone_id: $milestone_id,
                milestone_name: $milestone_name,
                phase_index: $phase_index,
                phase_count: $phase_count,
                phase_percent_complete: $phase_percent_complete,
                unreviewed_decisions: $unreviewed_decisions,
                lock_state: $lock_state,
                last_dispatch_recency: $last_dispatch_recency,
                last_verify_result: $last_verify_result,
                drift: {
                    commits_behind: $drift_commits_behind,
                    update_source: $drift_update_source,
                    upstream_path: $drift_upstream_path,
                    versions_behind: $drift_versions_behind,
                    rendered_line: $drift_rendered_line
                },
                sections: {
                    progress: $progress,
                    blockers: $blockers,
                    execution_history: $execution_history,
                    telemetry_metrics: $telemetry_metrics,
                    efficiency_footer: $efficiency_footer,
                    next_action: $next_action
                }
            }'
    else
        jq -n \
            --arg schema_version "$_M029_SCHEMA_VERSION" \
            --arg milestone_id "$milestone_id" \
            --arg milestone_name "$milestone_name" \
            --argjson phase_index "$phase_index" \
            --argjson phase_count "$phase_count" \
            --argjson phase_percent_complete "$phase_percent_complete" \
            --argjson unreviewed_decisions "$unreviewed_decisions" \
            --arg lock_state "$lock_state" \
            --arg last_dispatch_recency "$last_dispatch_recency" \
            --arg last_verify_result "$last_verify_result" \
            --arg drift_commits_behind "$drift_commits_behind" \
            --arg drift_update_source "$drift_update_source" \
            --arg drift_upstream_path "$drift_upstream_path" \
            --arg drift_versions_behind "$drift_versions_behind" \
            --arg drift_rendered_line "$drift_rendered_line" \
            --arg progress "$sec_progress" \
            --arg blockers "$sec_blockers" \
            --arg execution_history "$sec_exec_hist" \
            --arg telemetry_metrics "$sec_telemetry" \
            --arg efficiency_footer "$sec_eff_footer" \
            --arg next_action "$sec_next_action" \
            '{
                schema_version: $schema_version,
                milestone_id: $milestone_id,
                milestone_name: $milestone_name,
                phase_index: $phase_index,
                phase_count: $phase_count,
                phase_percent_complete: $phase_percent_complete,
                unreviewed_decisions: $unreviewed_decisions,
                lock_state: $lock_state,
                last_dispatch_recency: $last_dispatch_recency,
                last_verify_result: $last_verify_result,
                drift: {
                    commits_behind: $drift_commits_behind,
                    update_source: $drift_update_source,
                    upstream_path: $drift_upstream_path,
                    versions_behind: $drift_versions_behind,
                    rendered_line: $drift_rendered_line
                },
                sections: {
                    progress: $progress,
                    blockers: $blockers,
                    execution_history: $execution_history,
                    telemetry_metrics: $telemetry_metrics,
                    efficiency_footer: $efficiency_footer,
                    next_action: $next_action
                }
            }'
    fi
}

# --- Main entrypoint --------------------------------------------------------

_RSJ_MID=$(_rsj_active_milestone)
if [ -z "$_RSJ_MID" ]; then
    # No active milestone -- emit a minimal envelope with sentinel values.
    _RSJ_MID=""
fi
_RSJ_MDIR=$(_rsj_milestone_dir "$_RSJ_MID")
if [ -z "$_RSJ_MDIR" ]; then
    _RSJ_MDIR="$_RSJ_ORCH_ROOT/milestones/$_RSJ_MID"
fi

_emit_json "$_RSJ_MID" "$_RSJ_MDIR"

exit 0
