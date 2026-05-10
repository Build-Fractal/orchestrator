---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M019"
goal: "Ship the Tier 1 JSONL emitter (payload_breakdown + dispatch_usage + unit_close) on top of the P00-adapted dispatch baseline, with cost+quality pairing, pricing-degradation fallback, schema additivity, zero-token growth, and a P00->P01 ordering gate — no Tier 2/3 surface."
demo_sentence: "A developer dispatches a Tier-C task via scripts/dispatch/dispatch-interface.sh on a fixture milestone; after dispatch returns, the milestone's execution-log.jsonl contains exactly one new payload_breakdown record and exactly one new dispatch_usage record; when a task summary is then written via scripts/knowledge/write-summary.sh task ..., exactly one unit_close record is appended carrying both a cost block and a quality block; when .orchestrator/config/pricing.yml is renamed away mid-run, the next dispatch still emits a record with estimated_cost_usd: null + pricing_warning and exits 0; bash scripts/verify/m019-p01-phase-suite.sh exits 0; bash scripts/verify/m019-p01-no-pre-p00-emission.sh confirms no emitter record landed in any post-M011 milestone log before P00 went green."
risk: "medium"
depends_on: ["P00"]
---

## Must-Haves

### Truths

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M019/P01 verification logic lives inside the
     scripts/verify/m019-p01-*.sh files; the Check commands here invoke them. -->

- `scripts/dispatch/build-context.sh` emits exactly one `payload_breakdown` JSONL record to `.orchestrator/milestones/<Mxxx>/execution-log.jsonl` after payload assembly and the payload itself is byte-identical to the pre-instrumentation payload (SC-1, SC-6, C1).
  - Check: `bash scripts/verify/m019-p01-zero-token-growth.sh`

- `scripts/dispatch/dispatch-interface.sh` emits exactly one `dispatch_usage` JSONL record after backend invocation, carrying `estimated_cost_usd`, `pricing_version`, and `source: "estimate"` (SC-1, SC-4).
  - Check: `bash scripts/verify/m019-p01-emitter-presence.sh`

- `scripts/knowledge/write-summary.sh` emits exactly one `unit_close` JSONL record at task, phase, and milestone granularity, and every emitted `unit_close` carries both a cost block (`estimated_cost_usd`, `pricing_version`) and a quality block (`verification_pass_rate`, `deviation_count`, `retry_count`) — records missing either block fail the schema validator (SC-2, SC-3, C2).
  - Check: `bash scripts/verify/m019-p01-emitter-presence.sh`

- `scripts/verify/m019-schema.sh` enforces `record_type` enum ({`payload_breakdown`, `dispatch_usage`, `unit_close`}), `source` enum ({`estimate`, `runtime`}), `granularity` enum ({`task`, `phase`, `milestone`}) on `unit_close`, mandatory cost+quality pairing on `unit_close`, and additivity — pre-M019 records still validate (SC-4, SC-10).
  - Check: `bash scripts/verify/m019-p01-source-enum.sh`

- When `.orchestrator/config/pricing.yml` is renamed away mid-run (or `last_updated` is older than 90 days), the dispatch emitter writes the record with `estimated_cost_usd: null` + a `pricing_warning` field and exits 0 — dispatch never aborts (SC-5, C4).
  - Check: `bash scripts/verify/m019-p01-pricing-degradation.sh`

- Pre-M019 `execution-log.jsonl` fixtures replay cleanly against every modified consumer (`scripts/state/derive-phase.sh` and any other current log consumer keeps working) (SC-10, C3).
  - Check: `bash scripts/verify/m019-p01-additive-compat.sh`

- No emitter record exists in any post-[M011](../../../../milestones/M011/index.md) milestone's `execution-log.jsonl` with a timestamp earlier than P00 SUMMARY `completed_at: 2026-04-18T02:21:28Z` (SC-12, C9).
  - Check: `bash scripts/verify/m019-p01-no-pre-p00-emission.sh`

- Tier 1 records are greppable and aggregatable by a future rollup — demonstrated end-to-end by parsing ~10 fixture records and printing granularity-keyed totals, without shipping any new user-facing command (SC-7, US4).
  - Check: `bash scripts/verify/m019-p01-fixture-rollup.sh`

- Every P01-touched and P01-created `.sh` file is bash 3.2 compatible — no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>` (SC-9, C5).
  - Check: `bash scripts/verify/m019-p01-bash32-compat.sh`

- `bash scripts/verify/m019-p01-phase-suite.sh` orchestrates all eight P01 gates and exits 0 on green (SC-8).
  - Check: `bash scripts/verify/m019-p01-phase-suite.sh`

### Artifacts

- `scripts/lib/pricing.sh` (min 80 lines, contains "ORCH_PRICING_FILE")
- `scripts/dispatch/build-context.sh` (min 1000 lines, contains "payload_breakdown")
- `scripts/dispatch/dispatch-interface.sh` (min 200 lines, contains "dispatch_usage")
- `scripts/knowledge/write-summary.sh` (min 210 lines, contains "unit_close")
- `scripts/verify/m019-schema.sh` (min 80 lines, contains "record_type")
- `scripts/verify/m019-p01-emitter-presence.sh` (min 60 lines, contains "payload_breakdown")
- `scripts/verify/m019-p01-pricing-degradation.sh` (min 40 lines, contains "pricing_warning")
- `scripts/verify/m019-p01-source-enum.sh` (min 30 lines, contains "runtime")
- `scripts/verify/m019-p01-zero-token-growth.sh` (min 40 lines, contains "byte-identical")
- `scripts/verify/m019-p01-fixture-rollup.sh` (min 40 lines, contains "granularity")
- `scripts/verify/m019-p01-additive-compat.sh` (min 30 lines, contains "pre-M019")
- `scripts/verify/m019-p01-no-pre-p00-emission.sh` (min 30 lines, contains "2026-04-18T02:21:28Z")
- `scripts/verify/m019-p01-bash32-compat.sh` (min 40 lines, contains "declare -A")
- `scripts/verify/m019-p01-phase-suite.sh` (min 40 lines, contains "m019-p01")
- `tests/fixtures/m019-p01/` (directory with at least one pre-M019 execution-log.jsonl fixture and one post-M019 multi-record fixture)

### Key Links

- `scripts/dispatch/build-context.sh` -> `scripts/lib/pricing.sh` (emitter sources the pricing helper)
- `scripts/dispatch/dispatch-interface.sh` -> `scripts/lib/pricing.sh` (dispatch_usage uses rates)
- `scripts/knowledge/write-summary.sh` -> `m019-schema.sh` (cost+quality pairing validated at emit time)
- `scripts/verify/m019-p01-phase-suite.sh` -> `scripts/verify/m019-schema.sh` (orchestrated gate)
- `scripts/verify/m019-p01-phase-suite.sh` -> `scripts/verify/m019-p01-emitter-presence.sh` (orchestrated gate)
- `scripts/verify/m019-p01-phase-suite.sh` -> `scripts/verify/m019-p01-pricing-degradation.sh` (orchestrated gate)
- `scripts/verify/m019-p01-phase-suite.sh` -> `scripts/verify/m019-p01-source-enum.sh` (orchestrated gate)
- `scripts/verify/m019-p01-phase-suite.sh` -> `scripts/verify/m019-p01-zero-token-growth.sh` (orchestrated gate)
- `scripts/verify/m019-p01-phase-suite.sh` -> `scripts/verify/m019-p01-fixture-rollup.sh` (orchestrated gate)
- `scripts/verify/m019-p01-phase-suite.sh` -> `scripts/verify/m019-p01-additive-compat.sh` (orchestrated gate)
- `scripts/verify/m019-p01-phase-suite.sh` -> `scripts/verify/m019-p01-no-pre-p00-emission.sh` (orchestrated gate)
- `scripts/verify/m019-p01-phase-suite.sh` -> `scripts/verify/m019-p01-bash32-compat.sh` (orchestrated gate)

## Tasks

### T01: pricing.sh helper + m019-schema.sh validator

See [`.orchestrator/milestones/M019/phases/P01/tasks/T01-PLAN.md`](../../../../milestones/M019/phases/P01/tasks/T01-PLAN.md).

### T02: payload_breakdown emitter in build-context.sh

See [`.orchestrator/milestones/M019/phases/P01/tasks/T02-PLAN.md`](../../../../milestones/M019/phases/P01/tasks/T02-PLAN.md).

### T03: dispatch_usage emitter + pricing degradation in dispatch-interface.sh

See [`.orchestrator/milestones/M019/phases/P01/tasks/T03-PLAN.md`](../../../../milestones/M019/phases/P01/tasks/T03-PLAN.md).

### T04: unit_close emitter with Goodhart pairing in write-summary.sh

See [`.orchestrator/milestones/M019/phases/P01/tasks/T04-PLAN.md`](../../../../milestones/M019/phases/P01/tasks/T04-PLAN.md).

### T05: Fixtures + per-gate verify scripts

See [`.orchestrator/milestones/M019/phases/P01/tasks/T05-PLAN.md`](../../../../milestones/M019/phases/P01/tasks/T05-PLAN.md).

### T06: Phase-suite orchestrator + fixture-rollup demo + bash32-compat + no-pre-p00-emission

See [`.orchestrator/milestones/M019/phases/P01/tasks/T06-PLAN.md`](../../../../milestones/M019/phases/P01/tasks/T06-PLAN.md).

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04 ──► T05 ──► T06
```

Strict linear chain. Each task adds one emission boundary or one verification gate; downstream tasks depend on the lib + schema from T01 and the emitters from T02/T03/T04. T05 lays the fixtures and per-gate scripts; T06 closes the suite orchestrator and the cross-log SC-12 ordering gate.

## Files Likely Touched

- `scripts/lib/pricing.sh` (create)
- `scripts/dispatch/build-context.sh` (modify — append emit call after payload assembly, outside payload)
- `scripts/dispatch/dispatch-interface.sh` (modify — append emit call after adapter subprocess returns)
- `scripts/knowledge/write-summary.sh` (modify — append unit_close emission after summary write)
- `scripts/verify/m019-schema.sh` (create)
- `scripts/verify/m019-p01-emitter-presence.sh` (create)
- `scripts/verify/m019-p01-pricing-degradation.sh` (create)
- `scripts/verify/m019-p01-source-enum.sh` (create)
- `scripts/verify/m019-p01-zero-token-growth.sh` (create)
- `scripts/verify/m019-p01-fixture-rollup.sh` (create)
- `scripts/verify/m019-p01-additive-compat.sh` (create)
- `scripts/verify/m019-p01-no-pre-p00-emission.sh` (create)
- `scripts/verify/m019-p01-bash32-compat.sh` (create)
- `scripts/verify/m019-p01-phase-suite.sh` (create)
- `tests/fixtures/m019-p01/pre-m019-execution-log.jsonl` (create)
- `tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl` (create)
- `tests/fixtures/m019-p01/fixture-milestone/` (create — minimal milestone dir for end-to-end emitter fixture)
