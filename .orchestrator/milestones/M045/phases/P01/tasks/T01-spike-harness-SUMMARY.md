---
schema_version: "1.0"
type: task-summary
task: "T01"
phase: "P01"
milestone: "M045"
name: "Build the throwaway spike fixture + self-continue driver + capture helper"
outcome: success
---

## What was built

Throwaway spike harness under `.orchestrator/milestones/M045/phases/P01/spike/`:

- `fixture/` — `execution-log.jsonl` (driver appends), `orchestrator.lock` (static `startedAt`), `plan.txt` (3 synthetic phases).
- `capture-segment.sh` — appends one JSON measurement record per segment to `segments.jsonl`.
- `self-continue-drive.sh` — one segment: appends synthetic dispatch entries (now with `phase` + `timestamp` fields so the REAL `context-monitor.sh` counts them), runs `context-monitor.sh --limit N`, and on `CONTEXT:ROTATE` emits `SPIKE:SELF_CONTINUE`; on plan exhaustion emits `SPIKE:COMPLETE`.

## Fixes during build (both flagged as risks in the T01 plan)

1. **Missing `timestamp`/`phase` fields** — `context-monitor.sh` filters execution-log entries to those with a `timestamp` after the lock's `startedAt`; the first synthetic entries lacked it → `weight=0`, no rotation. Fixed the driver's `printf` to emit both fields with a static post-session timestamp.
2. **`REPO_ROOT` depth off by one** — the driver walked up 7 `..` from `spike/` but the dir is 6 below repo root, resolving above the repo so the `context-monitor.sh` call silently failed under `|| true`. Corrected to 6.

## Verification

Self-test (`self-continue-drive.sh <spike> 1 --limit 3 --work 4`) now emits
`SPIKE:SELF_CONTINUE next_segment=2 phase=P01 weight=4 limit=3` and appends a
`rotate` record. Both scripts executable; `grep CONTEXT:ROTATE` matches;
`segments.jsonl` present. Fixture + segments logs reset to empty for T02.

## For downstream

T02 runs the segments to cross ≥2 boundaries. **Key discovery surfaced during
build (feeds T02/T03 and #Q-2)**: `ScheduleWakeup` is only available inside
`/loop` dynamic mode, not a plain interactive turn — so a true in-session live
re-entry loop must be launched by the operator via `/loop`. This is itself
evidence that the arming surface (#Q-2) is the `/loop` recipe, not a bare flag.
