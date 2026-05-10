---
schema_version: "1.0"
type: phase-plan
phase: "P00"
milestone: "M018"
goal: "Close the dispatch_usage emitter coverage gap and ship a section-distribution probe so SC-9's reduction threshold is empirically calibrated before any tier code lands."
demo_sentence: "Operator runs the patched dispatch_usage emitter against a 20-dispatch sample and reports parity ≥ 95% with payload_breakdown; runs scripts/diagnostics/m018-section-distribution.sh and sees per-section size distribution + per-tier achievable-savings ceilings with confidence intervals; reads spec.md SC-9 and finds an empirically-pinned threshold replacing the placeholder."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- The `dispatch_usage` JSONL emitter fires on real dispatches at parity ≥ 95% with `payload_breakdown` over a 20-dispatch sample.
  - Check: `bash scripts/verify/m018-p00-fixture-replay.sh --iterations 20 --threshold 95`
- `scripts/diagnostics/m018-section-distribution.sh` produces per-section size distribution (mean, p50, p95, max) AND per-tier achievable-savings ceilings with confidence intervals (low/high bounds named explicitly).
  - Check: `bash scripts/verify/m018-p00-probe-output.sh`
- `specs/030-context-compression-layer/spec.md` SC-9 is amended with an empirically-grounded threshold derived from the probe — not the original "≥ 25%" placeholder.
  - Check: `bash scripts/verify/m018-p00-sc9-calibrated.sh`
- Phase summary records the parity result, the probe-derived threshold value, and the spec amendment commit/diff reference.
  - Check: `bash scripts/verify/m018-p00-summary-complete.sh`

### Artifacts

- `scripts/diagnostics/m018-section-distribution.sh` (min 80 lines, contains "savings_ceiling")
- `scripts/verify/m018-p00-emitter-parity.sh` (min 40 lines, contains "parity")
- `scripts/verify/m018-p00-probe-output.sh` (min 20 lines, contains "savings_ceiling")
- `scripts/verify/m018-p00-sc9-calibrated.sh` (min 20 lines, contains "SC-9")
- `scripts/verify/m018-p00-summary-complete.sh` (min 20 lines, contains "parity")
- [`.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md`](../../../../milestones/M018/phases/P00/P00-SUMMARY.md) (min 40 lines, contains "parity")

### Key Links

- [`.orchestrator/milestones/M018/phases/P00/P00-PLAN.md`](../../../../milestones/M018/phases/P00/P00-PLAN.md) → [`.orchestrator/milestones/M018/M018-ROADMAP.md`](../../../../milestones/M018/M018-ROADMAP.md)
- [`.orchestrator/milestones/M018/phases/P00/P00-PLAN.md`](../../../../milestones/M018/phases/P00/P00-PLAN.md) → `specs/030-context-compression-layer/spec.md`
- [`.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md`](../../../../milestones/M018/phases/P00/P00-SUMMARY.md) → `scripts/diagnostics/m018-section-distribution.sh`
- [`.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md`](../../../../milestones/M018/phases/P00/P00-SUMMARY.md) → `scripts/verify/m018-p00-emitter-parity.sh`

## Tasks

### T01: Diagnose and patch the dispatch_usage emitter coverage gap

See [`.orchestrator/milestones/M018/phases/P00/tasks/T01-PLAN.md`](../../../../milestones/M018/phases/P00/tasks/T01-PLAN.md).

### T02: Section-distribution probe with per-tier savings-ceiling estimator

See [`.orchestrator/milestones/M018/phases/P00/tasks/T02-PLAN.md`](../../../../milestones/M018/phases/P00/tasks/T02-PLAN.md).

### T03: Calibrate SC-9 threshold and amend spec

See [`.orchestrator/milestones/M018/phases/P00/tasks/T03-PLAN.md`](../../../../milestones/M018/phases/P00/tasks/T03-PLAN.md).

## Task Dependencies

```
T01 ──► T03
T02 ──► T03
```

T01 (emitter fix) and T02 (probe) are independent — T02 only reads existing `payload_breakdown` records and does not touch the emitter path. They can run in parallel. T03 consumes both: it runs T01's parity check against a 20-dispatch sample (collected after T01 lands), runs T02's probe to derive the SC-9 threshold, then `--amend`s the spec and writes P00-SUMMARY.md.

## Files Likely Touched

- `scripts/dispatch/dispatch-interface.sh` (modify — T01 may relocate or extend `_di_emit_dispatch_usage` to close coverage gap)
- `scripts/dispatch/build-context.sh` (modify — T01 may co-locate dispatch_usage emission with payload_breakdown if that's the chosen fix shape)
- `scripts/diagnostics/m018-section-distribution.sh` (create — T02)
- `scripts/verify/m018-p00-emitter-parity.sh` (create — T01)
- `scripts/verify/m018-p00-probe-output.sh` (create — T02)
- `scripts/verify/m018-p00-sc9-calibrated.sh` (create — T03)
- `scripts/verify/m018-p00-summary-complete.sh` (create — T03)
- `specs/030-context-compression-layer/spec.md` (modify — T03 amends SC-9 with empirically-grounded threshold)
- [`.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md`](../../../../milestones/M018/phases/P00/P00-SUMMARY.md) (create — T03)
- `.orchestrator/scratch/m018-section-distribution-output.txt` (create — T03 archives probe-run output for audit trail)
