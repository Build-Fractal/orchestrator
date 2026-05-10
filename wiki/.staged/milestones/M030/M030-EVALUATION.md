---
schema_version: "1.0"
type: evaluation
milestone: "M030"
feature_ref: "032-adaptive-model-selection"
feature_spec: "specs/032-adaptive-model-selection/spec.md"
tier: "C"
tier_source: "synthesized-2026-04-29"
created_at: "2026-04-29"
---

# M030 Evaluation

## Classification

- **Tier**: C
- **Source**: synthesized-2026-04-29 (post-discuss, post-amendment)
- **Next command**: `orchestrator:roadmap`

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 6 |
| Acceptance scenarios | 16 |
| Functional requirements | 19 |
| Estimated SDD flows | 7 (one per phase, see roadmap) |

## Reasoning

This evaluation file was synthesized after `orchestrator:discuss` completed because the upstream `orchestrator:specify` flow (run at Standard intensity 2026-04-30) did not produce an `M030-EVALUATION.md`. The tier classification is recovered post-hoc from the spec's surface area + the structural complexity surfaced during the conversus deliberation + the eight binding architectural decisions captured in `M030-CONTEXT.md` (D-A1 through D-A9).

Tier C is the unambiguous classification:

- **Multi-component implementation surface**: classifier (`scripts/dispatch/classify-task.sh`), routing table (`templates/model-routing.yml`), dispatch integration (amends `scripts/dispatch/dispatch-interface.sh`), shadow-comparison (`scripts/diagnostics/shadow-compare.sh`), three [M027](../../milestones/M027/index.md) surface extensions (`metrics-rollup.sh`, `efficiency-footer.sh`, `doctor.sh`), anomaly extension (`check-anomalies.sh`). 8+ scripts/templates touched across read and write surfaces.
- **Cross-phase dependency graph**: shadow-mode evidence (P02) gates live-routing flip (P04); kill switch (P03) is the operator panic button that must exist before live flip can ship safely; fixture corpus (P00) must commit before classifier (P01) by D-A4 mandate. This is not a flat sequential phase chain — there are real DAG edges with parallelization opportunities.
- **Required discussion gate**: 8 conversus advisory findings + 1 arbiter ruling required `orchestrator:discuss` to resolve. Discussion is mandatory for Tier C; Tier B does not gate on discuss-finalization. The fact that discussion meaningfully changed the spec's load-bearing design (D-A1 recharacterized the entire shadow-mode story) is itself Tier C evidence.
- **Programmatically-enforced safety mechanisms**: D-A2's flip-gate enforcement, D-A5's kill-switch precedence, D-A4's pre-implementation fixture corpus — these are operational-safety invariants that demand boundary maps and cross-cutting concerns to land coherently. Boundary maps are required for Tier C; optional for Tier B.

## Complexity Factors

- **Two-layer evidence story (D-A1)**: pre-flip classifier-calibration + post-flip regression-detection mesh (escalation + anomaly + kill switch). Each layer is a separate phase or set of phases.
- **Programmatic flip-gate enforcement (D-A2)**: operator config-knob alone is insufficient; `dispatch-interface.sh` must invoke `shadow-compare.sh` and refuse on `evidence_insufficient`. New code path with negative SC.
- **Partial-flip authorization (D-A3)**: 4-verdict shadow-compare output (`ready|partially_ready|block|evidence_insufficient`) plus per-class flip-activation in `dispatch-interface.sh` plus `partial_flip_active`/`withheld_classes` JSONL fields. New protocol surface.
- **Pre-implementation fixture corpus (D-A4)**: SC-10 mechanically requires the fixture file's commit timestamp to precede `classify-task.sh`'s first commit. This is a phase-ordering constraint, not just a documentation note.
- **Cost_rates SSOT (D-A6)**: new section in `templates/model-routing.yml` that downstream rollup/footer scripts consume. Affects FR-3, FR-15, FR-16, SC-8.
- **Symbolic-tier-with-per-runtime-resolution (CON-3)**: hardcoding model IDs in the routing table is forbidden. Adapter-translation surface in `scripts/dispatch/adapters/backend/*.sh`.
- **Additive JSONL schema invariant (CON-2/FR-19)**: every new field must be additive to preserve M027 byte-equality (SC-11). Cross-cuts P02, P03, P04, P05, P06.
- **Pre-launch CC-only posture**: M030 ships against Claude Code only. Codex CLI / Cursor adapters resolve any symbolic tier to `inherit` (no flag). Multi-runtime parity is M009 post-launch.
- **Sequencing assumption**: [M028](../../milestones/M028/index.md) (autonomous hardening v3) must close before M030 — M028 stabilizes autonomous runs whose JSONL feeds the shadow corpus.
