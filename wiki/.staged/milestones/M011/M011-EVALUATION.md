---
schema_version: "1.0"
type: evaluation
milestone: "M011"
feature_ref: "011-spec-management"
feature_spec: "specs/011-spec-management/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-16T12:00:00Z"
---

# M011 Evaluation

## Classification

- **Tier**: C
- **Source**: auto (analysis)
- **Next command**: orchestrator:discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 5 |
| Acceptance scenarios | 17 |
| Functional requirements | 16 |
| Estimated SDD flows | 3+ |

## Reasoning

M011 Spec Management requires multiple complete SDD flows across distinct subsystems. The work spans four concerns — spec storage and chunking (new knowledge category infrastructure), ingest pipeline (markdown parsing and classification), orchestrator integration (scope-filter and dispatch payload wiring), and intensity-aware roadmap generation (reusing existing engine with new input source). Each concern requires its own planning, task decomposition, execution, and verification cycle.

The 16 functional requirements distribute across these concerns with cross-cutting dependencies: the ingest pipeline (FR-001 through FR-008) produces chunks that scope filtering (FR-009, FR-010) and roadmap generation (FR-011, FR-012) consume. This creates boundary maps between phases that require explicit coordination — a defining characteristic of Tier C projects.

Additionally, M011 integrates with 4+ existing subsystems (knowledge scripts from [M002](../../milestones/M002/index.md), graph traversal from [M007](../../milestones/M007/index.md), scope-filter and dispatch from [M008](../../milestones/M008/index.md), intensity engine from M008), making the integration surface area significant.

## Complexity Factors

- **Cross-subsystem integration**: Touches knowledge scripts, graph traversal, scope filtering, build-context, intensity engine, and the evaluate/roadmap command chain
- **New knowledge category family**: `spec/*` categories require validation that existing infrastructure (create-entry, supersede-entry, resolve-entries, traverse-graph, rebuild-index) handles the new prefix correctly
- **Idempotency requirements**: Ingest must be idempotent (FR-007) and re-ingest must use supersession (FR-008) — both need careful state management
- **Three interaction modes**: Intensity-aware roadmap generation (FR-012) requires testing directive, semi-directive, and collaborative flows
- **Versioning with impact propagation**: Spec changes must flag affected phases (FR-016), requiring traceability from chunks through scope tags to phase plans
