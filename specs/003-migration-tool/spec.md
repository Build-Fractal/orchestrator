# Feature Specification: Migration Tool

**Feature Branch**: `003-migration-tool`
**Created**: 2026-04-09
**Status**: Draft
**Input**: Build a migration command (`/speckit.orchestrator.migrate`) that imports project knowledge, decisions, requirements, milestone history, and active work from GSD2, GSD v1, or standard spec-kit into the orchestrator's prescribed artifact format — enabling teams to adopt the orchestrator without losing institutional knowledge accumulated over months of development.

## Problem Statement

Teams switching to spec-kit-orchestrator from other tools face a cold-start problem:

1. **Knowledge loss**: Months of accumulated gotchas, conventions, patterns, and decisions are trapped in incompatible formats. Starting fresh means the first 10+ milestones re-discover knowledge that was already captured.
2. **History loss**: Milestone summaries, phase outcomes, and verification evidence provide institutional context ("we tried X in M012 and it failed because Y"). Without migration, this context is gone.
3. **Adoption barrier**: If switching tools requires manual re-entry of hundreds of knowledge entries and dozens of decisions, teams won't switch — even if the new tool is better.
4. **Active work disruption**: A project mid-milestone cannot afford to lose in-progress plans, partially completed phases, and active requirements.

The migration tool must handle three source formats with different data richness:

| Source | Knowledge | Decisions | Milestones | Telemetry | Database |
|--------|-----------|-----------|------------|-----------|----------|
| GSD2 Pi | 128+ entries with confidence, supersession, categories | 153+ with scope, rationale, revisability | Full hierarchy with summaries, UATs, validations | 940+ units with tokens/cost | SQLite (`gsd.db`) |
| GSD v1 | Flat KNOWLEDGE.md | Flat DECISIONS.md | `.planning/` directory | Minimal | None |
| Standard spec-kit | None (orchestrator-specific) | None | `specs/{NNN}/` with spec, plan, tasks | None | None |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - GSD2 Full Migration (Priority: P1)

As a developer who has been using GSD2 Pi on a large project (40+ milestones), I can run a single command that migrates my entire knowledge base, decision history, milestone artifacts, and active work into the orchestrator's format — so that my next milestone uses orchestrator with full institutional context.

**Why this priority**: GSD2 is the richest source format and the primary migration target. It has SQLite-backed structured data, which enables high-fidelity migration. The lakeledger project (43 milestones, 128 knowledge entries, 153 decisions, 940 execution units) is the validation case.

**Independent Test**: Can be tested by running the migration against a GSD2 `.gsd/` directory and verifying that: all active knowledge entries exist as individual files in `knowledge/{category}/`, the index is complete, all decisions are in DECISIONS.md, milestone history is tiered correctly, and the active milestone has full orchestrator artifacts.

**Acceptance Scenarios**:

1. **Given** a GSD2 project with a `.gsd/` directory containing `gsd.db`, `memories-snapshot.json`, and milestone directories, **When** the developer runs `/speckit.orchestrator.migrate --source gsd2 --path .gsd/`, **Then** the migration tool:
   - Creates `.specify/orchestrator/` with full directory structure
   - Migrates all active knowledge entries to individual `knowledge/{category}/{MEM###}.md` files
   - Builds `KNOWLEDGE-INDEX.md` from migrated entries
   - Converts decisions to orchestrator DECISIONS.md format
   - Tiers milestone history (active/recent/historical/archived)
   - Generates `MIGRATION-REPORT.md` with statistics and warnings

2. **Given** GSD2 knowledge entries with `superseded_by` pointers, **When** migration runs, **Then** superseded entries are migrated to `knowledge/archive/` with their supersession chain preserved. Active entries reference their predecessors in their detail file's `supersedes` frontmatter field.

3. **Given** a GSD2 project with an active milestone (M043 in progress), **When** migration runs, **Then** the active milestone is converted to orchestrator format:
   - M043 becomes M001 in the orchestrator (fresh numbering)
   - Active slices become phases with orchestrator plan format
   - Completed slices become phase summaries with 15-field frontmatter
   - Active tasks preserve their current state (pending/in-progress/complete)
   - The roadmap is converted to orchestrator roadmap format with boundary maps

4. **Given** GSD2 `gsd.db` is available, **When** migration reads data, **Then** it prefers the database over JSON/markdown files for: memories, decisions, requirements, verification evidence, and milestone/slice/task state. If `gsd.db` is unavailable, it falls back to `memories-snapshot.json` and filesystem scanning.

5. **Given** 1168 verification evidence records in GSD2, **When** migration runs, **Then** it aggregates them into `EXECUTION-HISTORY.md`: per-milestone success rate, common failure commands, average duration — not raw records.

---

### User Story 2 - Milestone History Tiering (Priority: P2)

As a developer migrating from a long-running project, milestone history is automatically tiered so that recent milestones provide useful context while old milestones don't bloat the working directory.

**Why this priority**: A 43-milestone project cannot carry all 43 milestones at full fidelity. Tiering is what makes migration practical for large projects. Without it, the migration output is larger than the source — defeating the purpose.

**Independent Test**: Can be tested by migrating a 43-milestone project and verifying that: the active milestone has full artifacts, recent milestones have summaries only, historical milestones have rollups, and archived milestones are in a compressed directory.

**Acceptance Scenarios**:

1. **Given** 43 milestones to migrate, **When** the tiering algorithm runs, **Then** milestones are classified:
   - **Active** (in-progress milestone): Full conversion to orchestrator format with plans, tasks, summaries, UATs
   - **Recent** (last 3 completed milestones): Phase summaries + decisions + knowledge references preserved
   - **Historical** (all other completed milestones): Single rollup document per milestone containing: title, vision, what shipped, key decisions (IDs), patterns established, gotchas discovered, requirement coverage
   - **Archived** (raw GSD2 artifacts): Copied to `archive/gsd-raw/` for manual reference

2. **Given** a historical milestone rollup, **When** a future agent needs detail about that milestone, **Then** the rollup includes `drill_down_paths` pointing to the archived raw artifacts — enabling progressive disclosure.

3. **Given** the tiering boundaries (how many milestones are "recent"), **When** the developer provides a `--recent-count N` flag, **Then** the boundary adjusts (default: 3). `--recent-count 0` means only the active milestone gets full conversion.

4. **Given** milestone M035 established a pattern (MEM089) that is still active in the knowledge base, **When** M035 is tiered as "historical", **Then** the pattern entry in `knowledge/pattern/MEM089.md` preserves the source reference `source_unit: M035/S02` — the knowledge survives independently of its source milestone's tier.

---

### User Story 3 - Knowledge Migration with Category Mapping (Priority: P3)

As a developer migrating from GSD2, all 128+ knowledge entries are individually migrated into `knowledge/{category}/` files with proper frontmatter, scope tags, confidence scores, and source provenance — so that the three-temperature architecture (spec 002) can immediately operate on the migrated data.

**Why this priority**: Knowledge is the most valuable artifact to migrate. A project that keeps its gotchas, conventions, and patterns across tool transitions saves weeks of re-discovery. The migration must produce entries that are immediately compatible with the knowledge architecture from spec 002.

**Independent Test**: Can be tested by migrating GSD2 knowledge entries and verifying that: each active entry has a detail file, the index is complete, categories map correctly, confidence scores are preserved, supersession chains are intact, and scope tags are derived from source unit IDs.

**Acceptance Scenarios**:

1. **Given** GSD2 knowledge entries with categories `gotcha`, `convention`, `pattern`, `infrastructure`, `global-rule`, **When** migration maps categories, **Then** the mapping is:
   | GSD2 Category | Orchestrator Category | Notes |
   |---|---|---|
   | gotcha | gotcha | Direct mapping |
   | convention | convention | Direct mapping |
   | pattern | pattern | Direct mapping |
   | infrastructure | infrastructure | Direct mapping |
   | global-rule | global-rule | Injected into all dispatches (hot) |

2. **Given** a GSD2 knowledge entry with `source_unit_id: "M008/S02"`, **When** migration creates the orchestrator entry, **Then** it adds scope tags derived from the source: `[milestone:M008]` (using original ID for traceability, not renumbered).

3. **Given** a GSD2 entry with `confidence: 0.95`, `hit_count: 12`, and `created_at: "2026-03-15"`, **When** migration creates the detail file, **Then** all metadata is preserved in the frontmatter:
   ```yaml
   ---
   id: MEM042
   category: gotcha
   confidence: 0.95
   hit_count: 12
   created_at: 2026-03-15
   last_verified: 2026-04-09  # set to migration date
   source_unit: M008/S02
   migrated_from: gsd2
   supersedes: null
   superseded_by: null
   relates_to: []
   ---
   ```

4. **Given** 24 superseded entries in GSD2, **When** migration runs, **Then** superseded entries are written to `knowledge/archive/{category}/` with their `superseded_by` pointer preserved, and the superseding entry's `supersedes` field references the archived entry.

---

### User Story 4 - Decision Register Migration (Priority: P4)

As a developer migrating from GSD2, all 153+ decisions are converted to the orchestrator's DECISIONS.md format with scope, rationale, revisability, and supersession preserved.

**Why this priority**: Decisions provide architectural context. "Why did we choose JWT over sessions?" is critical context for any task touching auth. Losing decisions means agents re-litigate settled questions.

**Independent Test**: Can be tested by migrating GSD2 decisions and verifying that: all decisions are present in DECISIONS.md, the format matches orchestrator's schema, superseded decisions are marked, and scope tags enable filtering.

**Acceptance Scenarios**:

1. **Given** GSD2 decisions with columns: seq, id, when_context, scope, decision, choice, rationale, revisable, made_by, superseded_by, **When** migration converts them, **Then** the orchestrator DECISIONS.md contains all decisions in the orchestrator table format:
   `| ID | Scope | When | Decision | Choice | Rationale | Revisable? |`

2. **Given** a decision D089 with `scope: "data"` and `when_context: "M012/S01"`, **When** migration creates the entry, **Then** the scope is mapped to orchestrator's scope taxonomy (`data` → `data`) and the When field preserves the original milestone/slice reference.

3. **Given** decisions where `superseded_by` is not null, **When** migration runs, **Then** the superseded decision row includes a note: `(Superseded by D###)` in the Rationale column — the row remains in the register for audit trail.

4. **Given** 153 decisions to migrate, **When** the orchestrator's DECISIONS.md is written, **Then** it includes a header noting: `Migrated from GSD2 on 2026-04-09. Entries D001-D153 are historical imports. New decisions continue from D154.`

---

### User Story 5 - Requirements Migration (Priority: P5)

As a developer migrating from GSD2, active requirements are converted to a format that the orchestrator can use as input for milestone evaluation and roadmap generation.

**Why this priority**: Requirements define what needs to be built. Active requirements from the source project become constraints for future orchestrator milestones.

**Independent Test**: Can be tested by migrating GSD2 requirements and verifying that: active requirements are preserved with their validation status, blocked requirements include blockers, and deferred requirements are noted.

**Acceptance Scenarios**:

1. **Given** 27 active requirements in GSD2 with classes (core-capability, primary-user-loop, quality-attribute, differentiator), **When** migration runs, **Then** each requirement is written to `REQUIREMENTS.md` in the orchestrator format with: ID, class, status, description, validation status, and requirement coverage from milestone history.

2. **Given** a requirement R012 that was validated by slices in M035 and M040, **When** migration runs, **Then** the requirement entry includes `validated_by: [M035/S02, M040/S01]` — preserving the validation chain from the source project.

3. **Given** requirements that have been fully satisfied and have no future work, **When** migration runs, **Then** they are placed in `REQUIREMENTS-ARCHIVE.md` with a `satisfied` status and the milestone that completed them.

---

### User Story 6 - GSD v1 Migration (Priority: P6)

As a developer who used GSD v1 (slash commands, `.planning/` directory), I can migrate my artifacts into orchestrator format.

**Why this priority**: GSD v1 is simpler to migrate (flat files, no database) but still contains valuable knowledge and decisions. Lower priority because GSD v1 data is less structured.

**Independent Test**: Can be tested by creating a mock `.planning/` directory with GSD v1 artifacts and verifying that knowledge and decisions are extracted.

**Acceptance Scenarios**:

1. **Given** a GSD v1 project with `.planning/KNOWLEDGE.md` (flat markdown list), **When** migration runs with `--source gsd1`, **Then** each knowledge entry is parsed from the markdown and created as an individual detail file. Confidence defaults to 0.80 (no confidence data in v1). Categories are inferred from content keywords or default to `pattern`.
2. **Given** a GSD v1 project with `.planning/DECISIONS.md` (markdown table), **When** migration runs, **Then** decisions are parsed and converted to orchestrator format.
3. **Given** a GSD v1 project with milestone directories under `.planning/milestones/`, **When** migration runs, **Then** milestone summaries are extracted and written as historical rollups.

---

### User Story 7 - Standard Spec-Kit Migration (Priority: P7)

As a developer with existing spec-kit specs (in `specs/{NNN}/`), I can wrap them in orchestrator milestone structure so that orchestrator can manage execution of existing specs.

**Why this priority**: Standard spec-kit has no knowledge, decisions, or milestones to migrate. The value is wrapping existing specs so they can be orchestrated. This is the simplest migration path.

**Independent Test**: Can be tested by creating a spec-kit spec and running migration, then verifying that an orchestrator evaluation is generated from the spec.

**Acceptance Scenarios**:

1. **Given** a spec-kit project with `specs/001-my-feature/spec.md`, **When** migration runs with `--source speckit`, **Then** the orchestrator creates a milestone evaluation from the spec: the spec's user stories inform tier classification, and the spec file is referenced as the feature spec in the evaluation.
2. **Given** a spec-kit project with existing `plan.md` and `tasks.md`, **When** migration runs, **Then** these are preserved as reference material in the milestone directory but NOT converted to orchestrator plans (the orchestrator will re-plan from the spec using its own decomposition).
3. **Given** no `.specify/orchestrator/` directory exists, **When** migration runs, **Then** it scaffolds the full directory structure before writing any artifacts.

---

### User Story 8 - Migration Validation and Report (Priority: P8)

As a developer who just ran a migration, I receive a comprehensive report detailing what was migrated, what was skipped, and any warnings — so that I can verify the migration succeeded before starting orchestrator work.

**Why this priority**: Migrations are high-stakes operations. A silent failure (missing entries, corrupted data) can go unnoticed until an agent makes a bad decision based on incomplete context. The report is the verification gate.

**Independent Test**: Can be tested by running a migration with deliberate anomalies (duplicate entries, missing files, malformed data) and verifying that the report captures each anomaly.

**Acceptance Scenarios**:

1. **Given** a completed migration, **When** the report is generated, **Then** `MIGRATION-REPORT.md` contains:
   - Source summary: type (gsd2/gsd1/speckit), path, detected artifacts
   - Knowledge: X active entries migrated, Y superseded archived, Z skipped (with reasons)
   - Decisions: X migrated, Y superseded noted
   - Requirements: X active, Y archived
   - Milestones: X active (full), Y recent (summaries), Z historical (rollups), W archived (raw)
   - Telemetry: X execution units aggregated into EXECUTION-HISTORY.md
   - Warnings: list of anomalies, skipped items, inferred values
   - Next steps: recommended orchestrator commands to run first

2. **Given** a knowledge entry that could not be parsed (malformed JSON or missing required fields), **When** migration encounters it, **Then** the entry is skipped, a warning is added to the report, and the raw data is preserved in `archive/migration-errors/` for manual review.

3. **Given** a successful migration, **When** the developer runs `/speckit.orchestrator.status`, **Then** the status command detects the migrated state and reports: "Project migrated from GSD2. Knowledge: 128 entries (40 gotcha, 44 convention, 39 pattern, 4 infrastructure, 1 global-rule). Decisions: 153. Active milestone: M001 (migrated from M043)."

4. **Given** a migration that has already been run (`.specify/orchestrator/` exists with migrated data), **When** the developer runs migrate again, **Then** it detects existing state and prompts: "Orchestrator state already exists. Options: --merge (add new entries, skip existing), --force (overwrite), --abort (cancel)." Default is --abort.

---

### Edge Cases

- What happens when `gsd.db` exists but is corrupted? Fall back to `memories-snapshot.json` + filesystem scanning. Log a warning in the migration report.
- What happens when `memories-snapshot.json` and `gsd.db` disagree on entry content? Prefer `gsd.db` (authoritative store). Note the discrepancy in the report.
- What happens when a GSD2 milestone has no summary (incomplete)? If it's not the active milestone, skip it with a warning. If it IS the active milestone, migrate its current state as-is (partial plans, in-progress tasks).
- What happens when knowledge entries reference decisions that don't exist? Migrate the entry with the reference intact, add a "broken reference" warning to the report.
- What happens when the source project has both `.gsd/` and `.planning/` directories? Auto-detect: if `gsd.db` exists, use GSD2 adapter. If only `.planning/` exists, use GSD v1 adapter. If both exist, prefer GSD2 and ignore `.planning/`.
- What happens when the target `.specify/orchestrator/` directory already exists from a previous orchestrator usage? Migration must not silently overwrite. Require explicit `--merge` or `--force` flag.
- What happens when migrating from GSD2 and the `preferences.md` contains GSD-specific settings (branch isolation, verification commands)? Migrate relevant settings to orchestrator config format. GSD-specific settings (e.g., `manage_gitignore`) are noted in the report but not migrated.
- What happens when knowledge entry IDs collide between source and existing orchestrator entries? Prefix migrated entries with source identifier: `MEM042` → `MEM042` if no collision, `GSD2-MEM042` if collision exists.

## Requirements *(mandatory)*

### Functional Requirements

| ID | Description | Source |
|----|-------------|--------|
| FR-200 | Source adapter architecture: pluggable adapters for GSD2, GSD v1, and standard spec-kit | US1, US6, US7 |
| FR-201 | GSD2 adapter reads from `gsd.db` (SQLite, preferred) or falls back to `memories-snapshot.json` + filesystem | US1 |
| FR-202 | Knowledge entry migration: individual detail files in `knowledge/{category}/{entry-id}.md` with full frontmatter | US3 |
| FR-203 | Knowledge index generation: `KNOWLEDGE-INDEX.md` built from migrated entries | US3 |
| FR-204 | Supersession chain preservation: superseded entries archived with `superseded_by` pointers | US3 |
| FR-205 | Decision register migration: convert source format to orchestrator DECISIONS.md schema | US4 |
| FR-206 | Milestone history tiering: active (full), recent (summaries), historical (rollups), archived (raw) | US2 |
| FR-207 | Configurable tiering boundaries: `--recent-count N` flag (default: 3) | US2 |
| FR-208 | Requirements migration: active requirements to REQUIREMENTS.md, satisfied to REQUIREMENTS-ARCHIVE.md | US5 |
| FR-209 | Execution telemetry aggregation: per-milestone metrics from raw execution data to EXECUTION-HISTORY.md | US1 |
| FR-210 | GSD v1 adapter: parse `.planning/` flat files, infer categories, default confidence to 0.80 | US6 |
| FR-211 | Spec-kit adapter: wrap existing specs in orchestrator evaluation structure | US7 |
| FR-212 | Migration report: `MIGRATION-REPORT.md` with statistics, warnings, and next steps | US8 |
| FR-213 | Idempotent with collision detection: existing state requires `--merge`, `--force`, or `--abort` | US8 |
| FR-214 | Error resilience: malformed entries skipped with warnings, raw data preserved in `archive/migration-errors/` | US8 |
| FR-215 | Active milestone conversion: in-progress work converted to orchestrator format with state preserved | US1 |
| FR-216 | Scope tag derivation: source unit IDs (`M008/S02`) mapped to orchestrator scope tags (`[milestone:M008]`) | US3 |
| FR-217 | ID continuity: knowledge entry IDs preserved from source. Decision numbering continues from source max +1 | US3, US4 |
| FR-218 | Source preferences migration: relevant settings converted to orchestrator config format | Edge case |
| FR-219 | Knowledge entries from historical milestones that are still active must survive independently of milestone tier | US2 |

### Non-Functional Requirements

| ID | Description |
|----|-------------|
| NFR-200 | Migration completes in <60 seconds for a 43-milestone project with 150 knowledge entries |
| NFR-201 | Migration is non-destructive: source `.gsd/` or `.planning/` directory is never modified |
| NFR-202 | Migration can run without network access (all data is local) |
| NFR-203 | All scripts maintain Bash 3.2 compatibility (macOS default) |
| NFR-204 | SQLite reading via `sqlite3` CLI (ships with macOS), no additional dependencies |
| NFR-205 | Migration output is valid orchestrator state: running `/speckit.orchestrator.status` after migration must work without errors |
