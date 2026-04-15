---
schema_version: "1.0"
type: context-draft
milestone: "M003"
status: draft
created_at: "2026-04-10T01:37:58Z"
finalized_at: "2026-04-10T01:37:58Z"
---

## Architectural Decisions

### AD-1: Pluggable Source Adapter Architecture (FR-200)

One adapter per source format: `gsd2`, `gsd1`, `speckit`. Each adapter implements a common interface where `extract()` returns normalized intermediate data. A central transformer converts intermediate data to orchestrator format. New source formats can be added by writing a new adapter script without modifying existing code.

**Rationale**: The three source formats have fundamentally different data richness and storage mechanisms. A pluggable architecture isolates parsing complexity per format and keeps the transformer generic. This also future-proofs for additional source formats.

### AD-2: GSD2 Adapter Data Source Priority (FR-201)

SQLite `gsd.db` is the preferred data source for the GSD2 adapter (richer data, indexed queries via `sqlite3` CLI which ships with macOS). Falls back to `memories-snapshot.json` + filesystem scanning if `gsd.db` is corrupted or missing.

**Rationale**: The database is the authoritative store in GSD2 and contains structured, queryable data. JSON/filesystem is a degraded path but ensures migration still works if the database is unavailable.

### AD-3: Milestone Renumbering Strategy (FR-215)

The active milestone gets renumbered as M001 in orchestrator (fresh start). Historical milestones keep original IDs in their rollup documents and in knowledge entry provenance fields for traceability.

**Rationale**: The orchestrator should start with a clean numbering scheme. Preserving original IDs in rollups and provenance fields maintains traceability without polluting the active numbering space.

### AD-4: Knowledge Entry ID Preservation (FR-217)

IDs are preserved from source (`MEM042` stays `MEM042`). If collision with existing orchestrator entries occurs, prefix with source identifier: `GSD2-MEM042`. New entries created by orchestrator after migration continue from `max(existing_ids) + 1`.

**Rationale**: Preserving IDs maintains all existing cross-references between knowledge entries, decisions, and milestone artifacts. The collision prefix handles the edge case of running migration into an existing orchestrator state.

### AD-5: Decision Numbering Continuity (FR-217)

Migrated decisions keep original IDs (D001-D153). New orchestrator decisions continue from D154+. A header in DECISIONS.md notes the migration boundary.

**Rationale**: Decision IDs are referenced throughout knowledge entries and milestone artifacts. Renumbering would break these references. The boundary header makes it clear which decisions are historical imports vs. new orchestrator decisions.

### AD-6: Execution Telemetry Aggregation (FR-209)

Raw JSONL activity files are NOT migrated 1:1. Instead, aggregate into per-milestone execution profiles in `EXECUTION-HISTORY.md` containing: average cost, average duration, success rate, cache hit rate, and notable failures.

**Rationale**: Raw telemetry from 940+ execution units would bloat the migration output without proportional value. Aggregated profiles provide the actionable information (cost trends, failure patterns) without the noise.

### AD-7: Idempotency Semantics (FR-213)

If `.specify/orchestrator/` already exists, require explicit `--merge`, `--force`, or `--abort` flag. Default is `--abort` to prevent accidental overwrites.

**Rationale**: Migration is a high-stakes operation. Silent overwrites could destroy manually curated orchestrator state. Defaulting to abort forces the developer to make a conscious choice about conflict resolution.

### AD-8: Error Handling Strategy (FR-214)

Malformed entries are skipped with warnings in `MIGRATION-REPORT.md`. Raw data preserved in `archive/migration-errors/` for manual review. Migration continues past individual entry failures -- a single bad entry should not prevent the other 127 from migrating.

**Rationale**: Real-world data is messy. GSD2 projects with 43 milestones will have some malformed entries. Fail-forward with comprehensive reporting lets the developer fix individual issues after migration rather than debugging a blocked migration.

### AD-9: Script Implementation Constraints (NFR-203, NFR-204)

All scripts in Bash 3.2 (macOS compatible). SQLite reading via `sqlite3` CLI. No `python3` or `jq` hard dependencies. YAML frontmatter written with `printf`/`echo`.

**Rationale**: Aligns with the existing spec-kit-orchestrator technology stack. Bash 3.2 is the macOS default, and `sqlite3` ships with macOS. Avoiding additional dependencies keeps the migration tool portable and consistent with the extension's architecture.

### AD-10: Non-Destructive Migration (NFR-201)

Source `.gsd/` or `.planning/` directory is NEVER modified. Migration reads only. All output goes to `.specify/orchestrator/`.

**Rationale**: This is a core safety guarantee. The developer must be able to run migration without risk to their existing project state. Constitution Principle VI (State On Disk Is Truth) demands that we only write to our own state directory.

### AD-11: Target Format Compatibility (NFR-205)

Migration output must produce valid orchestrator state that passes `/speckit.orchestrator.status` and is compatible with the knowledge architecture from spec 002. Knowledge entries follow the three-temperature format (individual detail files + index).

**Rationale**: The migration output is not a separate artifact -- it IS the orchestrator's state. If status can't read it, the migration failed. Compatibility with spec 002's knowledge architecture ensures migrated knowledge is immediately usable by all orchestrator commands.

### AD-12: Constitution Alignment

Migration itself is a Principle VI operation (State On Disk Is Truth) -- we read source state from disk, transform it, and write target state to disk. No in-memory-only state. Every intermediate step should be traceable to a file read or file write.

## Scope Boundaries

### In Scope

- GSD2 adapter: SQLite-backed migration with JSON/filesystem fallback (US1)
- GSD v1 adapter: flat-file `.planning/` directory parsing (US6)
- Standard spec-kit adapter: wrap existing specs in orchestrator structure (US7)
- Knowledge migration: individual detail files, index generation, supersession chains, category mapping, scope tag derivation (US3)
- Decision register migration: format conversion, supersession marking, boundary header (US4)
- Requirements migration: active to REQUIREMENTS.md, satisfied to REQUIREMENTS-ARCHIVE.md (US5)
- Milestone history tiering: active/recent/historical/archived with configurable `--recent-count` (US2)
- Active milestone conversion: in-progress work to orchestrator format with state preserved (US1)
- Execution telemetry aggregation: per-milestone profiles in EXECUTION-HISTORY.md (US1)
- Migration report: statistics, warnings, anomalies, next steps (US8)
- Idempotency: collision detection with `--merge`/`--force`/`--abort` flags (US8)
- Error resilience: skip-and-warn with raw data preservation (US8)
- Source preferences migration: relevant settings to orchestrator config (Edge case)

### Out of Scope

- Raw JSONL execution telemetry migration (aggregated profiles only, per AD-6)
- GSD-specific settings migration (e.g., `manage_gitignore`) -- noted in report but not converted
- Modifying source directories in any way (read-only access, per AD-10)
- Multi-agent migration (orchestrator v0.1.0 is Claude Code only; multi-agent is M002)
- Interactive migration wizard or TUI -- this is a single command with CLI flags
- Merging multiple source formats in one run (auto-detect picks one adapter)
- Migrating Git history or branch structure
- Network-based migration (all data is local, per NFR-202)

## Design Constraints

### Technical Constraints

1. **Bash 3.2 compatibility**: All scripts must work with macOS's default Bash. No Bash 4+ features (associative arrays, `|&`, `${var,,}` case conversion). (NFR-203)
2. **sqlite3 CLI only**: No Python SQLite bindings or custom SQLite extensions. Use `sqlite3 -separator` and `-csv` modes for output parsing. (NFR-204)
3. **No jq hard dependency**: JSON parsing must work without `jq`. Use `grep`/`sed`/`awk` for simple JSON extraction, or `sqlite3` JSON functions for database queries. `jq` may be used as optional enhancement if detected.
4. **No python3 hard dependency**: Everything in shell. No Python scripts for data transformation.
5. **Performance target**: Migration must complete in <60 seconds for a 43-milestone project with 150 knowledge entries. (NFR-200)
6. **YAML frontmatter generation**: Use `printf`/`echo` for YAML output. No YAML libraries. Must produce valid YAML that spec-kit-orchestrator's existing scripts can parse.

### Compatibility Constraints

7. **Spec 002 knowledge architecture**: Migrated knowledge entries must follow the three-temperature format. Detail files in `knowledge/{category}/`, index in `KNOWLEDGE-INDEX.md`, hot entries injected into dispatches.
8. **Existing orchestrator scripts**: Migration output must be parseable by `derive-phase.sh`, `read-roadmap.sh`, and all other existing scripts without modification.
9. **Tiering boundaries configurable**: Default `--recent-count=3` (last 3 completed milestones get summary-level preservation). Configurable via CLI flag. Active milestone always gets full conversion.

### Process Constraints

10. **Non-destructive**: Source directory is read-only. No temporary files in source directory.
11. **Idempotent with explicit flags**: Re-running requires `--merge`, `--force`, or `--abort`. Default `--abort`.
12. **Migration report is mandatory**: Every migration run produces `MIGRATION-REPORT.md`, even if there are zero warnings.

## Open Questions

### Resolved During Discussion

1. **Source adapter interface**: Resolved -- pluggable adapters with common `extract()` interface returning normalized intermediate data. (AD-1)
2. **GSD2 data source priority**: Resolved -- SQLite preferred, JSON/filesystem fallback. (AD-2)
3. **Milestone renumbering**: Resolved -- active becomes M001, historical keep original IDs in rollups. (AD-3)
4. **Knowledge ID collisions**: Resolved -- preserve IDs, prefix with source on collision. (AD-4)
5. **Decision numbering**: Resolved -- keep original IDs, continue from max+1. (AD-5)

### Remaining Open Questions

6. **Phase decomposition**: How should the roadmap break this work into phases? The spec has 8 user stories with dependencies (adapter architecture before source adapters, knowledge migration before tiering). The roadmap command will determine this, but the natural cut points are: (a) adapter framework + GSD2 adapter, (b) knowledge + decisions + requirements migration, (c) milestone tiering + active milestone conversion, (d) GSD v1 + spec-kit adapters, (e) validation + report + idempotency.
7. **GSD2 schema discovery**: The `gsd.db` schema is not documented in the spec. The GSD2 adapter will need to discover table structures. Should this be a dedicated discovery task in phase 1, or can it be done inline during adapter development?
8. **Spec 002 knowledge architecture availability**: Spec 002 defines the knowledge architecture that migration must target. Is spec 002 implemented, or does migration need to create the directory structure from scratch? If from scratch, migration becomes the first consumer of the knowledge format and must establish the conventions.
9. **Testing approach for 30 acceptance scenarios**: Should each acceptance scenario get a dedicated test case, or can scenarios be grouped by user story into integration tests? Given the 334-assertion precedent from M001, grouped integration tests seem appropriate.

## Addendum — 2026-04-14 Refit (post-M007/M008)

After P01–P06 shipped in commit `ad3da8a`, milestones M007 (graph-enhanced
knowledge) and M008 (standalone multi-runtime) introduced architectural
surfaces that the migration code was not built against. Three new architectural
decisions close the drift and govern phases P07 and P08.

### AD-13: Target Root via 5-Rule Resolver (supersedes AD-11's "write to `.specify/orchestrator/`")

Migration output root is the value returned by `scripts/state/resolve-root.sh`
at the time `migrate.sh` runs, honoring the full M008 precedence chain:
`ORCHESTRATOR_ROOT` env → config `state_root` → `.orchestrator/` →
`.specify/orchestrator/` → default `.orchestrator/`. `migrate.sh` resolves
once, exports the absolute path, and every transform script reads it from the
environment or an explicit argument — no transform may concatenate
`.specify/orchestrator/` itself.

**Rationale**: AD-11 committed migration to produce valid orchestrator state.
Post-M008, "valid orchestrator state" is defined by the resolver, not by a
fixed path. Hardcoding `.specify/orchestrator/` would produce output that M008
installations interpret as the bridge path rather than the canonical root, and
would silently miss explicit user configuration. The `--output` CLI flag still
overrides the resolver for offline extraction runs.

### AD-14: Knowledge Graph Participation Policy

Migrated knowledge entries emit `relates_to: []` during transform. `migrate.sh`
invokes `scripts/knowledge/rebuild-index.sh --root <resolved>` as its final
step, which regenerates `KNOWLEDGE-INDEX.md` and the M007 graph database
(`knowledge.db`) via `lib/graph-db.sh`. Semantic relationships between migrated
entries are NOT inferred during migration; users may run
`scripts/knowledge/detect-overlap.sh` post-migration to populate `relates_to`
based on content similarity.

**Rationale**: GSD2 source data does not contain orchestrator-style
`relates_to` edges, so any inference during migration would be synthetic.
Doing that inference inline would (a) couple migration runtime to overlap
detection quality, (b) bloat the migration report with arbitrary similarity
decisions, and (c) produce edges that look authoritative but are heuristic.
Deferring to `detect-overlap.sh` as an optional post-step preserves migration
determinism and lets users tune overlap thresholds against their own data.
Migration must still call `rebuild-index.sh` so the graph DB exists and
`supersedes`/`superseded_by` edges (which ARE preserved from source) are
indexed.

### AD-15: Command Naming — Defer to Cohort

`extension.yml` registers the migration command as
`speckit.orchestrator.migrate` alongside all other orchestrator commands in
that namespace. M008 decoupled the orchestrator from spec-kit as a runtime
dependency but did not rename the command cohort. The migration command stays
`speckit.orchestrator.migrate` until a coordinated rename of the entire cohort
is scheduled (a future milestone, tracked separately).

**Rationale**: Renaming one command in isolation fragments the namespace and
breaks every reference in documentation, recipes, and downstream user scripts.
AD-15 explicitly defers the rename so P07/P08 scope stays tight: fix drift,
don't churn call sites.
