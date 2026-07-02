---
schema_version: "1.0"
type: evaluation
milestone: "M045"
feature_ref: "046-self-continuing-auto"
feature_spec: "specs/046-self-continuing-auto/spec.md"
tier: "C"
tier_source: "override"
created_at: "2026-07-01"
---

# M045 Evaluation

## Classification

- **Tier**: C
- **Source**: override (auto-classification leaned Tier B on the strict single-SDD-flow rule; operator confirmed Tier C for the reasons below)
- **Next command**: `/orchestrator-discuss`

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 3 |
| Acceptance scenarios | 8 |
| Functional requirements | 10 |
| Estimated SDD flows | 1 (decomposed across ~3–4 phases with a gating viability spike) |

metrics_source: raw_spec

## Reasoning

The feature is deliberately minimal — a single coherent SDD flow confined to the
`auto-loop.sh` context-rotation exit branch (CON-3), which by the strict
2+-SDD-flow rule would classify Tier B. It is classified **Tier C** by operator
decision for three substantive reasons:

1. **Cross-phase decision coordination.** SC-6 is a milestone-blocking viability
   spike whose outcome gates whether the rest of the FR/SC surface is worth
   building as scoped, with CON-5 routing a negative outcome out to `M-auto-v2b`.
   That is a conditional dependency graph across phases — the coordination Tier C
   exists to manage — not a flat sequential task list.
2. **Autonomous-mode dogfood.** The milestone hardens the autonomous loop itself;
   running it under Tier C full orchestration (`orchestrator:auto`, crash
   recovery, knowledge consolidation) exercises the very machinery it improves.
3. **Arc membership.** M045 is the first slice of the Auto-v2 arc (proposal
   §Discussion Outcomes D1); the parent arc is Tier C, and v2b builds directly on
   this milestone's proven base.

## Complexity Factors

- **Gating spike (SC-6 / #Q-1)**: the load-bearing risk (does in-session
  `ScheduleWakeup` re-entry actually relieve context?) must be validated by a
  real, non-stubbed multi-rotation Tier C run before later phases lock — this is
  the highest-priority, earliest plan-phase task.
- **CC-only primitive**: `ScheduleWakeup`/self-paced `/loop` are Claude-Code
  native; FR-7/FR-8 require capability-detected graceful degradation to legacy
  behavior on Codex/Cursor (ties to M009).
- **Silent-failure surface**: three-plus distinct silent-failure modes
  (capability-absent, un-armed, directive-emitted-but-unregistered per FR-10,
  thrash-to-cap per FR-5) each need explicit observability + fixtures.
- **Confined blast radius**: CON-3 limits the change set to the rotation-exit
  branch + arming surface; dispatch/verify/budget/stuck scripts are reused
  unchanged, which bounds the coordination cost despite the Tier C label.
- **Hard dependency**: M028 hook portability (consumer-project dispatch parity
  across the re-entry boundary).
