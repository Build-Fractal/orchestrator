---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M045"
name: "Execute the live multi-rotation self-continue run and capture measurements"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `spike/self-continue-drive.sh` + `spike/capture-segment.sh` exist and self-tested; `spike/fixture/execution-log.jsonl` truncated to empty.

## Description

Run the spike across ≥2 real rotation boundaries and populate `spike/segments.jsonl` with the measurements needed for the T03 verdict. This task tests, for real, whether an in-session `ScheduleWakeup` re-entry keeps the orchestrating session's context bounded (via harness compaction) while resuming correctly from disk.

**CRITICAL EXECUTION CONSTRAINT — read before dispatching.** This task MUST run in the **orchestrating (main) session** under `/loop` self-paced mode. It CANNOT be handed to a fresh `Agent`/subagent dispatch: `ScheduleWakeup` (and the harness context-compaction it relies on) are main-loop primitives that a subagent does not have. If auto-mode reaches this task via subagent dispatch, it must surface this constraint and hand execution back to the interactive session rather than stubbing the run. (This is itself a finding P02 must honor: the production self-continue path lives in the main-session `commands/auto.md` agent, not in a dispatched unit.)

## Steps

Perform these in the main session:

1. Truncate `spike/segments.jsonl` to empty (clear the T01 self-test record).
2. **Segment 1**: run
   `sh .orchestrator/milestones/M045/phases/P01/spike/self-continue-drive.sh .orchestrator/milestones/M045/phases/P01/spike 1 --limit 3 --work 4`
   Read stdout. Immediately record, into the just-appended `segments.jsonl` line's `context_proxy`, the current session context measurement (see Measurement protocol below) — edit the `PENDING` placeholder to the observed value.
3. If stdout carried `SPIKE:SELF_CONTINUE next_segment=2`: call the `ScheduleWakeup` tool with a short delay (e.g. `delaySeconds: 60`, the floor) and a `prompt` that re-invokes THIS task's next segment (segment 2). When the wakeup fires, run the driver for segment 2 (same command, index `2`), and again fill its `context_proxy` from the observed context at re-entry.
4. Repeat for segment 3 (cross the 2nd rotation boundary). Three segments = two boundaries crossed, satisfying "≥2 rotation boundaries."
5. Continue until the driver emits `SPIKE:COMPLETE` (fixture plan exhausted) or ≥3 rotate segments are captured, whichever comes first. On `SPIKE:COMPLETE`, do NOT schedule a further wakeup — the loop is done.
6. **Correctness check at each re-entry**: before running each post-wakeup segment, confirm the loop can identify "the next segment" purely from disk state (the segment index passed in the wakeup prompt + the fixture log on disk), demonstrating disk-authoritative resume (spec CON-2). Note any case where the re-entry could NOT resume from disk.

### Measurement protocol (the boundedness signal)

At each segment's re-entry, record the strongest available context proxy into `context_proxy`:
- **Preferred**: the harness-reported context/token usage for the current session, if the environment exposes it (a token count or context-window-percent). 
- **Fallback 1**: the transcript message count at re-entry (monotonic growth vs. a drop after compaction is the signal).
- **Fallback 2**: the `weight=` value the driver already captured (a within-session proxy that resets when the lock `startedAt` advances — note this is a *design* reset, not evidence of real LLM-context relief; flag it as such).
Record which proxy was used in each line (append `proxy_kind` to the `context_proxy` string, e.g. `"tokens:48210"` / `"messages:37"` / `"weight-only"`).

## Must-Haves

- `spike/segments.jsonl` contains ≥3 segment records, ≥2 with `status":"rotate"`.
- Each rotate segment's `context_proxy` is filled with a real observed value (not the `PENDING`/`unavailable` placeholder) OR explicitly annotated `unavailable` with the reason.
- A note (captured in the segment records or a scratch note for T03) on whether each re-entry resumed correctly from disk.

## Verification

`bash tools/verify/m045-p01-segments-present.sh`

## Inputs

### From Previous Tasks
- `spike/self-continue-drive.sh` (from T01)
  - Key API: `self-continue-drive.sh <spike-dir> <segment-index> [--limit N] [--work N]`; emits `SPIKE:SELF_CONTINUE next_segment=<i>` on rotation, `SPIKE:CONTINUE_INLINE` when no rotation, `SPIKE:COMPLETE` when the fixture plan is exhausted; appends one line to `segments.jsonl` per call.
- `spike/capture-segment.sh` (from T01) — called by the driver, not directly.

### From Disk (Pre-existing)
- The harness `ScheduleWakeup` tool — schedules the next `/loop` dynamic-mode input in THIS session; `delaySeconds` clamped to [60, 3600].

## Constraints

- Main-session-only (see CRITICAL EXECUTION CONSTRAINT). Do NOT stub the run to satisfy a subagent dispatch.
- Keep the run bounded: ≥2 boundaries is sufficient evidence; do not loop indefinitely. Cap at ~5 segments.
- `tools/verify/m045-p01-segments-present.sh` is authored in T03; if T02's verification runs before T03, substitute the inline check `test -f .orchestrator/milestones/M045/phases/P01/spike/segments.jsonl` and confirm ≥3 lines by inspection.

## Expected Output

`spike/segments.jsonl` with ≥3 records spanning ≥2 rotation boundaries, each rotate record carrying a real context proxy, plus resume-correctness notes for T03 to analyze.
