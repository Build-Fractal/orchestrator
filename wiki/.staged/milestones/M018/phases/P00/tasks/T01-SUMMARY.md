---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P00"
milestone: "M018"
provides:
  - "dispatch_usage emitter parity machinery -- co-located build-context emission, emission_point disambiguator field, parity verifier script"
requires:
  - "MEM019/P01 emitter contract, scripts/lib/pricing.sh, scripts/dispatch/build-context.sh _bc_emit_payload_breakdown"
affects:
  - "scripts/dispatch/build-context.sh, scripts/dispatch/dispatch-interface.sh, scripts/verify/m019-p01-emitter-presence.sh"
key_files:
  - "scripts/dispatch/build-context.sh,scripts/dispatch/dispatch-interface.sh,scripts/verify/m018-p00-emitter-parity.sh,scripts/verify/m019-p01-emitter-presence.sh"
key_decisions:
  - "Option-1 co-location chosen over routing through dispatch-interface (lowest-touch; guarantees parity by construction); emission_point field is additive per CON-5; build-context co-located emit uses backend="" since no adapter selected at payload-build time"
patterns_established:
  - "MEM004 carve-out reused for co-located emit (pipes/awk in dispatch-internal emitter); CON-5 additive field shape; AD-19 single-script-file verifier with per-log grep + awk timestamp window"
drill_down_paths:
  - ".orchestrator/scratch/m018-telemetry-probe-report.txt -- baseline 169 vs 2 metrics; .orchestrator/milestones/M018/phases/P00/tasks/T01-PAYLOAD.md -- task brief"
duration: "45"
verification_result: "pass"
completed_at: "2026-04-27T21:02:26Z"
---

Investigated the 1.2% dispatch_usage / payload_breakdown parity ratio surfaced by the M018 telemetry probe (169 payload_breakdown vs 2 dispatch_usage across all milestones). Read build-context.sh and dispatch-interface.sh end-to-end and confirmed the structural cause: build-context.sh runs on every dispatched task to assemble the payload, but the runtime's native dispatch (Claude Code Agent tool) consumes the payload directly without routing through dispatch-interface.sh, so _di_emit_dispatch_usage fires only on the small subset of paths that exercise the dispatch interface wrapper (M019/P01 fixture runs and a couple of stub-backend probes).

Landed the lowest-touch fix from the task plan: a co-located dispatch_usage emit inside _bc_emit_payload_breakdown, stamped with emission_point="build-context" to disambiguate from full-pipeline dispatch-interface emissions (now stamped emission_point="dispatch-interface"). The emission_point field is additive per CON-5 -- pre-M018 records remain valid and the [M019](../../../../../milestones/M019/index.md) schema validator accepts records both with and without it. The co-located emitter reuses the same pricing pipeline used by dispatch-interface (pricing_estimate_cost_usd / pricing_warning_reason / pricing_last_updated), so degradation paths (pricing.yml missing or stale) are handled identically: cost=null + pricing_warning. Output tokens are emitted as 0 because real output is unknown at payload-build time.

Shipped scripts/verify/m018-p00-emitter-parity.sh as the new gate. It scans .orchestrator/milestones/*/execution-log.jsonl, sorts both record types by timestamp, takes the most recent N payload_breakdown records (--window N, default 20), counts dispatch_usage records whose timestamp >= the lower-bound payload_breakdown timestamp, and computes parity = floor(100 * du / pb). Threshold is configurable via --threshold P (default 95). Single-script-file shape per AD-19, bash 3.2 compatible, no compound chains > 2.

Verification outcomes (all pass): m019-schema.sh on real M019/[M027](../../../../../milestones/M027/index.md) logs, m019-p01-emitter-presence.sh (updated to expect 2 dispatch_usage per fixture run -- one per emission_point), m019-p01-additive-compat.sh, m019-p01-source-enum.sh, m019-p01-pricing-degradation.sh, m019-p01-zero-token-growth.sh (byte-identical stdout, delta=0), m019-p01-no-pre-p00-emission.sh, and the new m018-p00-emitter-parity.sh smoke run (--window 5 --threshold 0 returns PASS as expected; the same call with --threshold 95 correctly FAILs against the historical log, confirming the failure path). The 95%-over-20-sample assertion is T03's job; T01 ships the machinery and the no-regression proof.
