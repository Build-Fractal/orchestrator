---
schema_version: "1.0"
type: roadmap
milestone: "M003"
feature_ref: "003-migration-tool"
feature_spec: "specs/003-migration-tool/spec.md"
vision: "Enable teams to adopt spec-kit-orchestrator without losing institutional knowledge by migrating project artifacts from GSD2, GSD v1, or standard spec-kit into orchestrator format via a single command."
tier: "C"
created_at: "2026-04-09T12:00:00Z"
updated_at: "2026-04-09T12:00:00Z"
---

## Phases

- [ ] **P01**: Adapter Architecture & GSD2 Reader — "A developer can run the GSD2 adapter against a `.gsd/` directory and receive a normalized intermediate data structure containing knowledge entries, decisions, requirements, and milestone metadata extracted from `gsd.db` (or JSON fallback)."
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

- [ ] **P02**: Knowledge Migration Pipeline — "A developer can run the knowledge migrator against GSD2 intermediate data and find individual `knowledge/{category}/{MEM###}.md` detail files with full frontmatter, a complete `KNOWLEDGE-INDEX.md`, superseded entries archived in `knowledge/archive/{category}/`, and scope tags derived from source unit IDs."
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

- [ ] **P03**: Decision & Requirements Migration — "A developer can run the decision and requirements migrators and find a `DECISIONS.md` with all 153+ decisions in orchestrator table format (with supersession notes and migration boundary header), a `REQUIREMENTS.md` with active requirements including validation chains, and a `REQUIREMENTS-ARCHIVE.md` with satisfied requirements."
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

- [ ] **P04**: Milestone History Tiering — "A developer can run the milestone tiering algorithm against a 43-milestone GSD2 project and find the active milestone fully converted to orchestrator format (renumbered as M001), the last 3 completed milestones with summary-level preservation, all other completed milestones as single rollup documents with `drill_down_paths`, raw artifacts copied to `archive/gsd-raw/`, and an `EXECUTION-HISTORY.md` with per-milestone aggregated telemetry."
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

- [ ] **P05**: GSD v1 & Spec-Kit Adapters — "A developer can run migration with `--source gsd1` against a `.planning/` directory and receive parsed knowledge entries (with inferred categories and 0.80 default confidence), decisions, and milestone summaries; or with `--source speckit` against a `specs/` directory and receive an orchestrator evaluation scaffolded from the existing spec."
  - Risk: low
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/migrate/adapters/gsd1.sh` — GSD v1 adapter implementing `extract()`: parses flat KNOWLEDGE.md (markdown list to entries), DECISIONS.md (markdown table to records), milestone directories to summaries; infers categories from content keywords, defaults confidence to 0.80
      - `scripts/migrate/adapters/speckit.sh` — spec-kit adapter implementing `extract()`: reads `specs/{NNN}/` directories, wraps spec.md as feature spec reference, preserves plan.md and tasks.md as reference material (not converted to orchestrator plans)
      - `scripts/migrate/lib/category-inferrer.sh` — keyword-based category inference for unstructured knowledge entries (GSD v1 has no category field)
    - Consumes:
      - `scripts/migrate/adapter-interface.sh` adapter contract (from P01) — the interface that adapters must implement

- [ ] **P06**: Validation, Reporting & CLI — "A developer can run `/speckit.orchestrator.migrate --source gsd2 --path .gsd/` end-to-end and receive a `MIGRATION-REPORT.md` with source summary, per-artifact statistics, warnings for skipped/malformed entries, and recommended next steps; re-running migration without `--merge`/`--force` is blocked with a clear prompt; and `/speckit.orchestrator.status` works correctly against the migrated state."
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
  │                    ├──→ P06
  └───→ P05 ──────────→│
```

Explanation:
- P01 (Adapter Architecture) is the root node — all other phases depend on it.
- P02 (Knowledge) depends only on P01.
- P03 (Decisions & Requirements) depends only on P01 — independent of P02.
- P04 (Milestone Tiering) depends on P01 and P02 (knowledge entries must exist before tiering can verify FR-219).
- P05 (GSD v1 & Spec-Kit Adapters) depends only on P01 — independent of P02, P03, P04.
- P06 (Validation & Reporting) depends on P02, P03, P04, and P05 — it validates and reports on all migration output.

## Execution Order

1. **P01** — Foundation phase, no dependencies. High risk (defines the adapter interface and intermediate data format that everything else consumes). Must execute first.
2. **P02, P03, P05** — Can execute concurrently once P01 completes. P02 (knowledge, high risk) and P03 (decisions/requirements, medium risk) and P05 (alt adapters, low risk) all depend only on P01 and are independent of each other. Risk-ordering within this group: P02 first if sequential dispatch is required.
3. **P04** — Depends on P01 and P02. Cannot start until P02 completes (needs knowledge entries for FR-219 verification). Independent of P03 and P05.
4. **P06** — Depends on P02, P03, P04, and P05. Must execute last. Validates all migration output and produces the final report.

Summary: The critical path is P01 → P02 → P04 → P06. P03 and P05 can execute in parallel with P02, and both must complete before P06 begins.

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
