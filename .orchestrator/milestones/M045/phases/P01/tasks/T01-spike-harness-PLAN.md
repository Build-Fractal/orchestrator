---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M045"
name: "Build the throwaway spike fixture + self-continue driver + capture helper"
depends_on: []
---

## Prerequisites

- `scripts/lifecycle/context-monitor.sh` exists (the real rotation detector this spike drives).
- `scripts/lifecycle/lock-manager.sh` exists (lock acquire/break).
- Bash 3.2+ / POSIX sh.

## Description

Build a self-contained, throwaway spike harness that isolates the exact mechanism M045 P01 must test: the loop hits a context-rotation signal, and instead of exiting for a human, re-enters via `ScheduleWakeup` and resumes from disk. The harness must let the orchestrating-session agent (T02) cross ≥2 real rotation boundaries cheaply — WITHOUT slow real subagent dispatches — by simulating per-phase "work" as synthetic execution-log entries and using the REAL `context-monitor.sh` (with a forced-low limit) to produce the rotation signal.

All deliverables live under `.orchestrator/milestones/M045/phases/P01/spike/` and are spike-grade/disposable.

## Steps

1. Create the spike directory tree:
   - `.orchestrator/milestones/M045/phases/P01/spike/`
   - `.orchestrator/milestones/M045/phases/P01/spike/fixture/`

2. Seed a minimal fixture the driver operates on:
   - `spike/fixture/execution-log.jsonl` — start empty (the driver appends to it).
   - `spike/fixture/orchestrator.lock` — a JSON lock file with a `startedAt` field the driver rewrites per segment; e.g. `{"startedAt":"2026-07-01T00:00:00Z","completedUnits":[]}`.
   - `spike/fixture/plan.txt` — three lines naming synthetic phases: `P01`, `P02`, `P03` (the driver advances one per segment; exhaustion → SPIKE:COMPLETE).

3. Author `spike/capture-segment.sh` — appends one measurement record to `spike/segments.jsonl`. Exact contract:
   ```sh
   #!/usr/bin/env sh
   # capture-segment.sh <spike-dir> <segment-index> <phase> <weight> <limit> <rotate|ok|complete> <context-proxy>
   # Appends a JSON line to <spike-dir>/segments.jsonl.
   set -eu
   SPIKE_DIR="$1"; IDX="$2"; PHASE="$3"; WEIGHT="$4"; LIMIT="$5"; STATUS="$6"; PROXY="$7"
   LOG_LINES=$(grep -c '' "$SPIKE_DIR/fixture/execution-log.jsonl" 2>/dev/null || echo 0)
   printf '{"segment":%s,"phase":"%s","exec_log_lines":%s,"weight":"%s","limit":"%s","status":"%s","context_proxy":"%s"}\n' \
     "$IDX" "$PHASE" "$LOG_LINES" "$WEIGHT" "$LIMIT" "$STATUS" "$PROXY" >> "$SPIKE_DIR/segments.jsonl"
   ```
   Note: `context_proxy` is filled by T02 with the harness-observed context/token count at re-entry (the string `unavailable` if the harness exposes no such number — in which case boundedness is judged from message-count/weight trend instead).

4. Author `spike/self-continue-drive.sh` — runs ONE segment and emits a directive telling the caller whether to self-continue. Exact contract:
   ```sh
   #!/usr/bin/env sh
   # self-continue-drive.sh <spike-dir> <segment-index> [--limit N] [--work N]
   # One segment: simulate a phase's work (append N synthetic dispatch entries to the
   # fixture execution log), then run the REAL context-monitor with a low limit. If it
   # reports rotation, capture the segment and emit SPIKE:SELF_CONTINUE for the caller
   # to translate into a ScheduleWakeup re-entry. When the fixture plan is exhausted,
   # emit SPIKE:COMPLETE. Mirrors the production exit-14 branch (CONTEXT:ROTATE) that
   # M045 P02/P03 will wire for real.
   set -eu
   SPIKE_DIR="$1"; IDX="$2"; shift 2
   LIMIT=3; WORK=4
   while [ $# -gt 0 ]; do case "$1" in
     --limit) LIMIT="$2"; shift 2 ;;
     --work) WORK="$2"; shift 2 ;;
     *) shift ;;
   esac; done
   REPO_ROOT="$(cd "$(dirname "$0")/../../../../../../.." && pwd)"
   FIX="$SPIKE_DIR/fixture"
   PHASE_COUNT=$(grep -c '' "$FIX/plan.txt")
   if [ "$IDX" -gt "$PHASE_COUNT" ]; then
     sh "$SPIKE_DIR/capture-segment.sh" "$SPIKE_DIR" "$IDX" "-" "-" "$LIMIT" "complete" "-"
     echo "SPIKE:COMPLETE segments_done=$((IDX-1))"
     exit 0
   fi
   PHASE=$(sed -n "${IDX}p" "$FIX/plan.txt")
   # Simulate this phase's work: WORK synthetic dispatch entries into the fixture log.
   i=0; while [ "$i" -lt "$WORK" ]; do
     printf '{"type":"dispatch","unit":"%s/T0%s","outcome":"success"}\n' "$PHASE" "$i" >> "$FIX/execution-log.jsonl"
     i=$((i+1))
   done
   # REAL rotation check against the seeded log with a forced-low limit.
   MON=$(sh "$REPO_ROOT/scripts/lifecycle/context-monitor.sh" "$FIX/execution-log.jsonl" "$FIX/orchestrator.lock" --limit "$LIMIT" 2>/dev/null || true)
   WEIGHT=$(printf '%s' "$MON" | sed -n 's/.*weight=\([0-9]*\).*/\1/p')
   [ -n "$WEIGHT" ] || WEIGHT=0
   case "$MON" in
     *CONTEXT:ROTATE*)
       sh "$SPIKE_DIR/capture-segment.sh" "$SPIKE_DIR" "$IDX" "$PHASE" "$WEIGHT" "$LIMIT" "rotate" "PENDING"
       echo "SPIKE:SELF_CONTINUE next_segment=$((IDX+1)) phase=$PHASE weight=$WEIGHT limit=$LIMIT" ;;
     *)
       sh "$SPIKE_DIR/capture-segment.sh" "$SPIKE_DIR" "$IDX" "$PHASE" "$WEIGHT" "$LIMIT" "ok" "-"
       echo "SPIKE:CONTINUE_INLINE next_segment=$((IDX+1)) phase=$PHASE weight=$WEIGHT limit=$LIMIT" ;;
   esac
   ```
   The `REPO_ROOT` relative-depth (`../../../../../../..` from `spike/`) resolves the repo root from `.orchestrator/milestones/M045/phases/P01/spike/self-continue-drive.sh`; confirm the resolved path contains `scripts/lifecycle/context-monitor.sh` during the T01 self-test (Step 6) and adjust the depth if the self-test fails.

5. `chmod +x` both scripts.

6. Self-test (single-segment dry exercise): run
   `sh .orchestrator/milestones/M045/phases/P01/spike/self-continue-drive.sh .orchestrator/milestones/M045/phases/P01/spike 1 --limit 2 --work 4`
   and confirm stdout carries a `SPIKE:SELF_CONTINUE` (or `SPIKE:CONTINUE_INLINE`) line and that `spike/segments.jsonl` gained one record. Then reset the fixture log to empty for the real T02 run (truncate `spike/fixture/execution-log.jsonl`).

## Must-Haves

- `spike/self-continue-drive.sh` exists, is executable, references `CONTEXT:ROTATE`, and emits `SPIKE:SELF_CONTINUE` on a rotation.
- `spike/capture-segment.sh` exists and appends JSON records to `segments.jsonl`.
- The self-test produced at least one segment record.

## Verification

`test -x .orchestrator/milestones/M045/phases/P01/spike/self-continue-drive.sh`
`test -x .orchestrator/milestones/M045/phases/P01/spike/capture-segment.sh`
`grep -q "CONTEXT:ROTATE" .orchestrator/milestones/M045/phases/P01/spike/self-continue-drive.sh`
`test -f .orchestrator/milestones/M045/phases/P01/spike/segments.jsonl`

## Inputs

### From Disk (Pre-existing)
- `scripts/lifecycle/context-monitor.sh` — the real rotation detector; CLI: `context-monitor.sh <execution-log> <lock-file> [--limit N]`; emits `CONTEXT:OK weight=N ...` or `CONTEXT:ROTATE weight=N ...` on stdout; always exits 0.
- `scripts/lifecycle/lock-manager.sh` — not called directly by the driver in the spike; the fixture uses a static lock file.

## Constraints

- Everything under `spike/` is throwaway/spike-grade — do NOT touch production paths (`commands/`, `scripts/lifecycle/auto-loop.sh`, etc.). Respects spec CON-3.
- No new production dependencies; POSIX sh only.
- After the Step-6 self-test, leave `spike/fixture/execution-log.jsonl` truncated so T02 starts from a clean slate.

## Expected Output

Two executable spike scripts + a seeded fixture, ready for the T02 live run. The Step-6 self-test appends one record to `segments.jsonl` (which T02 will re-seed).
