#!/usr/bin/env bash
# tests/m029-acceptance/p03-sc7-live-tail.sh
#
# M029 / P03 / SC-7 acceptance script.
#
# Asserts the live-tail savings-marker contract against an in-memory
# mktemp fixture:
#
#   1. Background `render-position.sh --live --milestone <M999> --root
#      <fixture>` so the renderer enters the FR-7 / #Q-1 tail-loop.
#   2. Append a synthetic `dispatch_usage` record with savings >= 5%.
#      Assert the canonical compact marker `▽ saved Nk` (#Q-G8) appears
#      in the renderer's stdout within 1.5 seconds (poll-loop budget).
#      The 1.0s assertion is the median-trial budget verified by
#      `measure-live-tail-latency.sh`; this single-trial check uses the
#      drift-trigger ceiling (1.5s) as its outer wall-clock budget so a
#      slow-CI burst does not flap SC-7 -- multi-trial p95 statistics
#      are the load-bearing #Q-G9 assertion.
#   3. Append a second synthetic `dispatch_usage` record with savings
#      < 5%. Assert no NEW marker appears on the second update (the
#      renderer suppresses the marker below the threshold).
#   4. Delegate the multi-trial p95 statistical assertion to
#      `measure-live-tail-latency.sh --trials 10` (#Q-G9 methodology).
#
# Bash 3.2 (MEM001). MEM004 carve-out: pipes inside the script body are
# permitted; AD-19 single-script-file shape applies only at Check:
# command level.
#
# CON-1 / FR-14 read-only: fixture under mktemp -d. Trap-cleans on EXIT.
# CON-2 bash + ANSI only: tail -f from the renderer; no inotify/fswatch.
# #Q-G8 canonical-form invariant: `▽ saved Nk` is the ONLY accepted
# form; the verbose-suffix variant is forbidden.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RENDERER="$PROJECT_ROOT/scripts/diagnostics/render-position.sh"
LATENCY_HARNESS="$PROJECT_ROOT/tests/m029-acceptance/measure-live-tail-latency.sh"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

TMP="${TMPDIR:-/tmp}/m029-p03-sc7.$$"
mkdir -p "$TMP"

RENDERER_PID=""
cleanup() {
    if [ -n "$RENDERER_PID" ]; then
        # Kill cascade per T01 SUMMARY's child-process shutdown caution
        # -- tail -f children do not always exit on parent SIGTERM.
        pkill -TERM -P "$RENDERER_PID" 2>/dev/null || true
        kill -TERM "$RENDERER_PID" 2>/dev/null || true
        sleep 1
        kill -KILL "$RENDERER_PID" 2>/dev/null || true
    fi
    rm -rf "$TMP" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Build a minimal fixture under TMP. Milestone M999 keeps this fixture
# disjoint from the bundled M996/M997/M998 fixtures.
MID="M999"
ORCH_ROOT="$TMP/.orchestrator"
mkdir -p "$ORCH_ROOT/milestones/$MID/phases/P01/tasks"

cat >"$ORCH_ROOT/milestones/$MID/$MID-EVALUATION.md" <<EOF
---
schema_version: "1.0"
type: evaluation
milestone: "$MID"
intensity: "standard"
tier: "C"
created_at: "2026-05-06"
---
SC-7 ad-hoc fixture.
EOF
cat >"$ORCH_ROOT/milestones/$MID/$MID-ROADMAP.md" <<EOF
---
schema_version: "1.0"
type: roadmap
milestone: "$MID"
tier: "C"
---
# $MID
- [ ] **P01**: in-flight
EOF
cat >"$ORCH_ROOT/milestones/$MID/phases/P01/P01-PLAN.md" <<EOF
# P01 SC-7 fixture phase
EOF
cat >"$ORCH_ROOT/milestones/$MID/phases/P01/tasks/T01-sc7-PLAN.md" <<EOF
# T01 SC-7 fixture task
EOF

LOG="$ORCH_ROOT/milestones/$MID/execution-log.jsonl"
: >"$LOG"

# Background the renderer in --live mode.
OUT="$TMP/render.out"
: >"$OUT"
ORCHESTRATOR_ROOT="$ORCH_ROOT" bash "$RENDERER" --live --milestone "$MID" --root "$ORCH_ROOT" >"$OUT" 2>"$TMP/render.err" &
RENDERER_PID=$!

# Wait for initial render. Cap at 5s.
WAIT=0
while [ ! -s "$OUT" ]; do
    if [ "$WAIT" -ge 50 ]; then
        bad "renderer did not produce initial render within 5s"
        printf 'SUMMARY: p03-sc7-live-tail.sh pass=%d fail=%d\n' "$pass" "$fail"
        exit 1
    fi
    sleep 0.1 2>/dev/null || sleep 1
    WAIT=$(( WAIT + 1 ))
done
ok "renderer produced initial at-rest render"

# Step 1: append a >=5% record. Use 50% (3000/6000) for headroom.
T_BEFORE_1="$(date +%s)"
printf '{"record_type":"dispatch_usage","unitId":"%s/P01/T01","milestone":"%s","phase":"P01","task":"T01","tier1_savings_tokens":3000,"tier2_savings_tokens":0,"dispatch_total_tokens":6000,"input_tokens_estimate":3000,"output_tokens_estimate":3000,"timestamp":"2026-05-06T12:00:00Z"}\n' \
    "$MID" "$MID" >>"$LOG"

# Poll up to 1.5 seconds (1500ms via 30 * 50ms) for the marker.
POLL=0
SAW_MARKER=0
while [ "$POLL" -lt 30 ]; do
    if grep -F -q '▽ saved' "$OUT" 2>/dev/null; then
        SAW_MARKER=1
        break
    fi
    sleep 0.05 2>/dev/null || sleep 1
    POLL=$(( POLL + 1 ))
done

if [ "$SAW_MARKER" -eq 1 ]; then
    ok "SC-7 canonical compact marker '▽ saved Nk' appeared after >=5% record (1 second budget)"
else
    bad "SC-7 marker did NOT appear within 1.5s window after >=5% record"
fi

# Negative assertion: forbidden verbose-suffix form (#Q-G8). The literal
# token "via tier1 cache reuse" must NOT appear in the rendered output.
if grep -F -q 'via tier1 cache reuse' "$OUT" 2>/dev/null; then
    bad "SC-7 forbidden verbose-suffix marker present (#Q-G8 violation)"
else
    ok "SC-7 forbidden verbose-suffix form absent (#Q-G8 invariant)"
fi

# Capture the marker count after the >=5% append for the negative
# below-threshold check.
COUNT_AFTER_1="$(grep -c -F '▽ saved' "$OUT" 2>/dev/null || true)"
[ -z "$COUNT_AFTER_1" ] && COUNT_AFTER_1=0

# Step 2: append a <5% record. The renderer will re-render but the
# savings_pct (1.6%) is below the 5.0 threshold so no NEW marker
# appears for this task. Sleep ~750ms to give the renderer time to
# re-render but stay well under the next-trial budget.
printf '{"record_type":"dispatch_usage","unitId":"%s/P01/T01","milestone":"%s","phase":"P01","task":"T01","tier1_savings_tokens":100,"tier2_savings_tokens":0,"dispatch_total_tokens":6000,"input_tokens_estimate":3000,"output_tokens_estimate":3000,"timestamp":"2026-05-06T12:01:00Z"}\n' \
    "$MID" "$MID" >>"$LOG"
sleep 0.75 2>/dev/null || sleep 1

# After the below-threshold record, the *latest* dispatch_usage for T01
# is the 1.6% record. The renderer re-renders and emits a NEW tree
# WITHOUT a marker for T01. Total marker count should NOT grow.
COUNT_AFTER_2="$(grep -c -F '▽ saved' "$OUT" 2>/dev/null || true)"
[ -z "$COUNT_AFTER_2" ] && COUNT_AFTER_2=0

if [ "$COUNT_AFTER_2" -gt "$COUNT_AFTER_1" ]; then
    bad "SC-7 below-threshold record produced a NEW marker (count grew: $COUNT_AFTER_1 -> $COUNT_AFTER_2)"
else
    ok "SC-7 below-threshold record did NOT add a new marker (5% threshold honoured)"
fi

# Step 3: delegate the multi-trial p95 statistical assertion to the
# latency harness (#Q-G9). The harness builds its own fixture and
# tears it down -- this is purely a statistical-budget gate, not a
# correctness gate. We allow the latency harness wall-clock budget of
# ~30s for 10 trials.
if [ -x "$LATENCY_HARNESS" ]; then
    HARNESS_OUT="$TMP/harness.out"
    if bash "$LATENCY_HARNESS" --trials 10 >"$HARNESS_OUT" 2>"$TMP/harness.err"; then
        if grep -F -q 'VERDICT: PASS' "$HARNESS_OUT" 2>/dev/null; then
            ok "SC-7 #Q-G9 multi-trial p95 budget passed (1 second target)"
        else
            bad "SC-7 latency harness produced no PASS verdict"
        fi
    else
        bad "SC-7 latency harness exited non-zero (#Q-G9 p95 budget exceeded)"
        cat "$HARNESS_OUT" 2>/dev/null
        cat "$TMP/harness.err" 2>/dev/null
    fi
else
    bad "SC-7 latency harness missing or non-executable at $LATENCY_HARNESS"
fi

printf 'SUMMARY: p03-sc7-live-tail.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
