---
schema_version: "1.0"
type: evaluation
milestone: "M005"
feature_ref: "005-hardening-integration-prep"
feature_spec: "specs/005-hardening-integration-prep/spec.md"
tier: "C"
tier_source: "manual"
created_at: "2026-04-10T23:00:00Z"
---

# M005 Evaluation

## Classification

- **Tier**: C
- **Source**: manual
- **Next command**: speckit.orchestrator.discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 6 |
| Acceptance scenarios | ~24 |
| Functional requirements | ~12 |
| Estimated SDD flows | 3 |

## Reasoning

This milestone hardens the M004 engine architecture across 6 functional domains: content-hash idempotency, cost transparency, pure transform extraction, agent instruction schema, gate verdict protocol, and conformance test expansion. While individually each domain is small (1-2 scripts each), the cross-cutting nature of hashing and cost tracking touches knowledge scripts, telemetry scripts, and the execution log schema. The conformance expansion phase validates all prior work. Tier C is appropriate because of the breadth of changes across subsystems, even though no individual phase is high-risk.

## Complexity Factors

- **Cross-subsystem hash integration** — content hashing touches knowledge create/update/rebuild scripts (M002), dispatch result recording (M001), and the new engine (M004). Coordinating changes across 3 milestones' worth of scripts.
- **Schema evolution** — execution-log.jsonl gains cost_source field; knowledge frontmatter gains content_hash field. Both are additive but all consumers must be updated.
- **Verdict protocol design** — the gate verdict schema must be general enough for Conversus, budget gates, and quality checks without being so generic it loses meaning. Design risk.
- **4 independent phases** — P01-P04 can all run concurrently, which is efficient but means 4 parallel context tracks to coordinate.
