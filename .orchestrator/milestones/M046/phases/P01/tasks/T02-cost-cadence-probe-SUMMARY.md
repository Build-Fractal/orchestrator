---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M046"
provides:
  - "#Q-4 JSONL-half verdict: unit_close records readable at unit grain mid-segment (4/4 before loop_exit, 0.35-0.75s observe lag); unit_close estimated_cost_usd nullable via any-null propagation; recommended FR-7/FR-8 cost-source split in CADENCE-FINDINGS.md"
requires:
  - "scripts/lifecycle/auto-loop.sh (loop under test), scripts/knowledge/write-summary.sh (unit_close emitter), scripts/state/derive-phase.sh (fixture file-presence contract), .orchestrator/proposals/M-auto-v2b-P00-spike-evidence.md (total_cost_usd citation)"
affects:
  - "T03 (#Q-4 verdict), P04 (FR-7/FR-8 cost source)"
key_files:
  - ".orchestrator/milestones/M046/phases/P01/spike/cost/run-cadence-probe.sh, .orchestrator/milestones/M046/phases/P01/spike/cost/drive-segment.sh, .orchestrator/milestones/M046/phases/P01/spike/cost/cadence.jsonl, .orchestrator/milestones/M046/phases/P01/spike/cost/CADENCE-FINDINGS.md, .orchestrator/milestones/M046/phases/P01/spike/cost/fixture/milestones/MFIX/"
key_decisions:
  - "stub realized as driver-writes-summaries-via-real-write-summary.sh (auto-loop.sh has no --dispatch-stub flag; M031 seam is Tier-A-only in do-entry.sh); fixture root doubles as ORCHESTRATOR_ROOT so unit_close routes to fixture log; loop_exit stamped at exit-detection so post-exit drains classify conservatively; P02 seeded one labeled synthetic dispatch_usage to exercise cost aggregation with zero spend"
patterns_established:
  - "cadence-probe shape: background segment driver + 0.2s JSONL poller + per-record boundary-ordering analysis, all inside one wrapper script (AD-19)"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P01/spike/cost/"
duration: "1100s"
verification_result: "pass"
completed_at: "2026-07-13T15:31:32Z"
---

Drove the real auto-loop.sh single-step driver through 5 steps (READY, PHASE_COMPLETE, READY, PHASE_COMPLETE, MILESTONE_VALIDATING) against a throwaway 2-phase MFIX fixture in a scratch state root with stubbed dispatch and zero LLM spend; the 0.2s poller observed all 4 unit_close records (2 task-grain, 2 phase-grain) readable from the fixture execution-log.jsonl mid-segment, the last ~7s before loop_exit, proving the M019 JSONL emits at unit grain during a segment rather than only at exit; cost keys were always present per Goodhart pairing but estimated_cost_usd was null on all 4 unit_close records - including P02/T01 which had a non-null synthetic dispatch_usage contributor - because write-summary.sh any-null propagation nulls the sum when any same-unit contributor is null (build-context's dispatch_usage carried null under pricing no-rate for the empty stub model), and the step-G --cost value lands under the disjoint cost_estimated key after the unit_close; verdict for FR-7/FR-8: JSONL supplies mid-segment unit-grain cadence but only advisory nullable estimates, so FR-7 keeps the conservative reserve plus duration probe and reconciles per-unit only on non-null values, while FR-8 trues up the ledger per segment from the P00-proven claude -p total_cost_usd JSON result read at segment exit; probe run PASS 4/4 assertions and verify-only re-check PASS.
