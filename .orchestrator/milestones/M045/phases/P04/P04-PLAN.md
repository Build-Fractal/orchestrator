---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M045"
goal: "Make self-continuing runs auditable and stall-observable: FR-9 continuity log records + FR-10 SELF_CONTINUE:STALLED watchdog, plus the flagship SC-1 continuity fixture and SC-7 stall fixture."
demo_sentence: "A completed multi-segment self-continue run is auditable as one continuous execution in a JSONL log, and a segment that produces no outcome surfaces as SELF_CONTINUE:STALLED via a status reader."
risk: "medium"
depends_on: ["P03"]
---

## Must-Haves

### Truths

- The driver appends continuity records (`self_continue_scheduled` per re-spawn, plus a terminal/cap/unavailable record) to a JSONL log when `--log` is given.
  - Check: `bash tools/verify/m045-p04-continuity.sh`
- A segment that produces no outcome marker surfaces as `SELF_CONTINUE:STALLED` and writes a `self_continue_unconfirmed` log record; the status reader reports it.
  - Check: `bash tools/verify/m045-p04-stall.sh`

### Artifacts

- scripts/diagnostics/self-continue-status.sh (min 15 lines, contains "SELF_CONTINUE:STALLED")
- tools/verify/m045-p04-continuity.sh (min 15 lines, contains "self_continue_scheduled")
- tools/verify/m045-p04-stall.sh (min 15 lines, contains "STALLED")

### Key Links

- scripts/diagnostics/self-continue-status.sh → scripts/lifecycle/self-continue-drive.sh (status reader consumes the driver's log)

## Tasks

### T01: Add FR-9/FR-10 log emission + stall detection to the driver

See `tasks/T01-log-emission-PLAN.md`.

### T02: Status reader scripts/diagnostics/self-continue-status.sh (FR-10 surface)

See `tasks/T02-status-reader-PLAN.md`.

### T03: SC-1 continuity fixture + SC-7 stall fixture

See `tasks/T03-fixtures-PLAN.md`.

## Task Dependencies

```
T01 → T02 → T03
```

## Files Likely Touched

- scripts/lifecycle/self-continue-drive.sh (modify — add --log emission + stall path)
- scripts/diagnostics/self-continue-status.sh (create)
- tools/verify/m045-p04-continuity.sh (create)
- tools/verify/m045-p04-stall.sh (create)

## Notes

- **FR-10 under the process-fresh model**: the ScheduleWakeup-era "directive emitted but tool call unconfirmed" maps to "the driver ran a fresh segment but it produced NO outcome marker" (the spawned `claude -p` crashed / failed to start / hung-then-died). The driver writes a `self_continue_unconfirmed` record BEFORE each segment and clears it once an outcome marker appears; an unknown outcome leaves it uncleared and emits `SELF_CONTINUE:STALLED`. The status reader surfaces a lingering unconfirmed record. This is the honest process-fresh analog of the spec's in-session stall watchdog.
- **SC-1 (flagship continuity)**: a completed multi-segment run must be auditable as ONE continuous execution — the log shows ≥1 `self_continue_scheduled` records then a terminal record, with NO "human re-invoke" marker between segments. The fixture asserts this from the log alone.
- All fixtures hermetic (stub `--auto-cmd`, `--min-interval 0`), consistent with P03.
- Keep changes additive; do not regress P03's SC-2/SC-3/SC-4 verifiers (run them after editing the driver).
