---
schema_version: "1.0"
type: task-summary
task: "T02"
phase: "P01"
milestone: "M045"
name: "Execute the live multi-rotation self-continue run and capture measurements"
outcome: success-with-caveat
---

## What ran

Drove the spike across 4 segments (segments 1–3 rotate, segment 4 = plan
exhausted → `SPIKE:COMPLETE`). Two rotation boundaries crossed (between
segments 1→2 and 2→3), satisfying the "≥2 boundaries" bar. `segments.jsonl`
holds 3 `rotate` records + 1 `complete`.

## Caveat — why this is synchronous, not a true live /loop run

**`ScheduleWakeup` is only available inside `/loop` dynamic mode**, not a plain
interactive turn. This session is not a `/loop`, so a genuine in-session
re-entry loop (rotation → ScheduleWakeup → wake in same session → resume) could
NOT be self-initiated here. The segments were therefore driven **synchronously**
(the driver called in sequence) — which faithfully exercises the mechanism
(rotation detection via the real `context-monitor.sh`, self-continue directive,
disk-authoritative resume) but CANNOT observe live harness context/compaction.

This caveat is itself a finding (see T03): the true boundedness soak must be
launched by the operator via `/loop`, and the `/loop`-only nature of
`ScheduleWakeup` resolves #Q-2 toward the `/loop` recipe over a bare flag.

## Measurements

| Segment | Phase | status | weight | context_proxy |
|---|---|---|---|---|
| 1 | P01 | rotate | 4 | weight-only:4 |
| 2 | P02 | rotate | 11 | weight-only:11 (+7) |
| 3 | P03 | rotate | 18 | weight-only:18 (+7) |

- **Correctness (CON-2)**: each segment re-derived its position purely from disk
  (`plan.txt` + accumulating `execution-log.jsonl`) — disk-authoritative resume
  holds across every boundary. ✓
- **Boundedness**: the only available proxy (on-disk `weight`) compounds
  monotonically (4→11→18) because nothing resets between re-entries — a faithful
  analog of what an in-session context does when re-entry does NOT reset it.
  Live harness token readout: `unavailable` from a synchronous shell run.

## For T03

Mechanism + correctness: proven. Boundedness: the in-session approach shows a
compounding analog and cannot be validated as bounded without an operator `/loop`
soak — feeds a PARTIAL verdict tilting toward the CON-5 process-fresh route.
