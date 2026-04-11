---
schema_version: "1.0"
type: evaluation
milestone: "M005"
feature_ref: "005-hardening-integration-prep"
feature_spec: "specs/005-hardening-integration-prep/spec.md"
tier: "C"
tier_source: "manual"
created_at: "2026-04-10T23:00:00Z"
updated_at: "2026-04-10T23:30:00Z"
---

# M005 Evaluation

## Classification

- **Tier**: C
- **Source**: manual
- **Next command**: speckit.orchestrator.discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 7 |
| Acceptance scenarios | ~28 |
| Functional requirements | ~22 |
| Estimated SDD flows | 4 |

## Reasoning

This milestone hardens the M004 engine architecture across 7 functional domains: content-hash idempotency, cost transparency, pure transform extraction, agent instruction schema, gate verdict protocol, autonomy permission generation, and conformance test expansion. While individually each domain is small (1-4 scripts each), the cross-cutting nature of hashing, cost tracking, and autonomy introspection touches knowledge scripts, telemetry scripts, lifecycle scripts, the execution log schema, and the auto command. The conformance expansion phase validates all prior work. Tier C is appropriate because of the breadth of changes across subsystems, even though no individual phase is high-risk.

## Complexity Factors

- **Cross-subsystem hash integration** — content hashing touches knowledge create/update/rebuild scripts (M002), dispatch result recording (M001), and the new engine (M004). Coordinating changes across 3 milestones' worth of scripts.
- **Schema evolution** — execution-log.jsonl gains cost_source field; knowledge frontmatter gains content_hash field; orchestrator-config.yml gains an `autonomy` section. All additive but all consumers must be updated.
- **Verdict protocol design** — the gate verdict schema must be general enough for Conversus, budget gates, and quality checks without being so generic it loses meaning. Design risk.
- **Project introspection breadth (P07)** — the autonomy generator must introspect package.json, Makefile, orchestrator-config, extension.yml, ~10 toolchain markers, and agent host directories in Bash 3.2 without jq. Breadth of inputs is the main complexity driver; each individual introspection source is mechanically simple. The MVP template in `templates/claude-settings.json` (commit `50f7098`) already covers FR-3/FR-4/FR-5/FR-9, so P07 focuses on FR-1/FR-2/FR-6/FR-7/FR-8/FR-10.
- **5 independent phases** — P01-P04 and P07 can all run concurrently, which is efficient but means 5 parallel context tracks to coordinate. P07 has no dependencies on other M005 phases, only on M004 P02 shared libraries.
