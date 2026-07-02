---
schema_version: "1.0"
type: phase-summary
phase: "P01"
milestone: "M045"
outcome: complete
verdict: PARTIAL
---

# P01 Summary — Viability spike (SC-6 / #Q-1 decision gate)

## Outcome

**VERDICT: PARTIAL → substrate pivot (decision D015).** The spike tested whether
in-session `ScheduleWakeup` re-entry relieves the orchestrating context across
rotation boundaries. It does not: `ScheduleWakeup` re-fires in the same session
without a reset, so relief depends on non-rotation-aware harness compaction (the
spike's weight analog compounded 4→11→18). Correctness (disk-authoritative
resume, CON-2) held. On the axis rotation targets, in-session re-entry is weaker
than today's fresh-session re-invoke.

## Decision driven

M045 folds into the **process-fresh `claude -p`** re-entry substrate (D015 /
spec CON-5). P02–P04 proceed with the substrate swapped; the mechanism work
(deterministic branch, capability detection, safety envelope, observability) is
~unchanged. #Q-1 resolved; #Q-2 moot under process-fresh.

## Key files

- `P01-VIABILITY-EVIDENCE.md` — measurements + verdict + resolution.
- `spike/` — throwaway harness (fixture + `self-continue-drive.sh` + `capture-segment.sh` + `segments.jsonl`).
- `tools/verify/m045-p01-viability-evidence.sh`, `tools/verify/m045-p01-segments-present.sh` — verifiers (PASS).
- `.orchestrator/DECISIONS.md` D015 — the substrate-pivot decision.

## Value

The spike caught a load-bearing false premise before P02–P04 were built on it —
exactly the RISK-1/MIT-1 failure mode the conversus deliberation demanded SC-6
guard against. A cheap, correct "no" that redirected the milestone.

## Follow-on for P02 (substrate swap)

- Capability detection: `headless_reentry` (can spawn a fresh `claude -p`?) replaces the rejected `schedule_wakeup` capability.
- The P01 spike `self-continue-drive.sh` is the seed for a productionized process-fresh driver (rotation → fresh process → resume-from-disk → until terminal).
- FR-5a "delay floor" reframes as a min-interval between process spawns (avoid busy-spawn under a mis-set threshold).
- Arming (#Q-2) becomes a driver/launch flag, not a `/loop` recipe.
