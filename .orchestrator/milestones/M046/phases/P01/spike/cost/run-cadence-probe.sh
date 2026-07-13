#!/usr/bin/env bash
# run-cadence-probe.sh — M046/P01/T02 #Q-4 cost-read cadence probe.
# Spike-grade / throwaway.
#
# Measures WHEN cost-bearing records become readable from the M019 Tier-1
# JSONL relative to (a) unit boundaries and (b) segment (loop-process)
# boundaries — with ZERO LLM spend. The claude -p --output-format json
# total_cost_usd half of #Q-4 is answered by citation to
# .orchestrator/proposals/M-auto-v2b-P00-spike-evidence.md, never re-measured.
#
# Full run (default):
#   1. Reset the throwaway MFIX fixture (scratch state root under ./fixture/).
#   2. Append a loop_start mark to cadence.jsonl.
#   3. Launch drive-segment.sh (the stub-dispatch auto-loop segment) in the
#      background.
#   4. Poll the fixture's execution-log.jsonl every 0.2 s; on each new line,
#      append a timestamped jsonl_append event to cadence.jsonl:
#        {"t":"<epoch.ms>","event":"jsonl_append","record_type":"<type>",
#         "unit":"<unitId>","cost_present":true|false}
#      cost_present = the line carries a non-null cost value
#      (numeric estimated_cost_usd, or a cost_estimated key).
#   5. On segment exit, append {"t":...,"event":"loop_exit","code":N}, drain
#      any lines observed only after exit-detection (conservatively AFTER the
#      loop_exit mark), then append per-unit_close analysis events
#      (readable_before_loop_exit, observe_lag_s) and a probe_summary event.
#   6. Run the same assertions as --verify-only.
#
# --verify-only: re-check the captured cadence.jsonl without re-running the
#   loop. Asserts: >=3 jsonl_append events with record_type=unit_close, each
#   carrying a cost_present field; >=1 loop_exit mark; >=3 of those unit_close
#   observations timestamped BEFORE the loop_exit mark. Exit 0 when all hold.
#
# AD-19: background-launch + poll logic lives INSIDE this script; no
# command substitutions containing pipes; no >2-element compound chains.
set -euo pipefail

SPIKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_ROOT="$SPIKE_DIR/fixture"
MILESTONE_DIR="$FIXTURE_ROOT/milestones/MFIX"
FIX_LOG="$MILESTONE_DIR/execution-log.jsonl"
CADENCE="$SPIKE_DIR/cadence.jsonl"
DRIVE_LOG="$SPIKE_DIR/segment-drive.log"
TMPLINE="$SPIKE_DIR/.poll-line.txt"

MODE="run"
if [ "${1:-}" = "--verify-only" ]; then
  MODE="verify"
fi

# --- epoch timestamp with millisecond precision (perl ships on macOS) ---
_now() {
  perl -MTime::HiRes=time -e 'printf "%.3f", time' 2>/dev/null || date +%s
}

# --- ISO-8601Z -> epoch seconds (for observe-lag vs the record's own ts) ---
_iso_to_epoch() {
  perl -MTime::Piece -e 'my $t=Time::Piece->strptime($ARGV[0],"%Y-%m-%dT%H:%M:%SZ"); print $t->epoch' "$1" 2>/dev/null || echo 0
}

# ---------------------------------------------------------------------------
# Verification assertions (shared by full run and --verify-only)
# ---------------------------------------------------------------------------
verify_cadence() {
  local fails=0
  if [ ! -f "$CADENCE" ]; then
    echo "FAIL: cadence.jsonl missing at $CADENCE"
    return 1
  fi

  local uc_appends
  uc_appends=$(grep -c '"event":"jsonl_append","record_type":"unit_close"' "$CADENCE") || uc_appends=0
  if [ "$uc_appends" -ge 3 ]; then
    echo "PASS: unit_close jsonl_append observations = $uc_appends (>= 3)"
  else
    echo "FAIL: unit_close jsonl_append observations = $uc_appends (< 3)"
    fails=1
  fi

  local uc_with_cp
  uc_with_cp=$(grep -c '"event":"jsonl_append","record_type":"unit_close".*"cost_present":' "$CADENCE") || uc_with_cp=0
  if [ "$uc_with_cp" -eq "$uc_appends" ]; then
    echo "PASS: all $uc_appends unit_close observations record cost_present"
  else
    echo "FAIL: only $uc_with_cp of $uc_appends unit_close observations record cost_present"
    fails=1
  fi

  local exits
  exits=$(grep -c '"event":"loop_exit"' "$CADENCE") || exits=0
  if [ "$exits" -ge 1 ]; then
    echo "PASS: loop_exit lifecycle mark present (count=$exits)"
  else
    echo "FAIL: no loop_exit lifecycle mark"
    fails=1
  fi

  # Ordering: unit_close observation timestamps strictly BEFORE loop_exit t.
  # cadence.jsonl key order is emitter-controlled, so awk -F'"' positional
  # field parsing is stable: $2=t-key, $4=t-value, $6=event-key, $8=event-value,
  # $10=record_type-key, $12=record_type-value.
  local before_exit
  before_exit=$(awk -F'"' '
    $6=="event" && $8=="jsonl_append" && $10=="record_type" && $12=="unit_close" { n++; ts[n]=$4+0 }
    $6=="event" && $8=="loop_exit" { et=$4+0 }
    END { c=0; for (i=1; i<=n; i++) if (et > 0 && ts[i] < et) c++; print c }
  ' "$CADENCE") || before_exit=0
  if [ "$before_exit" -ge 3 ]; then
    echo "PASS: $before_exit unit_close observations timestamped BEFORE loop_exit (>= 3, mid-segment readability proven)"
  else
    echo "FAIL: only $before_exit unit_close observations before loop_exit (< 3)"
    fails=1
  fi

  return "$fails"
}

if [ "$MODE" = "verify" ]; then
  if verify_cadence; then
    echo "CADENCE-PROBE: verify-only PASS"
    exit 0
  fi
  echo "CADENCE-PROBE: verify-only FAIL"
  exit 1
fi

# ---------------------------------------------------------------------------
# Full run
# ---------------------------------------------------------------------------
if [ ! -d "$MILESTONE_DIR" ]; then
  echo "run-cadence-probe.sh: fixture milestone dir missing: $MILESTONE_DIR" >&2
  exit 1
fi

# Portable in-place sed (BSD/GNU).
sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

reset_fixture() {
  rm -f "$FIX_LOG"
  rm -f "$MILESTONE_DIR/phases/P01/tasks/T01-SUMMARY.md"
  rm -f "$MILESTONE_DIR/phases/P02/tasks/T01-SUMMARY.md"
  rm -f "$MILESTONE_DIR/phases/P01/tasks/T01-PAYLOAD.md"
  rm -f "$MILESTONE_DIR/phases/P02/tasks/T01-PAYLOAD.md"
  rm -f "$MILESTONE_DIR/phases/P01/P01-VERIFICATION.md"
  rm -f "$MILESTONE_DIR/phases/P01/P01-SUMMARY.md"
  rm -f "$MILESTONE_DIR/phases/P02/P02-VERIFICATION.md"
  rm -f "$MILESTONE_DIR/phases/P02/P02-SUMMARY.md"
  rm -f "$MILESTONE_DIR/MFIX-VALIDATED"
  rm -f "$MILESTONE_DIR/build-context-stderr.log"
  rm -f "$MILESTONE_DIR/build-context-planning-stderr.log"
  rm -f "$SPIKE_DIR/.segment-step-out.txt"
  sed_i 's/^- \[x\] \*\*P0/- [ ] **P0/' "$MILESTONE_DIR/MFIX-ROADMAP.md"
}

emit_cadence() {
  # $1 = pre-formed JSON line (single line, no expansion surprises)
  printf '%s\n' "$1" >> "$CADENCE"
}

SEEN=0
poll_once() {
  [ -f "$FIX_LOG" ] || return 0
  local n
  n=$(wc -l < "$FIX_LOG") || n=0
  n=$((n + 0))
  while [ "$SEEN" -lt "$n" ]; do
    SEEN=$((SEEN + 1))
    sed -n "${SEEN}p" "$FIX_LOG" > "$TMPLINE"
    local rt unit cp t
    rt=$(sed -n 's/.*"record_type":"\([^"]*\)".*/\1/p' "$TMPLINE")
    [ -n "$rt" ] || rt="pre_m019_result"
    unit=$(sed -n 's/.*"unitId":"\([^"]*\)".*/\1/p' "$TMPLINE")
    cp=false
    if grep -q '"cost_estimated":' "$TMPLINE"; then cp=true; fi
    if grep -qE '"estimated_cost_usd":[0-9][0-9.]*' "$TMPLINE"; then cp=true; fi
    t=$(_now)
    emit_cadence "{\"t\":\"$t\",\"event\":\"jsonl_append\",\"record_type\":\"$rt\",\"unit\":\"$unit\",\"cost_present\":$cp}"
  done
}

echo "CADENCE-PROBE: resetting fixture"
reset_fixture
: > "$CADENCE"

t=$(_now)
emit_cadence "{\"t\":\"$t\",\"event\":\"loop_start\"}"

echo "CADENCE-PROBE: launching drive-segment.sh in background"
bash "$SPIKE_DIR/drive-segment.sh" > "$DRIVE_LOG" 2>&1 &
CHILD=$!

while kill -0 "$CHILD" 2>/dev/null; do
  poll_once
  sleep 0.2
done

rc=0
wait "$CHILD" || rc=$?

# Stamp loop_exit at exit-detection time; anything drained AFTERWARDS is
# conservatively classified as not-proven-mid-segment.
t=$(_now)
emit_cadence "{\"t\":\"$t\",\"event\":\"loop_exit\",\"code\":$rc}"
poll_once

echo "CADENCE-PROBE: segment exited rc=$rc (drive log: $DRIVE_LOG)"
if [ "$rc" -ne 0 ]; then
  echo "CADENCE-PROBE: segment driver failed — see $DRIVE_LOG" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Post-exit analysis: per-unit_close boundary ordering + observe lag
# ---------------------------------------------------------------------------
EXIT_T=$(awk -F'"' '$6=="event" && $8=="loop_exit" { print $4; exit }' "$CADENCE")
TMPUC="$SPIKE_DIR/.uc-lines.txt"
grep '"record_type":"unit_close"' "$FIX_LOG" > "$TMPUC" || true

while IFS= read -r ucline; do
  printf '%s\n' "$ucline" > "$TMPLINE"
  unit=$(sed -n 's/.*"unitId":"\([^"]*\)".*/\1/p' "$TMPLINE")
  gran=$(sed -n 's/.*"granularity":"\([^"]*\)".*/\1/p' "$TMPLINE")
  rec_ts=$(sed -n 's/.*"timestamp":"\([^"]*\)".*/\1/p' "$TMPLINE")
  cp=false
  if grep -qE '"estimated_cost_usd":[0-9][0-9.]*' "$TMPLINE"; then cp=true; fi
  obs_t=$(awk -F'"' -v u="$unit" '
    $6=="event" && $8=="jsonl_append" && $12=="unit_close" && $16==u { print $4; exit }
  ' "$CADENCE")
  if [ -z "$obs_t" ]; then
    t=$(_now)
    emit_cadence "{\"t\":\"$t\",\"event\":\"analysis\",\"unit\":\"$unit\",\"granularity\":\"$gran\",\"readable_before_loop_exit\":false,\"observe_lag_s\":null,\"cost_present\":$cp,\"note\":\"observed only after exit-detection\"}"
    continue
  fi
  before=$(awk -v a="$obs_t" -v b="$EXIT_T" 'BEGIN { if (a+0 < b+0) print "true"; else print "false" }')
  rec_epoch=$(_iso_to_epoch "$rec_ts")
  lag=$(awk -v a="$obs_t" -v b="$rec_epoch" 'BEGIN { printf "%.3f", a - b }')
  t=$(_now)
  emit_cadence "{\"t\":\"$t\",\"event\":\"analysis\",\"unit\":\"$unit\",\"granularity\":\"$gran\",\"readable_before_loop_exit\":$before,\"observe_lag_s\":$lag,\"cost_present\":$cp}"
done < "$TMPUC"

uc_total=$(grep -c '' "$TMPUC") || uc_total=0
uc_before=$(grep -c '"event":"analysis".*"readable_before_loop_exit":true' "$CADENCE") || uc_before=0
verdict="exit_only"
if [ "$uc_before" -ge 3 ]; then
  verdict="unit_grain_mid_segment"
fi
t=$(_now)
emit_cadence "{\"t\":\"$t\",\"event\":\"probe_summary\",\"unit_close_total\":$uc_total,\"unit_close_before_exit\":$uc_before,\"verdict\":\"$verdict\"}"

rm -f "$TMPLINE" "$TMPUC"

echo "CADENCE-PROBE: analysis complete — unit_close_total=$uc_total before_exit=$uc_before verdict=$verdict"

if verify_cadence; then
  echo "CADENCE-PROBE: PASS"
  exit 0
fi
echo "CADENCE-PROBE: FAIL"
exit 1
