---
schema_version: "1.0"
type: roadmap
milestone: "M003"
feature_ref: "003-migration-tool"
feature_spec: "specs/003-migration-tool/spec.md"
vision: "Enable teams to adopt spec-kit-orchestrator without losing institutional knowledge by migrating project artifacts from GSD2, GSD v1, or standard spec-kit into orchestrator format via a single command."
tier: "C"
created_at: "2026-04-09T12:00:00Z"
updated_at: "2026-04-14T00:00:00Z"
---

## Revision Note (2026-04-14)

Phases P01–P06 were implemented in commit `ad3da8a` (2026-04-09). Since then
M007 (graph-enhanced knowledge) and M008 (standalone multi-runtime) landed and
introduced architectural surfaces that the migration code was not built against:
the 5-rule state resolver (`scripts/state/resolve-root.sh`), the knowledge graph
database rebuilt by `rebuild-index.sh` via `lib/graph-db.sh`, and the adaptive
intensity engine. A delta audit (see git log at this date) confirmed all P01–P06
scripts exist and are wired, but migration output still hardcodes
`.specify/orchestrator/` paths, always emits `relates_to: []`, and never
rebuilds the knowledge graph post-migration.

P01–P06 are therefore marked DONE with caveats. Two new refit phases (P07, P08)
close the drift and validate end-to-end against live GSD2 data. See
`M003-CONTEXT.md` addendum (AD-13..AD-15) for the architectural decisions.

## Phases

- [x] **P01**: Adapter Architecture & GSD2 Reader — "A developer can run the GSD2 adapter against a `.gsd/` directory and receive a normalized intermediate data structure containing knowledge entries, decisions, requirements, and milestone metadata extracted from `gsd.db` (or JSON fallback)."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces:
      - `scripts/migrate/adapter-interface.sh` — common adapter interface defining `extract()` contract and intermediate data format (JSON-like structured output with sections: knowledge, decisions, requirements, milestones, telemetry)
      - `scripts/migrate/adapters/gsd2.sh` — GSD2 adapter implementing `extract()` with SQLite-preferred, JSON-fallback data access
      - `scripts/migrate/lib/sqlite-reader.sh` — SQLite query helpers using `sqlite3` CLI (Bash 3.2 compatible)
      - `scripts/migrate/lib/json-fallback.sh` — JSON/filesystem fallback reader for when `gsd.db` is unavailable
      - Intermediate data format specification (documented in adapter-interface.sh header comments)
    - Consumes: nothing (foundation phase)

- [x] **P02**: Knowledge Migration Pipeline — "A developer can run the knowledge migrator against GSD2 intermediate data and find individual `knowledge/{category}/{MEM###}.md` detail files with full frontmatter, a complete `KNOWLEDGE-INDEX.md`, superseded entries archived in `knowledge/archive/{category}/`, and scope tags derived from source unit IDs."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/migrate/transform/knowledge.sh` — transforms intermediate knowledge data into individual detail files with YAML frontmatter (id, category, confidence, hit_count, created_at, last_verified, source_unit, migrated_from, supersedes, superseded_by, relates_to)
      - `scripts/migrate/transform/knowledge-index.sh` — generates `KNOWLEDGE-INDEX.md` from migrated detail files
      - `scripts/migrate/lib/category-mapper.sh` — maps GSD2 categories (gotcha, convention, pattern, infrastructure, global-rule) to orchestrator categories
      - `scripts/migrate/lib/supersession-chain.sh` — resolves supersession chains and routes entries to active vs. archive directories
      - `scripts/migrate/lib/scope-tag.sh` — derives orchestrator scope tags from source unit IDs (e.g., `M008/S02` to `[milestone:M008]`)
      - Output directory structure: `knowledge/{category}/{MEM###}.md`, `knowledge/archive/{category}/{MEM###}.md`, `KNOWLEDGE-INDEX.md`
    - Consumes:
      - `scripts/migrate/adapter-interface.sh` intermediate data format (from P01) — knowledge section with entries containing id, category, content, confidence, hit_count, timestamps, supersession pointers, source_unit_id

- [x] **P03**: Decision & Requirements Migration — "A developer can run the decision and requirements migrators and find a `DECISIONS.md` with all 153+ decisions in orchestrator table format (with supersession notes and migration boundary header), a `REQUIREMENTS.md` with active requirements including validation chains, and a `REQUIREMENTS-ARCHIVE.md` with satisfied requirements."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/migrate/transform/decisions.sh` — converts intermediate decision data to orchestrator DECISIONS.md format (table with ID, Scope, When, Decision, Choice, Rationale, Revisable columns; superseded decisions marked in Rationale; migration boundary header)
      - `scripts/migrate/transform/requirements.sh` — splits requirements into active (REQUIREMENTS.md) and satisfied (REQUIREMENTS-ARCHIVE.md) with validation chains (validated_by field)
      - `scripts/migrate/lib/decision-numbering.sh` — tracks max decision ID for numbering continuity (new decisions start from max+1)
      - Output files: `DECISIONS.md`, `REQUIREMENTS.md`, `REQUIREMENTS-ARCHIVE.md`
    - Consumes:
      - `scripts/migrate/adapter-interface.sh` intermediate data format (from P01) — decisions section (seq, id, when_context, scope, decision, choice, rationale, revisable, made_by, superseded_by) and requirements section (id, class, status, description, validation_status, validated_by)

- [x] **P04**: Milestone History Tiering — "A developer can run the milestone tiering algorithm against a 43-milestone GSD2 project and find the active milestone fully converted to orchestrator format (renumbered as M001), the last 3 completed milestones with summary-level preservation, all other completed milestones as single rollup documents with `drill_down_paths`, raw artifacts copied to `archive/gsd-raw/`, and an `EXECUTION-HISTORY.md` with per-milestone aggregated telemetry."
  - Risk: medium
  - Depends: P01, P02
  - Boundary Map:
    - Produces:
      - `scripts/migrate/transform/milestone-tiering.sh` — classifies milestones into active/recent/historical/archived tiers with configurable `--recent-count` boundary (default: 3)
      - `scripts/migrate/transform/active-milestone.sh` — converts in-progress milestone to orchestrator format (renumbered as M001): slices to phases, active tasks with state preserved, roadmap conversion with boundary maps
      - `scripts/migrate/transform/milestone-rollup.sh` — generates single rollup documents for historical milestones (title, vision, what shipped, key decisions, patterns established, gotchas, requirement coverage, drill_down_paths)
      - `scripts/migrate/transform/telemetry-aggregator.sh` — aggregates raw execution data into per-milestone profiles in EXECUTION-HISTORY.md (average cost, duration, success rate, cache hit rate, notable failures)
      - Output structure: `milestones/M001/` (full orchestrator format), `milestones/summaries/` (recent), `milestones/rollups/` (historical), `archive/gsd-raw/` (archived raw artifacts), `EXECUTION-HISTORY.md`
    - Consumes:
      - `scripts/migrate/adapter-interface.sh` intermediate data format (from P01) — milestones section (milestone metadata, slice/phase data, task states, verification evidence) and telemetry section (execution unit records)
      - Knowledge entry output (from P02) — FR-219 requires verifying that knowledge entries from historical milestones survive independently of their source milestone's tier; tiering must not orphan active knowledge entries

- [x] **P05**: GSD v1 & Spec-Kit Adapters — "A developer can run migration with `--source gsd1` against a `.planning/` directory and receive parsed knowledge entries (with inferred categories and 0.80 default confidence), decisions, and milestone summaries; or with `--source speckit` against a `specs/` directory and receive an orchestrator evaluation scaffolded from the existing spec."
  - Risk: low
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/migrate/adapters/gsd1.sh` — GSD v1 adapter implementing `extract()`: parses flat KNOWLEDGE.md (markdown list to entries), DECISIONS.md (markdown table to records), milestone directories to summaries; infers categories from content keywords, defaults confidence to 0.80
      - `scripts/migrate/adapters/speckit.sh` — spec-kit adapter implementing `extract()`: reads `specs/{NNN}/` directories, wraps spec.md as feature spec reference, preserves plan.md and tasks.md as reference material (not converted to orchestrator plans)
      - `scripts/migrate/lib/category-inferrer.sh` — keyword-based category inference for unstructured knowledge entries (GSD v1 has no category field)
    - Consumes:
      - `scripts/migrate/adapter-interface.sh` adapter contract (from P01) — the interface that adapters must implement

- [x] **P06**: Validation, Reporting & CLI — "A developer can run `/speckit.orchestrator.migrate --source gsd2 --path .gsd/` end-to-end and receive a `MIGRATION-REPORT.md` with source summary, per-artifact statistics, warnings for skipped/malformed entries, and recommended next steps; re-running migration without `--merge`/`--force` is blocked with a clear prompt; and `/speckit.orchestrator.status` works correctly against the migrated state."
  - Risk: medium
  - Depends: P02, P03, P04, P05
  - Boundary Map:
    - Produces:
      - `scripts/migrate/migrate.sh` — top-level migration orchestrator: auto-detects source format, selects adapter, runs extraction, invokes all transformers, generates report; handles `--source`, `--path`, `--recent-count`, `--merge`/`--force`/`--abort` flags
      - `scripts/migrate/transform/report.sh` — generates MIGRATION-REPORT.md with statistics (knowledge: X active/Y archived/Z skipped, decisions: X migrated/Y superseded, requirements: X active/Y archived, milestones: X active/Y recent/Z historical/W archived, telemetry: X units aggregated), warnings, anomalies, and next steps
      - `scripts/migrate/lib/idempotency.sh` — detects existing `.specify/orchestrator/` state, enforces `--merge`/`--force`/`--abort` semantics (default: `--abort`)
      - `scripts/migrate/lib/error-handler.sh` — skip-and-warn error handling: malformed entries logged to report, raw data preserved in `archive/migration-errors/`
      - `scripts/migrate/transform/preferences.sh` — converts relevant source preferences to orchestrator config format, notes GSD-specific settings in report
      - `commands/migrate.md` — orchestrator command definition for `/speckit.orchestrator.migrate`
      - Output files: `MIGRATION-REPORT.md`, `archive/migration-errors/` (if errors), updated `extension.yml` command registration
    - Consumes:
      - All adapter scripts (from P01, P05) — `gsd2.sh`, `gsd1.sh`, `speckit.sh`
      - All transform scripts (from P02, P03, P04) — `knowledge.sh`, `knowledge-index.sh`, `decisions.sh`, `requirements.sh`, `milestone-tiering.sh`, `active-milestone.sh`, `milestone-rollup.sh`, `telemetry-aggregator.sh`
      - All library scripts (from P01, P02, P03, P04, P05) — `sqlite-reader.sh`, `json-fallback.sh`, `category-mapper.sh`, `supersession-chain.sh`, `scope-tag.sh`, `decision-numbering.sh`, `category-inferrer.sh`

- [x] **P07**: State Resolver & Graph Integration (refit) — "A developer can run `bash scripts/migrate/migrate.sh --path <gsd2-project>` and find migration output written to the path returned by `scripts/state/resolve-root.sh` (not hardcoded `.specify/orchestrator/`), `KNOWLEDGE-INDEX.md` regenerated via `scripts/knowledge/rebuild-index.sh` so the M007 graph database (`knowledge.db`) is populated, and migrated knowledge entries participate in graph traversal via `scripts/knowledge/traverse-graph.sh`."
  - Risk: medium
  - Depends: P01, P02, P04, P06 (refits existing code)
  - Boundary Map:
    - Produces:
      - Modified `scripts/migrate/migrate.sh` — sources `scripts/state/resolve-root.sh`, computes resolved target root once, threads it to all transform scripts, invokes `scripts/knowledge/rebuild-index.sh --root <resolved>` after transforms complete
      - Modified `scripts/migrate/transform/milestone-rollup.sh` — replaces hardcoded `${target_root}/.specify/orchestrator/` at lines 92, 96 with resolved root passed from caller
      - Modified `scripts/migrate/transform/active-milestone.sh` — replaces hardcoded path at line 68
      - Modified `scripts/migrate/transform/milestone-tiering.sh` — replaces hardcoded paths at lines 58, 59
      - Modified `scripts/migrate/lib/idempotency.sh` — `enforce_conflict_policy` checks both `.orchestrator/` and `.specify/orchestrator/` when detecting existing state (per 5-rule resolver)
      - Optional: new `scripts/migrate/lib/relate-entries.sh` — if AD-14 resolution is "infer on migrate", wraps `scripts/knowledge/detect-overlap.sh` to backfill `relates_to` frontmatter after entry creation; if AD-14 is "empty, enrich post-migration", this is a no-op step documented in `commands/migrate.md`
      - Modified `commands/migrate.md` — document the `relates_to` policy decided in AD-14 and the post-migration graph rebuild
    - Consumes:
      - `scripts/state/resolve-root.sh` (M008 5-rule state resolver, supports `--absolute`)
      - `scripts/knowledge/rebuild-index.sh` (M002/M007 index + graph DB rebuilder, accepts `--root`)
      - `scripts/knowledge/detect-overlap.sh` (M007 overlap detection, only if AD-14 is "infer on migrate")
      - Existing P01–P06 migration scripts (unchanged interfaces)

- [ ] **P08**: End-to-End Validation Against Live GSD2 (refit) — "A developer can run `bash scripts/migrate/migrate.sh --source gsd2 --path <lakeledger-submodule-parent> --output <tempdir> --force`, then `ORCHESTRATOR_ROOT=<tempdir>/.orchestrator bash scripts/orchestrator/status.sh` returns a structured milestone summary without error, `bash scripts/knowledge/traverse-graph.sh --id <any-migrated-id>` returns at least one related entry when overlaps exist, and `MIGRATION-REPORT.md` in the output contains non-zero counts for knowledge, decisions, requirements, milestones, and telemetry."
  - Risk: low
  - Depends: P07
  - Boundary Map:
    - Produces:
      - `tests/integration/test-m003-e2e-migration.sh` — runs end-to-end migration against live lakeledger `.gsd/` fixture (skipped in CI when fixture absent), asserts output structure and status-command parseability
      - Possible corrections to migration scripts uncovered during validation (scoped via `Files Likely Touched` in P08-PLAN, not pre-enumerated here)
      - Modified `.specify/orchestrator/milestones/M003/M003-ROADMAP.md` and `milestone-summary.md` — mark P07/P08 complete after validation passes
    - Consumes:
      - P07 output (refitted migration pipeline)
      - Live `/Users/brettkellgren/Sites/lakeledger/.gsd/` (read-only fixture)
      - Orchestrator status command (current implementation, post-M008)

## Cross-Cutting Concerns

- **Error handling pattern (skip-and-warn)** — P01, P02, P03, P04, P05, P06. P01 establishes the base error reporting format (structured warning records). P06 formalizes the pattern with `error-handler.sh` and aggregates all warnings into `MIGRATION-REPORT.md`. P02 through P05 must emit warnings in the format P01 establishes so P06 can collect them. AD-8 governs: malformed entries are skipped, raw data preserved in `archive/migration-errors/`.

- **Non-destructive source access** — P01, P05. P01 establishes the read-only constraint for the GSD2 adapter (AD-10, NFR-201). P05 must follow the same pattern for GSD v1 and spec-kit adapters. No adapter may write, modify, or create temporary files in the source directory.

- **Bash 3.2 compatibility** — P01, P02, P03, P04, P05, P06. P01 establishes the scripting conventions (no associative arrays, no `|&`, no `${var,,}`, `sqlite3` CLI for database reads, no `jq` hard dependency). All subsequent phases must conform. NFR-203 and AD-9 govern.

- **YAML frontmatter generation** — P02, P03, P04. P02 establishes the frontmatter generation pattern for knowledge detail files using `printf`/`echo`. P03 (decisions, requirements) and P04 (milestone summaries, rollups) must use the same approach. No YAML libraries.

- **ID preservation and collision handling** — P02, P03, P06. P02 establishes the ID preservation pattern for knowledge entries (AD-4: preserve source IDs, prefix with source identifier on collision). P03 follows the same pattern for decisions (AD-5: keep original IDs, continue from max+1). P06 enforces collision detection during idempotency checks.

- **Intermediate data format** — P01, P02, P03, P04, P05. P01 defines the intermediate data format that adapters produce and transformers consume. All transformers (P02-P04) read from this format. All adapters (P01, P05) must produce this format. Changes to the format require coordinated updates.

## Dependency Graph

```
P01 ──→ P02 ──→ P04 ──┐
  │                    │
  ├───→ P03 ──────────→│
  │                    ├──→ P06 ──→ P07 ──→ P08
  └───→ P05 ──────────→│
```

Explanation:
- P01 (Adapter Architecture) is the root node — all other phases depend on it.
- P02 (Knowledge) depends only on P01.
- P03 (Decisions & Requirements) depends only on P01 — independent of P02.
- P04 (Milestone Tiering) depends on P01 and P02 (knowledge entries must exist before tiering can verify FR-219).
- P05 (GSD v1 & Spec-Kit Adapters) depends only on P01 — independent of P02, P03, P04.
- P06 (Validation & Reporting) depends on P02, P03, P04, and P05 — it validates and reports on all migration output.
- P07 (refit) modifies P01/P02/P04/P06 outputs to align with M007/M008 architecture (state resolver, graph DB rebuild).
- P08 (refit) validates the refitted pipeline end-to-end against live GSD2 data.

## Execution Order

**Historical (P01–P06, completed 2026-04-09):**
1. **P01** — Foundation phase, no dependencies. High risk (defines the adapter interface and intermediate data format that everything else consumes). Executed first.
2. **P02, P03, P05** — Executed concurrently once P01 completed.
3. **P04** — Depended on P01 and P02.
4. **P06** — Depended on P02, P03, P04, and P05.

**Refit (P07–P08, 2026-04-14):**
5. **P07** — Depends on P01, P02, P04, P06 (refits their outputs). Medium risk because the boundary map enumerates every changed line; no new subsystems. Must execute before P08.
6. **P08** — Depends on P07. Low risk — end-to-end validation with concrete demo sentence. Only produces a new integration test plus any corrections uncovered by the validation run.

Critical path for remaining work: P07 → P08.

## Validation

- **No conflicting producers**: PASS — Each phase produces distinct scripts and output files. No two phases produce the same artifact. P01 produces adapter infrastructure, P02 produces knowledge transform scripts, P03 produces decision/requirements transform scripts, P04 produces milestone tiering scripts, P05 produces alternative adapter scripts, P06 produces the CLI entry point and reporting scripts.

- **All consumed items have producers**: PASS — Every `Consumes` entry maps to a `Produces` entry in an upstream phase:
  - P02 consumes adapter-interface.sh intermediate data format → produced by P01
  - P03 consumes adapter-interface.sh intermediate data format → produced by P01
  - P04 consumes adapter-interface.sh intermediate data format → produced by P01; consumes knowledge entry output → produced by P02
  - P05 consumes adapter-interface.sh adapter contract → produced by P01
  - P06 consumes all adapter scripts → produced by P01, P05; consumes all transform scripts → produced by P02, P03, P04; consumes all library scripts → produced by P01, P02, P03, P04, P05

- **DAG is acyclic**: PASS — The dependency graph forms a valid DAG with no cycles. Topological sort confirms: P01 → {P02, P03, P05} → P04 → P06. No phase depends on a phase that directly or transitively depends on it.

- **Demo sentence coverage**: PASS — All 6 phases have concrete, testable demo sentences describing observable outcomes: P01 (normalized intermediate data from GSD2), P02 (individual knowledge files with frontmatter and index), P03 (DECISIONS.md and REQUIREMENTS.md in orchestrator format), P04 (tiered milestone output with rollups and telemetry), P05 (GSD v1 and spec-kit adapter output), P06 (end-to-end migration with report and idempotency enforcement).
