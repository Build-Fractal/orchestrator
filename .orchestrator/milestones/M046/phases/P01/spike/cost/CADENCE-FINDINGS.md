# CADENCE-FINDINGS — #Q-4 cost-read cadence probe (M046/P01/T02)

Probe: `run-cadence-probe.sh` drove the REAL `scripts/lifecycle/auto-loop.sh` single-step driver
(5 steps: READY -> PHASE_COMPLETE -> READY -> PHASE_COMPLETE -> MILESTONE_VALIDATING) against the
throwaway MFIX fixture with stubbed dispatch (summaries written via the real `write-summary.sh`,
the production unit_close emission path). Zero LLM spend. Evidence: `cadence.jsonl` (this dir).

## Observed ordering (the JSONL half of #Q-4)

- **VERDICT: unit_grain_mid_segment.** All 4 `unit_close` records (task P01/T01, phase P01, task
  P02/T01, phase P02) were readable from the fixture `execution-log.jsonl` BEFORE `loop_exit` —
  the last one ~7 s before segment end. Observe-lag 0.35–0.75 s (bounded by the 0.2 s poll +
  1 s record-timestamp truncation): POSIX append is effectively synchronous at unit close.
- Cost-bearing records appear even EARLIER than unit close: `dispatch_usage` (emission_point
  build-context) lands at dispatch time, and the step-G result record (`cost_estimated`, from
  `--cost=`) lands immediately after each unit_close. Both mid-segment.

## Cost-field presence under stubbed dispatch (plainly stated)

- `unit_close.estimated_cost_usd` key is ALWAYS present (M019 Goodhart pairing) but its VALUE was
  **null on all 4 records** — including P02/T01, where a synthetic `dispatch_usage` carried
  `estimated_cost_usd:0.0123`. Cause: `write-summary.sh` any-null propagation — build-context's
  real `dispatch_usage` for the same unitId carried `estimated_cost_usd:null` (`pricing_warning:
  no-rate` for the empty stub model), and one null contributor nulls the whole sum. This holds in
  production too: unit_close cost is estimate-grade and NULLABLE under any pricing degradation.
- The step-G `--cost` value lands under key `cost_estimated` (pre-M019 result-record shape), which
  the unit_close aggregator does NOT read (it matches `estimated_cost_usd` only) — and it lands
  AFTER the same unit's unit_close anyway. Two disjoint unit-grain cost surfaces.
- The authoritative per-segment actual remains the child's `claude -p --output-format json`
  `total_cost_usd` (0.244–0.249/worker, parent-readable at segment exit only) — P00-proven, cited
  from `.orchestrator/proposals/M-auto-v2b-P00-spike-evidence.md`; NOT re-measured here.

## Recommended FR-7/FR-8 cost-source split

- **FR-7 (in-segment watchdog):** read the M019 JSONL at unit grain mid-segment — it IS readable
  pre-spawn and per-unit — but treat JSONL cost values as advisory estimates that may be null.
  Primary in-segment guard stays the conservative reserve + duration probe; reconcile the reserve
  downward per completed unit only when a non-null `estimated_cost_usd` (or `cost_estimated`) is
  readable, never assume presence.
- **FR-8 (per-segment reconciliation):** true-up the reserve-then-spend ledger at each segment
  boundary from the exiting child's `total_cost_usd` JSON result (the sole authoritative actual),
  BEFORE spawning segment N+1. JSONL supplies grain; JSON result supplies truth.
