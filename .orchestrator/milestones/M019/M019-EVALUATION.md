---
schema_version: "1.0"
type: evaluation
milestone: "M019"
feature_ref: "019-observability-metrics"
feature_spec: "specs/019-observability-metrics/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-17T22:35:00Z"
---

# M019 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: speckit.orchestrator.discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 5 |
| Acceptance scenarios | 24 |
| Functional requirements | 15 (expressed as SC-1..SC-15 success criteria) |
| Estimated SDD flows | 2 (P00 Opus 4.7 baseline adaptation + P01 Tier 1 emitter) |

## Reasoning

The spec declares two explicit phases with a strict P00-before-P01 ordering enforced by SC-12 (no Tier 1 record may be written until P00 verify suite is green). Each phase is its own SDD flow:

- **P00** is a sweep across dispatch-facing templates, intensity-gate prompt nudges, and payload structure (L1–L5 from the 4.7 articles synthesis). It has its own acceptance scenarios (US5), its own verify suite (`scripts/verify/m019-p00-payload-shape.sh`), and a regression-safety constraint (SC-13: pre-existing test suites must pass unchanged against adapted templates).
- **P01** is the emitter itself: schema design, dispatch-time `payload_breakdown` + `dispatch_usage` records, unit-close cost+quality pairs, pricing degradation path, source-field enum, fixture rollup. Six success criteria (SC-1..SC-6, SC-8) and four acceptance scenarios across US1–US4.

Multiple cross-cutting concerns (Goodhart guard via paired cost/quality emission, schema additivity for Tier 3 backend adapters, zero-token instrumentation constraint, Bash 3.2 compat) require boundary-map enforcement and cross-phase verification. The autonomous loop, knowledge consolidation, and crash recovery all become load-bearing.

## Complexity Factors

- **Strict cross-phase ordering**: SC-12 enforces "no emitter record before P00 green". A Tier B linear sequence couldn't enforce this without orchestrator state.
- **Schema-as-contract**: Records will be consumed by Tier 2 (rollup + `orchestrator:cost`) and Tier 3 (backend runtime-actuals adapters). Schema decisions made in P01 must survive without migration. Boundary maps catch this.
- **Goodhart pairing constraint**: Every `unit_close` must carry both cost and quality blocks. Verified by schema validator + the `m019-*.sh` verify suite. Easy to break under refactor — needs phase-boundary verification.
- **Zero-token instrumentation**: Emitter must run *outside* the agent's context. Build-context.sh emits the record after payload assembly, not inside it. Constraint cuts across dispatch + summary writer changes.
- **Pricing degradation path**: Missing/stale `config/pricing.yml` must degrade to `estimated_cost_usd: null` + `pricing_warning`, never abort. Standalone testable but cuts across every dispatch path.
- **Existing-consumer additivity**: SC-10 — pre-M019 `execution-log.jsonl` must remain valid; existing consumers (`derive-phase.sh` etc.) must not break. New fields additive only.
- **Opus 4.7 release adaptation**: P00 is documentation-driven (4.7 release notes; articles synthesis at `.orchestrator/scratch/articles-synthesis-2026-04-17.md`). Requires research-backed planning, not just mechanical decomposition.
- **Bounded scope discipline**: D009 explicitly flags scope creep risk (Tier 2/3 surfaces must stay out). Non-Goals section is long — boundary map enforcement matters.
