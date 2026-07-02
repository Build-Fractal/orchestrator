---
schema_version: "1.0"
type: evaluation
milestone: "M046"
feature_ref: "047-auto-v2b-unified-serial"
feature_spec: "specs/047-auto-v2b-unified-serial/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-07-02"
discuss_required: true
metrics_source: "raw_spec"
---

# M046 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: /orchestrator-discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 4 |
| Acceptance scenarios | 15 |
| Functional requirements | 17 |
| Estimated SDD flows | 2+ |

## Reasoning

M046 (auto-v2b unified serial core) is decisively Tier C. It comprises multiple distinct SDD flows requiring roadmap decomposition and cross-phase coordination: (1) a unified classify-first entry that collapses `orchestrator:do` into `orchestrator:auto`; (2) a breaking deprecate-and-merge migration of `orchestrator:do` with an installed-consumer surface; (3) a serial `--unattended` safety envelope with several independently-testable, safety-critical sub-mechanisms (in-segment budget watchdog + SIGKILL, reserve-then-spend accounting, default-DENY PreToolUse path+tool+MCP allowlist hook, thrash-terminal, fail-closed caps, marker-contract hardening); and (4) a runtime-degrade path. 17 FRs, 12 SCs (three of them non-stubbed milestone-blocking safety gates), 4 user stories, 15 acceptance scenarios. The safety-critical, reputational nature of unattended overnight execution plus the breaking migration mandate full orchestration (autonomous dispatch, crash recovery, knowledge consolidation) and a required discussion gate before roadmap.

Discussion is a hard gate (`discuss_required: true`): the spec passed a Full-intensity conversus strict gate "proceed with conditions" — the 7 MIT amendments are applied, but several open questions (#Q-1..#Q-7) carry load-bearing plan-phase decisions (hook-install portability, cost-read cadence as an SC-3 precondition, second-gate substrate, precision-floor anti-circularity protocol) that discussion must frame before roadmap decomposition.

## Complexity Factors

- **Breaking change** — `orchestrator:do` deprecate-merge with installed-consumer migration (do-shim, `orchestrator:update` re-stage path).
- **Safety-critical unattended execution** — three non-stubbed milestone-blocking gates (SC-3 in-segment SIGKILL, SC-5 write+tool+MCP scope, SC-9 full marker exit-code contract) enforcing the M045-P01 "prove it live" discipline.
- **Substrate inheritance** — builds on the M045 process-fresh driver (D015); CON-2 limits `auto-loop.sh` to exactly one additive marker write.
- **Load-bearing open primitives** — PreToolUse deny-hook portability (#Q-1), M019 cost-read cadence (#Q-4, SC-3 precondition), classifier precision floor (#Q-6).
- **Scope carve-outs** — fan-out coordinator (v2c-fanout, P00 N=3 concurrency evidence banked) and Posture-3 Stop-hook (own slice) are explicit Non-Goals; discussion must hold that boundary.
