---
schema_version: "1.0"
type: evaluation
milestone: "M024"
feature_ref: "028-universal-intake-routing"
feature_spec: "specs/028-universal-intake-routing/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-25"
metrics_source: "raw_spec"
---

# M024 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: `orchestrator:discuss` (Tier C requires a finalized context draft before `roadmap` can run)

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 6 |
| Acceptance scenarios | 24 |
| Functional requirements | 15 |
| Success criteria | 8 |
| Non-goals | 6 |
| Constraints | 5 |
| Open questions (deferred to planning) | 7 |
| Estimated SDD flows | 2+ |

Note: `metrics_source: raw_spec` — the spec was newly authored and has not been ingested via `orchestrator:ingest` yet, so chunk-derived counts (`scripts/state/spec-metrics.sh`) reflect a prior milestone's ingest, not this spec. Counts above are from regex on `specs/028-universal-intake-routing/spec.md`. Re-running `evaluate --force` post-ingest is safe; the tier verdict will not change.

## Reasoning

M024 (Universal Intake & Routing) extends `orchestrator:evaluate` to be input-agnostic across five intake shapes (idea / paragraph / fragment / spec / empty + Q&A) and emits a single reviewable proposal artifact at `.orchestrator/intake/<id>/proposal.md` covering six routing axes (input shape, scope tier, decomposition, design gate, conversus gate, intensity). The spec carries 6 user stories (3 P1 / 3 P2), 15 functional requirements spanning router infrastructure, proposal-artifact shape, Q&A loop, revision flow, design-gate graceful degradation, conversus-adapter reuse, and an [M014](../../milestones/M014/index.md)↔M024 manifest-shape handshake (FR-15 per D017), and 24 Given/When/Then acceptance scenarios. Five upstream-milestone dependencies ([M020](../../milestones/M020/index.md) knowledge surface, M014 extended `orchestrator:specify`, [M016](../../milestones/M016/index.md) intensity engine, M011/P07 conversus adapter, [M013](../../milestones/M013/index.md) GitHub UAT-bug intake) and five downstream consumers ([M019](../../milestones/M019/index.md) T2+3, [M018](../../milestones/M018/index.md), M023, M009, M010) make this a load-bearing router that materially binds the rest of the forward roadmap.

This is unambiguously Tier C:

1. **Multiple SDD flows**: at minimum the router design itself (input-shape detector + proposal-artifact schema), the approval-gate / fast-path policy layer, the empty-input Q&A flow, the revision flow, the pre-M023 design-gate graceful-degradation branch, and the M014 handshake all need their own scaffold→author→gate→plan loops. They cannot collapse into a single context window without losing the per-axis evidence-citation discipline FR-13 commits to.
2. **Roadmap decomposition required**: 7 open questions (input-shape heuristics, intake-id allocation, Q&A source, decomposition depth, schema-version pinning, revision mutation semantics, auto-proceed config scope) are explicitly deferred to plan-phase, signaling that `discuss` must finalize them before the roadmap can be drawn. Single-phase decomposition cannot answer these without becoming a planning monolith.
3. **Cross-milestone coordination**: D016 promoted M024 specifically because downstream milestones (M019 T2+3, M018, M023, M009, M010) depend on a shipped router. The dogfood posture in CLAUDE.md ("M024 ships post-M020 so it dogfoods through remaining milestones") only works if M024 has phase-level instrumentation, which Tier C provides.
4. **Constitution III load**: the spec's defining commitment (proposal-as-artifact gates dispatch on Design Before Code) is itself a design-layer concern — running this as Tier B would short-circuit the very principle the milestone enforces.
5. **D016 explicit milestone status**: D016 named M024 as a committed milestone in the revised forward sequence. Tier-A or Tier-B classification would contradict the decision record without a new D-row superseding it.

## Complexity Factors

- **Multi-shape input detector** (FR-1) introduces a pre-tier classification layer that did not previously exist in `evaluate`. Heuristics are pinned only to the extent of #Q-1; the precise mechanical thresholds are plan-phase work.
- **Six-axis proposal artifact** (FR-2) is a new on-disk contract whose frontmatter shape is constrained from two sides simultaneously: D017's FR-7/FR-15 M014-manifest superset and downstream consumption by M018/M019/M023. Schema-version pinning (#Q-5) is a coordination decision, not a technical one.
- **Four-condition fast-path** (FR-3) is a policy commitment that interacts with NG-6 (no autonomous approval bypass beyond degenerate path) — bounding the auto-proceed surface against later "always auto-approve" pressure is a discuss-phase commitment.
- **Pre-M023 graceful-degradation string** (FR-7) is byte-pinned for grep-stability, which means M023 has a forward dependency on the exact string M024 ships. This is a coordination cost paid by both milestones and worth explicit roadmap acknowledgment.
- **Reuse-over-rebuild posture** (FR-8 / FR-9 / NG-1 / NG-2) inherits all the contracts of the surfaces it consumes — M016 intensity invariants, M011/P07 adapter 0/1/2 exit-code contract, M026/D022 OSS-edition diagnostic shape, D019 universal TODO pre-flight. Plan-phase needs to enumerate every inherited invariant that this milestone is now jointly responsible for not breaking.
- **Knowledge-Layer Boundary (M024 ↔ M020)** is committed but the exact M020 query-surface API M024 reads against is still in flight per the remote-review notification (M020 wiring landed without `lib/query.sh` body). M024 plan-phase must verify M020 has shipped and stabilized before scoping FR-13 evidence citations.
- **Six-user-story phase shape**: the spec's Minimal Slice (US-1 + US-2 + US-3, all P1) suggests Phase 1 lands the paragraph + spec-backward-compat + fast-path triad as the dogfood loop. US-4 (Q&A) / US-5 (revise) / US-6 (design degradation) ride in Phase 2 per the spec's own slice declaration. Plan-phase will likely produce 3–4 phases.

## Constitution Check Summary

The spec materially touches Principles I (Context Minimization), II (Evidence Before Claims), III (Design Before Code, primary), VI (State On Disk Is Truth), and XIV (Surface Discipline — extends `evaluate` rather than introducing a new command, per D016 / CON-2). The Constitution Check section in the spec body documents each.

## Recommended Next Step

Run `orchestrator:discuss` to finalize the 7 open questions (#Q-1 through #Q-7) and produce the M024 context draft. Roadmap cannot proceed until the discuss-finalize gate has produced `M024-CONTEXT.md` with status `finalized`.
