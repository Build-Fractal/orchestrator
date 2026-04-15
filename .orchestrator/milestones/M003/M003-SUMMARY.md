---
schema_version: "1.0"
type: milestone-summary
id: "M003"
parent: "003-migration-tool"
milestone: "M003"
provides:
  - "Migration tool for GSD2/GSD v1/spec-kit → orchestrator format: adapter interface (P01), knowledge/decisions/requirements/milestone transforms (P02-P04), GSD v1 + spec-kit adapters (P05), end-to-end CLI with idempotency + reporting (P06). Refit (P07-P08) aligns migration output with M007 knowledge graph and M008 5-rule state resolver: resolver-wired target root, dual-root idempotency, post-migration graph rebuild, AD-13/14/15 documented, synthetic + live E2E validation with 8 AD-19-safe verify scripts + integration test (all green)."
requires:
  - "from:M007 what:scripts/knowledge/rebuild-index.sh + knowledge.db graph + detect-overlap.sh; from:M008 what:scripts/state/resolve-root.sh (5-rule resolver, --absolute); from:spec-kit what:commands registration + CLI contract"
affects:
  - "M009 (recipe packaging can assume .orchestrator/ default target); future milestone-management work"
key_files:
  - "scripts/migrate/migrate.sh,scripts/migrate/adapter-interface.sh,scripts/migrate/adapters/gsd2.sh,scripts/migrate/adapters/gsd1.sh,scripts/migrate/adapters/speckit.sh,scripts/migrate/transform/knowledge.sh,scripts/migrate/transform/knowledge-index.sh,scripts/migrate/transform/decisions.sh,scripts/migrate/transform/requirements.sh,scripts/migrate/transform/milestone-tiering.sh,scripts/migrate/transform/active-milestone.sh,scripts/migrate/transform/milestone-rollup.sh,scripts/migrate/transform/telemetry-aggregator.sh,scripts/migrate/transform/report.sh,scripts/migrate/lib/idempotency.sh,scripts/migrate/lib/sqlite-reader.sh,scripts/migrate/lib/json-fallback.sh,scripts/migrate/lib/category-mapper.sh,scripts/migrate/lib/supersession-chain.sh,scripts/migrate/lib/scope-tag.sh,scripts/migrate/lib/decision-numbering.sh,scripts/migrate/lib/category-inferrer.sh,scripts/migrate/lib/error-handler.sh,scripts/orchestrator/status.sh,commands/migrate.md,tests/fixtures/m003-p08-gsd-minimal/,tests/integration/test-m003-e2e-migration.sh"
key_decisions:
  - "AD-13 (resolver-driven target root), AD-14 (relates_to empty on migrate; post-migration detect-overlap.sh enriches), AD-15 (command-naming deferral), AD-19 (single-script Check invocations, no compound bash)"
patterns_established:
  - "adapter-interface extract() contract for source-format pluggability; tiered milestone layout (active/recent/historical/archived); three-tier root resolution (flag→env→resolver) as standard CLI contract; dual-layout state probe for idempotency; warn-but-continue post-pipeline rebuild; progressive-disclosure ADR documentation in command docs; Tier-1 static+behavioral verify-per-truth with single-file AD-19 invocations; skip-gracefully integration-test pattern; strict/warn split for synthetic-vs-live validation; deterministic SQLite fixtures under 50KB (PRAGMA page_size=1024 + hard-coded ISO-8601); .gitignore negation for test fixtures sharing ignored names"
drill_down_paths:
  - ".specify/orchestrator/milestones/M003/phases/P01/P01-SUMMARY.md,.specify/orchestrator/milestones/M003/phases/P02/P02-SUMMARY.md,.specify/orchestrator/milestones/M003/phases/P03/P03-SUMMARY.md,.specify/orchestrator/milestones/M003/phases/P04/P04-SUMMARY.md,.specify/orchestrator/milestones/M003/phases/P05/P05-SUMMARY.md,.specify/orchestrator/milestones/M003/phases/P06/P06-SUMMARY.md,.specify/orchestrator/milestones/M003/phases/P07/P07-SUMMARY.md,.specify/orchestrator/milestones/M003/phases/P08/P08-SUMMARY.md"
duration: "initial build 2026-04-09 + refit 2026-04-14/15"
verification_result: "pass"
completed_at: "2026-04-15T04:51:37Z"
observability_surfaces:
  - "MIGRATION-REPORT.md per-section counts; EXECUTION-HISTORY.md per-milestone telemetry"
---

M003 Migration Tool milestone complete. Initial build (P01-P06, commit ad3da8a 2026-04-09) delivered the end-to-end migration pipeline: adapter interface with pluggable source formats (GSD2/GSD v1/spec-kit), per-artifact transforms (knowledge, decisions, requirements, milestones with tiering), and CLI with idempotency + reporting. After M007 (knowledge graph) and M008 (standalone multi-runtime + 5-rule state resolver) landed, a delta audit surfaced three drift points: hardcoded .specify/orchestrator/ paths, unpopulated graph database, single-layout idempotency probe. P07 refit wired migrate.sh to resolve-root.sh --absolute, dropped hardcoded paths in three transforms, added dual-root idempotency probing, wired rebuild-index.sh as final pipeline stage, and documented AD-13/14/15 in commands/migrate.md. P08 validated end-to-end via deterministic synthetic GSD2 fixture (primary) and live lakeledger (secondary, skip-gracefully), new scripts/orchestrator/status.sh CLI wrapper making the roadmap demo sentence literally executable, 8 AD-19-safe verify scripts, and a two-pass integration test — all green. Surfaced and fixed one latent P02 bug (missing content_hash frontmatter) during refit. Retroactive phase summaries added for P01-P06 (originally delivered before phase-summary machinery) based on roadmap Revision Note + commit ad3da8a. Migration pipeline now produces resolver-wired output, populates the M007 graph database, and participates in graph traversal — ready for M009 recipe packaging and M010 cloud dispatch.
