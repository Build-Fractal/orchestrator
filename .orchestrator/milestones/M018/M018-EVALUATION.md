---
schema_version: "1.0"
type: evaluation
milestone: "M018"
feature_ref: "030-context-compression-layer"
feature_spec: "specs/030-context-compression-layer/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-27T18:41:25Z"
metrics_source: "raw_spec"
---

# M018 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: `orchestrator:discuss`

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 9 |
| Acceptance scenarios | (encoded inline in user-story bodies; not separately counted) |
| Functional requirements | 21 |
| Estimated SDD flows | 2+ |

> Note: `scripts/state/spec-metrics.sh` reports `spec_chunks_present=true`, but the
> chunk counts (3 stories / 0 reqs / 10 acceptances) do not match this spec —
> they reflect a prior ingest of a different feature. Falling back to
> `metrics_source: raw_spec` (regex on `specs/030-context-compression-layer/spec.md`)
> for this evaluation.

## Reasoning

Scope is unambiguously Tier C:

1. **Phase decomposition is built into the spec.** The spec is structured as a
   four-tier pipeline (knowledge-aware filter, T1 microcompact, T2 snip,
   T3 auto-compact) plus a P0 measurement-prerequisites prelude. Each tier has
   independent verification ladders, telemetry contracts, and intensity-gating
   semantics. This is multiple complete SDD flows, not one.
2. **Cross-milestone integration surface.** M018 interacts with M019 (telemetry
   schema additions), M020 (knowledge `status:` field consumed by the filter),
   M027 (cost surfaces gain new savings fields), the dispatch interface
   (`build-context.sh`, `dispatch-interface.sh`), and the runtime adapter tree
   (CC / Codex CLI / Cursor parity per FR-13). Coordination across these
   dependencies requires a roadmap, not a single plan.
3. **Conversus gate is in scope.** FR-18 mandates that P01 (`compression-grammar.md`)
   passes a `--strict` conversus gate before P01 closes. The spec already went
   through one BLOCK-with-conditions cycle pre-evaluate; downstream phases will
   re-engage conversus.
4. **CLAUDE.md forward roadmap pre-classifies M018 as Tier C.** The forward
   sequence (`M014 (extended) → M020 → M024 → M019 Tier 2+3 → M018 → ...`)
   describes M018 as a full milestone with its own roadmap and phase plans.
5. **Empirical anchor exists.** The telemetry probe at
   `.orchestrator/scratch/m018-telemetry-probe-report.txt` (n=169 dispatches,
   mean=16,797 tok, p95=24,534) is the load-bearing measurement that informs
   tier ordering, threshold calibration (SC-9), and the P0 prerequisite. That
   anchor is what makes Tier C orchestration warranted — without it, this would
   be guesswork.

## Complexity Factors

- 4-tier compression pipeline with per-tier verification + intensity gates
  (Quick / Standard / Full).
- P0 measurement-prerequisites phase (FR-0a, FR-0b) blocks all tier code; this
  is itself a non-trivial sub-flow (emitter coverage probe + section
  distribution probe + threshold calibration).
- Schema additions to M019 telemetry (FR-10) and M027 cost surfaces (FR-11)
  must be back-compat additive — coordinated with two adjacent milestones.
- Multi-runtime parity requirement (FR-13) — zero-LLM tiers byte-identical
  across CC / Codex CLI / Cursor; T3 routes through the dispatch adapter.
- Conversus `--strict` gate on P01 grammar (FR-18) — gate failures halt the
  phase.
- Cache lifecycle (FR-16 cache-prune) and cache reuse (FR-6) — cache is a new
  durable artifact category that needs its own retention story.
- Three risk mitigations from the prior conversus cycle were folded into the
  spec body: RISK-1 emitter coverage (now FR-0a), RISK-2 SC-9 threshold
  empirical grounding (now FR-0b + SC-9 calibrated wording), RISK-3 US-7
  promoted P3 → P2 with eval harness participating in T3 verification ladder.
- Constitution Principle II (Evidence Before Claims) is load-bearing here —
  several FRs (eval harness, savings emitters, threshold calibration) exist
  specifically to keep M018 honest about whether compression is helping or
  hurting.
