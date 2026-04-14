---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M006"
name: "Update CHANGELOG.md with M002-M006 entries"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- Milestone summaries exist for M002, M004, M005.
- M003 roadmap exists (M003 has no summary file — use roadmap phases).
- M006 P01-P05 phase summaries exist.
- No prior tasks required — T01 is independent.

## Description

Add CHANGELOG entries for milestones M002 through M006. The existing
CHANGELOG.md already has entries for v0.1.0 (M001) and v0.1.1 (M001
post-release fixes). New entries are added above the existing v0.1.1
section, following the Keep a Changelog format already established.

Each milestone gets its own version header. Version numbering:
- M002 (knowledge architecture): v0.2.0
- M003 (migration tool): v0.3.0
- M004 (engine architecture): v0.4.0
- M005 (hardening): v0.5.0
- M006 (documentation & quality): v0.6.0

Each entry includes Added, Changed, and Fixed subsections as appropriate.
Items are written from the user's perspective (what capability they gain),
not from the developer's perspective (what code changed).

## Steps

### Step 1 — Read milestone summaries and roadmaps for accuracy

Read the following files to gather accurate content for CHANGELOG entries:

- `CHANGELOG.md` — current content (format reference, existing entries)
- `.specify/orchestrator/milestones/M002/M002-SUMMARY.md` — M002 deliverables
- `.specify/orchestrator/milestones/M003/M003-ROADMAP.md` — M003 phases (no summary exists)
- `.specify/orchestrator/milestones/M004/M004-SUMMARY.md` — M004 deliverables
- `.specify/orchestrator/milestones/M005/M005-SUMMARY.md` — M005 deliverables
- `.specify/orchestrator/milestones/M006/phases/P01/P01-SUMMARY.md` — P01 deliverables
- `.specify/orchestrator/milestones/M006/phases/P02/P02-SUMMARY.md` — P02 deliverables
- `.specify/orchestrator/milestones/M006/phases/P03/P03-SUMMARY.md` — P03 deliverables
- `.specify/orchestrator/milestones/M006/phases/P04/P04-SUMMARY.md` — P04 deliverables
- `.specify/orchestrator/milestones/M006/phases/P05/P05-SUMMARY.md` — P05 deliverables

### Step 2 — Write M006 CHANGELOG entry (v0.6.0)

Add above the existing `## [0.1.1]` section:

```markdown
## [0.6.0] — 2026-04-13

### Added

- **`references/architecture.md`** — Engine pipeline (7 stages), data flow, state machine overview, file layout, subsystem relationship map
- **`references/engine.md`** — Engine run.sh documentation: arguments, environment variables, lifecycle stages, checkpointing, dry-run mode, crash recovery
- **`references/events.md`** — Complete event type registry (20 canonical event types) with field schemas and examples
- **`references/errors.md`** — Error taxonomy (6 kinds: CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO) with emit_result protocol
- **`references/hooks.md`** — Hook lifecycle (4 points), hooks.yaml format, verdict protocol, custom hook walkthrough
- **`references/recipes.md`** — Context-recipe.yaml schema: section fields, source types, compression, manifest, resolution order
- **`references/routing.md`** — Routing.yaml schema: model tiers, fallback chains, classification rules, budget controls
- **`references/constitution-walkthrough.md`** — 13 constitution principles with codebase examples, violations, and compliance checks
- **`docs/getting-started.md`** — Installation, first project setup, engine output interpretation, crash recovery, diagnostics
- **`docs/recipe-authoring.md`** — Custom recipes, per-phase overrides, compression, troubleshooting
- **`docs/hook-development.md`** — Writing hooks, verdict protocol, testing, debugging, example hooks
- **`docs/knowledge-management.md`** — Entry creation, lifecycle operations, staleness, graph, consolidation

### Changed

- **`scripts/AGENTS.md`** — Transformed from 48-line directory listing to 323-line contributor guide with Bash 3.2 conventions, testing patterns, constitution compliance checklist, PR review checklist
- **`references/file-formats.md`** — Added 3 new format schemas: context-recipe.yaml, hooks.yaml, engine-checkpoint.json (802→1105 lines)
- **`CHANGELOG.md`** — Added entries for M002-M006
- **`CLAUDE.md`** — Updated project status, key files, recent changes
```

Adjust the date and specific line counts based on what is actually on disk
at the time of writing. Every file path mentioned must be verified to exist.

### Step 3 — Write M005 CHANGELOG entry (v0.5.0)

Based on M005-SUMMARY.md. Key items:

- Added: content-hash idempotency (hash.sh), cost transparency
  (cost_source field), payload transform extraction, agent instruction
  schema (instruction-schema.md, check-instructions.sh), gate verdict
  protocol (verdicts.sh, provider-convention.md), 5 new diagnostic
  checks (scored run-doctor.sh), autonomy permission pipeline
  (generate/write/check-permissions.sh)
- Changed: run-doctor.sh (scored health report, DOCTOR: protocol),
  extension.yml (registered all new scripts)

### Step 4 — Write M004 CHANGELOG entry (v0.4.0)

Based on M004-SUMMARY.md. Key items:

- Added: 5 shared libraries (errors.sh, events.sh, run-context.sh,
  guards.sh, hooks.sh), engine core (run.sh, checkpoint.sh), YAML
  recipe system (context-recipe.yaml, hooks.yaml, recipe-parser.sh),
  constitution v2.0 (13 principles), ANTIPATTERNS.md, recipe conformance
  diagnostic (check-recipe.sh)
- Changed: dispatch scripts refactored to recipe-driven assembly,
  6 scripts integrated with library stack, routing.yaml extended

### Step 5 — Write M003 CHANGELOG entry (v0.3.0)

Based on M003-ROADMAP.md phases. Key items:

- Added: migration command (commands/migrate.md), adapter architecture
  (adapter-interface.sh), GSD2/GSD1/spec-kit adapters, knowledge
  migration pipeline, decision migration, active milestone detection,
  requirements rollup, telemetry aggregation, milestone tiering,
  idempotency guards, migration report

### Step 6 — Write M002 CHANGELOG entry (v0.2.0)

Based on M002-SUMMARY.md. Key items:

- Added: three-temperature knowledge architecture (hot/warm/cold),
  KNOWLEDGE-INDEX.md pipe-delimited index, 7 knowledge CRUD scripts,
  3 shared libraries (staleness.sh, index-utils.sh, detail-utils.sh),
  graph traversal, detail resolution, pre-inlined dispatch with manifest
  header, execution telemetry pipeline, model routing configuration,
  diagnostics command (run-doctor.sh)
- Changed: build-context.sh (knowledge-aware context building),
  compress-payload.sh (manifest header support)

### Step 7 — Verify all CHANGELOG entries

For every file path mentioned in any CHANGELOG entry:
- Confirm the file exists on disk.
- If a file is referenced that does not exist, remove the reference
  or correct the path.

For every version header:
- Confirm the version number in `extension.yml` is consistent (the
  current version is `0.2.0` — this may need updating).

## Must-Haves

- [ ] `CHANGELOG.md` contains `## [0.2.0]` section with M002 content
- [ ] `CHANGELOG.md` contains `## [0.3.0]` section with M003 content
- [ ] `CHANGELOG.md` contains `## [0.4.0]` section with M004 content
- [ ] `CHANGELOG.md` contains `## [0.5.0]` section with M005 content
- [ ] `CHANGELOG.md` contains `## [0.6.0]` section with M006 content
- [ ] All entries follow Keep a Changelog format (### Added, ### Changed, ### Fixed)
- [ ] Every file path mentioned in CHANGELOG entries exists on disk
- [ ] New entries are above existing v0.1.1 and v0.1.0 entries
- [ ] Entries are in reverse chronological order (newest first)

## Verification

After writing, run:

```
bash scripts/verify/m006-p06-changelog-m002.sh
bash scripts/verify/m006-p06-changelog-m003.sh
bash scripts/verify/m006-p06-changelog-m004.sh
bash scripts/verify/m006-p06-changelog-m005.sh
bash scripts/verify/m006-p06-changelog-m006.sh
```

All must exit 0. If verification scripts do not yet exist (T03 has not
run), verify manually by grepping for required sections and keywords.

## Inputs

### From Previous Tasks

None — T01 is independent.

### From Disk (Pre-existing)

- `CHANGELOG.md` — current content (97 lines, v0.1.0 and v0.1.1 entries)
- `.specify/orchestrator/milestones/M002/M002-SUMMARY.md` — M002 summary
- `.specify/orchestrator/milestones/M003/M003-ROADMAP.md` — M003 roadmap (no summary)
- `.specify/orchestrator/milestones/M004/M004-SUMMARY.md` — M004 summary
- `.specify/orchestrator/milestones/M005/M005-SUMMARY.md` — M005 summary
- `.specify/orchestrator/milestones/M006/phases/P01/P01-SUMMARY.md` through P05-SUMMARY.md

## Constraints

- **DC-4**: Verify-as-you-write — every file path in entries confirmed on disk.
- **DC-5**: Bug fix commits reference CHANGELOG.md if bugs are found.
- Keep a Changelog format: `## [version] — date`, then `### Added`, `### Changed`, `### Fixed`.
- Entries written from user perspective (capabilities gained), not developer perspective.
- Preserve all existing CHANGELOG content (v0.1.0, v0.1.1 sections).

## Expected Output

After completing this task:

1. `CHANGELOG.md` contains entries for M002 (v0.2.0), M003 (v0.3.0),
   M004 (v0.4.0), M005 (v0.5.0), and M006 (v0.6.0).
2. All entries follow Keep a Changelog format.
3. All file paths in entries verified against disk.
4. Entries appear in reverse chronological order above existing content.
