---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M046"
name: "Cost-read cadence probe (#Q-4)"
depends_on: []
---

## Prerequisites

All pre-existing (verified on disk at plan-authoring time):

- `scripts/lifecycle/auto-loop.sh` — the Tier C loop. Accepts `--cost=<amount>` plumbing on its record path (see line ~129 `COST_ESTIMATED`) and emits `unit_close` records to `<state-root>/execution-log.jsonl`. Supports dispatch stubbing (the M031 `--dispatch-stub` fixture path — check `commands/auto.md` + `scripts/intake/do-entry.sh` for the stub convention if flags differ).
- `scripts/verify/m019-schema.sh` — documents the M019 record contract: record types `payload_breakdown | dispatch_usage | unit_close`; `unit_close` carries `granularity: task|phase|milestone` + mandatory cost+quality pairing.
- `.orchestrator/proposals/M-auto-v2b-P00-spike-evidence.md` — the P00 spike evidence proving `claude -p --output-format json` returns a parent-readable `total_cost_usd` per segment (cite this; do NOT re-spend to re-prove it).
- `.orchestrator/milestones/M045/phases/P01/spike/` — the M045 fixture-milestone pattern to copy for the throwaway fixture tree shape.

## Description

Answer **#Q-4** mechanically: *when* do cost-bearing records become readable from the M019 Tier-1 JSONL relative to (a) unit boundaries and (b) segment (loop-process) boundaries? The unattended driver (P04) must decide, **before spawning segment N+1**, how much budget is already spent. Two candidate sources: the JSONL stream (if it emits at unit grain mid-segment, completed-unit spend is readable pre-spawn) and the child's `--output-format json` `total_cost_usd` (only readable after the segment exits — P00-proven). The probe measures the JSONL half with zero LLM spend by driving `auto-loop.sh` with a dispatch stub against a throwaway fixture milestone in a scratch state root, wrapping the loop so each JSONL append is timestamped against unit and loop lifecycle marks.

The verdict shapes P04's FR-7/FR-8 design: if `unit_close` cost records land synchronously at unit grain, the reserve-then-spend ledger reconciles per-unit mid-segment AND per-segment via the JSON result; if they only land at loop exit, the JSON result is the sole per-segment source and the in-segment watchdog (FR-7) must rely on its conservative reserve + duration probe until segment end.

## Steps

1. **Create the spike dirs**: `.orchestrator/milestones/M046/phases/P01/spike/cost/` and `spike/cost/fixture/`.

2. **Build the throwaway fixture milestone** under `spike/cost/fixture/` (copy the M045 P01 spike-fixture shape): a scratch state root containing a minimal milestone dir (`MFIX`) with a 2-phase roadmap, each phase pre-planned with one trivial task, such that `auto-loop.sh` can advance ≥ 3 units (task → phase → task) under the dispatch stub without any LLM call. Before authoring, read `scripts/lifecycle/auto-loop.sh` usage header + `scripts/state/derive-phase.sh` to match the exact file-presence contract the loop derives state from (the M045 spike fixture is the working example).

3. **Author the probe wrapper** at `spike/cost/run-cadence-probe.sh`:
   - Launch `auto-loop.sh` against the fixture (stubbed dispatch, scratch `ORCHESTRATOR_ROOT`) in the background.
   - Poll the fixture's `execution-log.jsonl` every 0.2 s; on each size change, append to `spike/cost/cadence.jsonl` one JSON line: `{"t": "<epoch.ms>", "event": "jsonl_append", "record_type": "<type>", "unit": "<id>", "cost_present": true|false}`.
   - Also append lifecycle marks the wrapper itself controls: `{"t": ..., "event": "loop_start"}`, `{"t": ..., "event": "loop_exit", "code": <n>}`.
   - After exit: for every `unit_close` in the fixture log, record whether its JSONL line was readable BEFORE `loop_exit` (mid-segment) and the append→readable latency (expected ≈ 0 — POSIX atomic append; the number matters less than the boundary ordering).

4. **Run the probe**; assert `cadence.jsonl` contains ≥ 3 `jsonl_append` records with `record_type=unit_close`, each with `cost_present` recorded, ordered relative to `loop_exit`.

5. **Author the findings note** at `spike/cost/CADENCE-FINDINGS.md` (~20 lines): observed ordering (unit-grain mid-segment vs exit-only), cost-field presence on stub-driven records (if the stub path omits real cost fields, say so plainly — that itself is a finding: the JSONL cost value under stubbed dispatch is synthetic, and the authoritative per-segment figure remains the P00-proven `total_cost_usd`), and the recommended FR-7/FR-8 source split. Cite `.orchestrator/proposals/M-auto-v2b-P00-spike-evidence.md` for the JSON-result half.

## Must-Haves

- The cost-cadence log captures per-record wall-clock timestamps proving when cost-bearing records appear relative to unit and loop boundaries.

## Verification

```bash
bash .orchestrator/milestones/M046/phases/P01/spike/cost/run-cadence-probe.sh --verify-only
grep -c "unit_close" .orchestrator/milestones/M046/phases/P01/spike/cost/cadence.jsonl
grep -c "loop_exit" .orchestrator/milestones/M046/phases/P01/spike/cost/cadence.jsonl
```

## Notes

Expected: `--verify-only` re-checks the captured log without re-running the loop and exits 0 when the assertions in Step 4 hold; first `grep -c` prints ≥ 3; second prints ≥ 1. Zero LLM spend in this task — the `claude -p` JSON half of #Q-4 is answered by citation to the P00 evidence, not re-measurement. T03 authors the durable `tools/verify/m046-p01-cadence-log.sh` wrapper; this task's inline checks depend only on artifacts it creates itself (plan-time discipline rule 2).

## Inputs

### From Previous Tasks

None (first task, parallel with T01).

### From Disk (Pre-existing)

- `scripts/lifecycle/auto-loop.sh` — loop under test; read its usage header for stub/state-root flags before building the fixture.
- `scripts/state/derive-phase.sh` — file-presence contract the fixture tree must satisfy.
- `.orchestrator/milestones/M045/phases/P01/spike/fixture/` — working fixture-tree example to copy.
- `scripts/verify/m019-schema.sh` — record-type and field contract for classifying observed records.
- `.orchestrator/proposals/M-auto-v2b-P00-spike-evidence.md` — P00 `total_cost_usd` evidence (citation input).

## Constraints

- **Zero LLM spend** — stub-driven only; the JSON-result half is cited from P00.
- **Scratch state root only** — the probe must not write to the repo's live `.orchestrator/execution-log.jsonl`; point the loop at the fixture root (`ORCHESTRATOR_ROOT` env or the loop's root flag — confirm which from the usage header).
- **Throwaway discipline** — nothing lands outside the spike dir.
- **AD-19 shapes** in all harness scripts (no `$(...)`-with-pipes, no >2 compound chains); background-launch + poll logic lives INSIDE `run-cadence-probe.sh`, invoked as a single script file.

## Expected Output

`spike/cost/` containing the fixture tree, the probe wrapper, `cadence.jsonl` (≥3 timestamped `unit_close` observations + lifecycle marks), and `CADENCE-FINDINGS.md` with the observed ordering and the recommended FR-7/FR-8 cost-source split. These are T03's #Q-4 verdict inputs.
