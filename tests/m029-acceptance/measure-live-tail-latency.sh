#!/usr/bin/env bash
# tests/m029-acceptance/measure-live-tail-latency.sh
#
# M029 / P03 / T04 / #Q-G9 -- live-tail latency measurement harness.
#
# Methodology: N trials of (append synthetic dispatch_usage record ->
# wait for `▽ saved Nk` marker on rendered output -> measure latency).
# Reports p50/p95/p99 in milliseconds. Asserts p95 <= 1.0s (1000ms).
# Emits p99 informationally. No per-measurement retry. On drift trigger
# (p95 > 1.5s = 1500ms) emits a `RISK:` callout to stderr for human
# review (escalation per #Q-G9 -- does NOT change verdict).
#
# Bash 3.2 (MEM001): parallel scalars, no associative arrays, no
# herestring, no process substitution. MEM004 carve-out: pipes inside
# the script body are permitted; AD-19 verifier-shape rules apply only
# to Check: command level.
#
# CON-1 / FR-14 read-only: fixture lives under mktemp -d. Sole allowed
# write site is /tmp/m029-p03-mlt-latency.$$/ (per run-probe.sh scope
# rule 4).
#
# CON-2 bash + ANSI only: tail -f is the renderer's primitive (POSIX);
# no inotify, no fswatch, no Python except as last-resort nanosecond
# clock shim.
#
# Three-tier nanosecond-clock shim:
#   1. `date +%s%N` (Linux GNU coreutils).
#   2. `gdate +%s%N` (macOS coreutils via brew).
#   3. `python3 -c 'import time; print(int(time.monotonic()*1e9))'`.
# When all three fail, fall back to millisecond resolution via
# `date +%s` * 1000 (acknowledged in the latency assertion).
#
# Output shape (stdout):
#   measure-live-tail-latency.sh: trials=N
#   p50=NN ms
#   p95=NN ms
#   p99=NN ms
#   VERDICT: PASS|FAIL
#   SUMMARY: measure-live-tail-latency.sh pass=1 fail=0|0 fail=1
#
# Exit 0 iff p95 <= 1000ms.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RENDERER="$PROJECT_ROOT/scripts/diagnostics/render-position.sh"

TRIALS=10
FIXTURE_MID="M998"
FIXTURE_DIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --trials) shift; TRIALS="${1:-10}"; shift ;;
        --trials=*) TRIALS="${1#--trials=}"; shift ;;
        --fixture-dir) shift; FIXTURE_DIR="${1:-}"; shift ;;
        --fixture-dir=*) FIXTURE_DIR="${1#--fixture-dir=}"; shift ;;
        --milestone) shift; FIXTURE_MID="${1:-M998}"; shift ;;
        --milestone=*) FIXTURE_MID="${1#--milestone=}"; shift ;;
        -h|--help)
            printf 'Usage: measure-live-tail-latency.sh [--trials N] [--fixture-dir <path>] [--milestone <M###>]\n'
            exit 0
            ;;
        *) shift ;;
    esac
done

# Three-tier nanosecond-clock shim. Returns nanoseconds on stdout.
# Tier 4 fallback returns ms*1e6 (millisecond resolution dressed in ns
# units). Detected once at startup; one of the four scalars is set.
CLOCK_KIND=""
_probe_now_date_pct_n() {
    _v="$(date +%s%N 2>/dev/null || true)"
    case "$_v" in
        *N) return 1 ;;
        '') return 1 ;;
        *) printf '%s' "$_v"; return 0 ;;
    esac
}
_probe_now_gdate_pct_n() {
    _v="$(gdate +%s%N 2>/dev/null || true)"
    case "$_v" in
        *N) return 1 ;;
        '') return 1 ;;
        *) printf '%s' "$_v"; return 0 ;;
    esac
}
_probe_now_python3() {
    if command -v python3 >/dev/null 2>&1; then
        _v="$(python3 -c 'import time; print(int(time.monotonic()*1e9))' 2>/dev/null || true)"
        if [ -n "$_v" ]; then
            printf '%s' "$_v"
            return 0
        fi
    fi
    return 1
}
_probe_now_date_seconds() {
    # Last-resort millisecond resolution dressed in ns units (* 1e6).
    _s="$(date +%s 2>/dev/null || true)"
    [ -z "$_s" ] && return 1
    printf '%s000000000' "$_s"
    return 0
}

# Detect clock at startup.
if _probe_now_date_pct_n >/dev/null 2>&1; then
    CLOCK_KIND="date_pct_n"
elif _probe_now_gdate_pct_n >/dev/null 2>&1; then
    CLOCK_KIND="gdate_pct_n"
elif _probe_now_python3 >/dev/null 2>&1; then
    CLOCK_KIND="python3"
else
    CLOCK_KIND="date_seconds"
fi

now_ns() {
    case "$CLOCK_KIND" in
        date_pct_n) _probe_now_date_pct_n ;;
        gdate_pct_n) _probe_now_gdate_pct_n ;;
        python3) _probe_now_python3 ;;
        date_seconds) _probe_now_date_seconds ;;
    esac
}

# --- Fixture setup --------------------------------------------------------

TMP="${TMPDIR:-/tmp}/m029-p03-mlt-latency.$$"
mkdir -p "$TMP"

cleanup() {
    if [ -n "${RENDERER_PID:-}" ]; then
        # Kill cascade per T01 SUMMARY's child-process shutdown caution.
        pkill -TERM -P "$RENDERER_PID" 2>/dev/null || true
        kill -TERM "$RENDERER_PID" 2>/dev/null || true
        sleep 1
        kill -KILL "$RENDERER_PID" 2>/dev/null || true
    fi
    rm -rf "$TMP" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# If --fixture-dir was not supplied, build a minimal in-tree fixture.
if [ -z "$FIXTURE_DIR" ]; then
    FIXTURE_DIR="$TMP/fixture"
    mkdir -p "$FIXTURE_DIR/.orchestrator/milestones/$FIXTURE_MID/phases/P01/tasks"
    cat >"$FIXTURE_DIR/.orchestrator/milestones/$FIXTURE_MID/$FIXTURE_MID-EVALUATION.md" <<EOF
---
schema_version: "1.0"
type: evaluation
milestone: "$FIXTURE_MID"
intensity: "standard"
tier: "C"
created_at: "2026-05-06"
---
synthetic mlt-latency fixture
EOF
    cat >"$FIXTURE_DIR/.orchestrator/milestones/$FIXTURE_MID/$FIXTURE_MID-ROADMAP.md" <<EOF
---
schema_version: "1.0"
type: roadmap
milestone: "$FIXTURE_MID"
tier: "C"
---
- [ ] **P01**: in-flight
EOF
    cat >"$FIXTURE_DIR/.orchestrator/milestones/$FIXTURE_MID/phases/P01/P01-PLAN.md" <<EOF
# P01 mlt-latency fixture phase
EOF
    cat >"$FIXTURE_DIR/.orchestrator/milestones/$FIXTURE_MID/phases/P01/tasks/T01-mlt-PLAN.md" <<EOF
# T01 mlt-latency fixture task
EOF
    : >"$FIXTURE_DIR/.orchestrator/milestones/$FIXTURE_MID/execution-log.jsonl"
fi

LOG="$FIXTURE_DIR/.orchestrator/milestones/$FIXTURE_MID/execution-log.jsonl"
ORCH_ROOT="$FIXTURE_DIR/.orchestrator"

# Background the renderer in --live mode against the fixture. Stdout
# captured to a temp file we'll poll for the marker.
OUT="$TMP/render.out"
: >"$OUT"
ORCHESTRATOR_ROOT="$ORCH_ROOT" bash "$RENDERER" --live --milestone "$FIXTURE_MID" --root "$ORCH_ROOT" >"$OUT" 2>/dev/null &
RENDERER_PID=$!

# Wait for the initial render so the polling loop measures the
# *re*-render latency, not the first-paint latency.
WAIT=0
while [ ! -s "$OUT" ]; do
    if [ "$WAIT" -ge 50 ]; then
        printf 'ERROR: renderer did not produce initial render within 5s\n' 1>&2
        exit 1
    fi
    sleep 0.1 2>/dev/null || sleep 1
    WAIT=$(( WAIT + 1 ))
done

# Trial loop. For each trial:
#   1. Compute t_append_ns
#   2. Append a synthetic dispatch_usage record with savings >= threshold
#      (5% default). Use 50% (3000/6000) for headroom.
#   3. Poll OUT for new "▽ saved" marker presence (count grows by 1).
#   4. Compute t_render_ns at first new occurrence; record latency_ms.
#
# The previous "▽ saved" count is tracked so we measure each render's
# additional marker emission, not cumulative file content.

LATENCIES_FILE="$TMP/latencies.txt"
: >"$LATENCIES_FILE"

count_marker() {
    # grep -c emits a number to stdout AND exits non-zero when the
    # count is 0. We redirect stderr away and tolerate the non-zero
    # exit; if the file does not exist yet we emit "0".
    if [ ! -f "$OUT" ]; then
        printf '0'
        return 0
    fi
    _c="$(grep -c -F '▽ saved' "$OUT" 2>/dev/null || true)"
    if [ -z "$_c" ]; then
        printf '0'
    else
        printf '%s' "$_c"
    fi
}

PREV_COUNT="$(count_marker)"
TRIAL=1
while [ "$TRIAL" -le "$TRIALS" ]; do
    T_APPEND="$(now_ns)"
    # Task id is the bare T## prefix because the renderer's task_glyph
    # parses `T##-...-PLAN.md` and strips at the first `-`. The task
    # PLAN file we seed below is `T01-mlt-PLAN.md` -> tid is `T01`.
    # Vary the savings amount per trial so each appended record's
    # marker output (`▽ saved Nk`) is textually distinct from the prior
    # render's marker; the count-based delta detector works either way
    # but distinct markers also stress-test the awk extraction.
    TID="T01"
    SAVINGS=$(( 3000 + TRIAL * 1000 ))
    TOTAL=$(( SAVINGS * 2 ))
    printf '{"record_type":"dispatch_usage","unitId":"%s/P01/%s","milestone":"%s","phase":"P01","task":"%s","tier1_savings_tokens":%d,"tier2_savings_tokens":0,"dispatch_total_tokens":%d,"input_tokens_estimate":%d,"output_tokens_estimate":%d,"timestamp":"2026-05-06T12:0%d:00Z"}\n' \
        "$FIXTURE_MID" "$TID" "$FIXTURE_MID" "$TID" "$SAVINGS" "$TOTAL" "$SAVINGS" "$SAVINGS" "$TRIAL" >>"$LOG"

    # Poll for the new marker. Bail at 1500ms (the drift-trigger ceiling)
    # so a runaway trial does not hang the whole battery.
    POLL=0
    LATENCY_MS=-1
    while [ "$POLL" -lt 30 ]; do
        CUR="$(count_marker)"
        if [ "$CUR" -gt "$PREV_COUNT" ]; then
            T_RENDER="$(now_ns)"
            # latency_ms = (t_render - t_append) / 1e6 via awk integer
            # arithmetic. T_APPEND/T_RENDER may be 19-digit ns -- well
            # above bash 32-bit int range -- so awk handles them.
            LATENCY_MS="$(printf '%s %s\n' "$T_RENDER" "$T_APPEND" \
                | awk '{ printf "%d", ($1 - $2) / 1000000 }')"
            PREV_COUNT="$CUR"
            break
        fi
        sleep 0.05 2>/dev/null || sleep 1
        POLL=$(( POLL + 1 ))
    done
    if [ "$LATENCY_MS" = "-1" ]; then
        # Didn't observe a new marker within 1.5s -- record 1500ms as
        # the trial's effective latency. This biases p95/p99 toward
        # FAIL when the renderer is hung, which is the right semantics.
        LATENCY_MS=1500
    fi
    printf '%s\n' "$LATENCY_MS" >>"$LATENCIES_FILE"
    TRIAL=$(( TRIAL + 1 ))
done

# Sort + index pick for percentile computation. ceil(N * pct / 100).
SORTED="$TMP/sorted.txt"
sort -n "$LATENCIES_FILE" >"$SORTED"

# 1-indexed percentile picks.
P50_IDX="$(printf '%s\n' "$TRIALS" | awk '{ printf "%d", ($1 * 50 + 99) / 100 }')"
P95_IDX="$(printf '%s\n' "$TRIALS" | awk '{ printf "%d", ($1 * 95 + 99) / 100 }')"
P99_IDX="$(printf '%s\n' "$TRIALS" | awk '{ printf "%d", ($1 * 99 + 99) / 100 }')"

# Clamp to [1, TRIALS].
[ "$P50_IDX" -lt 1 ] && P50_IDX=1
[ "$P95_IDX" -lt 1 ] && P95_IDX=1
[ "$P99_IDX" -lt 1 ] && P99_IDX=1
[ "$P50_IDX" -gt "$TRIALS" ] && P50_IDX="$TRIALS"
[ "$P95_IDX" -gt "$TRIALS" ] && P95_IDX="$TRIALS"
[ "$P99_IDX" -gt "$TRIALS" ] && P99_IDX="$TRIALS"

P50="$(awk -v i="$P50_IDX" 'NR == i { print; exit }' "$SORTED")"
P95="$(awk -v i="$P95_IDX" 'NR == i { print; exit }' "$SORTED")"
P99="$(awk -v i="$P99_IDX" 'NR == i { print; exit }' "$SORTED")"

# Default to 0 if percentile pick failed.
[ -z "$P50" ] && P50=0
[ -z "$P95" ] && P95=0
[ -z "$P99" ] && P99=0

printf 'measure-live-tail-latency.sh: trials=%d\n' "$TRIALS"
printf 'p50=%d ms\n' "$P50"
printf 'p95=%d ms\n' "$P95"
printf 'p99=%d ms\n' "$P99"

# Drift trigger -- p95 > 1.5s emits a RISK callout to stderr (does not
# change verdict).
if [ "$P95" -gt 1500 ]; then
    printf 'RISK: p95 latency drift to %dms exceeds 1.5s tightening trigger\n' "$P95" 1>&2
fi

# Verdict: p95 <= 1.0s = 1000ms.
if [ "$P95" -le 1000 ]; then
    printf 'VERDICT: PASS\n'
    printf 'SUMMARY: measure-live-tail-latency.sh pass=1 fail=0\n'
    exit 0
fi
printf 'VERDICT: FAIL\n'
printf 'SUMMARY: measure-live-tail-latency.sh pass=0 fail=1\n'
exit 1
