---
schema_version: "1.0"
type: evaluation
milestone: "M003"
feature_ref: "003-migration-tool"
feature_spec: "specs/003-migration-tool/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-09T00:00:00Z"
---

# M003 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: speckit.orchestrator.discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 8 |
| Acceptance scenarios | 30 |
| Functional requirements | 20 |
| Estimated SDD flows | 4-6 |

## Reasoning

This spec defines a migration tool (`/speckit.orchestrator.migrate`) that must handle three distinct source formats (GSD2 with SQLite, GSD v1 with flat files, standard spec-kit), each requiring its own adapter with different parsing logic, data richness levels, and output mappings. The work spans multiple orthogonal subsystems: a pluggable adapter architecture, a knowledge migration pipeline with category mapping and supersession chain preservation, a decision register converter, a requirements migration path, a milestone history tiering algorithm, telemetry aggregation, and a comprehensive validation/reporting system.

With 8 user stories, 30 acceptance scenarios, 20 functional requirements, and 8 enumerated edge cases, this work requires at minimum 4 complete SDD flows (specify-clarify-plan-tasks-implement cycles), placing it firmly in Tier C territory. No single SDD flow can encompass both the GSD2 SQLite adapter and the knowledge migration file generation system, let alone the milestone tiering algorithm, the two additional source adapters, and the validation/reporting infrastructure.

Cross-phase dependencies are significant: the adapter architecture (FR-200) must exist before any source-specific adapter can be built; knowledge migration (US3) must precede milestone tiering (US2) because tiering depends on knowledge entries surviving independently of their source milestone tier (FR-219); and the migration report (US8) depends on all other subsystems being complete to report accurate statistics.

The estimated effort exceeds 8 hours of agent work across 10+ context windows, with complex dependency graphs between phases and the need for boundary maps at adapter interfaces.

## Complexity Factors

- **Three source format adapters**: GSD2 (SQLite + JSON + filesystem), GSD v1 (flat markdown), spec-kit (specs directory) each need distinct parsing, validation, and mapping logic
- **SQLite dependency**: GSD2 adapter reads from `gsd.db` with fallback to `memories-snapshot.json`, requiring dual data access paths and preference logic
- **Supersession chain preservation**: Knowledge entries form directed graphs via `superseded_by` pointers; migration must reconstruct these chains and route entries to either active or archive directories
- **Milestone tiering algorithm**: 43 milestones must be classified into 4 tiers (active/recent/historical/archived) with configurable boundaries and progressive disclosure via `drill_down_paths`
- **Active milestone conversion**: In-progress work (partial plans, active tasks) must be converted to orchestrator format while preserving current state
- **Cross-subsystem references**: Knowledge entries reference decisions, requirements reference milestones, milestones reference knowledge -- broken references must be detected and reported
- **Idempotency with collision detection**: Re-running migration requires `--merge`, `--force`, or `--abort` semantics with ID collision handling
- **Validation completeness**: 30 acceptance scenarios define a large verification surface; the migration report must capture anomalies, skipped items, and inferred values
