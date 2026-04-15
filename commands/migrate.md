---
description: "Use when migrating project data from GSD2, GSD v1, or standard spec-kit into orchestrator format."
---

# speckit.orchestrator.migrate

Import project knowledge, decisions, requirements, and milestone history from external tools into the orchestrator's format.

## Usage

Run the migration CLI:

```bash
bash scripts/migrate/migrate.sh --path <source-path> [--source gsd2|gsd1|speckit] [--output <target>] [--recent-count N] [--merge|--force|--abort]
```

## Options

- `--path`: Source project path (required)
- `--source`: Explicitly specify source format (auto-detected if omitted)
- `--output`: Target directory (default: current directory)
- `--recent-count`: Number of recent milestones to preserve at summary level (default: 3)
- `--merge`: Add new entries, skip existing
- `--force`: Overwrite existing state
- `--abort`: Cancel if state exists (default)

## What Gets Migrated

| Artifact | GSD2 | GSD v1 | Spec-Kit |
|----------|------|--------|----------|
| Knowledge entries | Full (with confidence, categories) | Parsed (inferred categories, 0.80 confidence) | None |
| Decisions | Full (with supersession) | Parsed (from table) | None |
| Requirements | Full (active + archived) | None | From user stories |
| Milestone history | Tiered (active/recent/historical) | Summaries only | Spec references |
| Telemetry | Aggregated metrics | None | None |

## Post-Migration

After migration completes:
1. Review `MIGRATION-REPORT.md` for statistics and warnings
2. Run `speckit.orchestrator.status` to verify state
3. Begin orchestrator work from the migrated milestone

## State Root Resolution (AD-13)

`migrate.sh` writes to the path returned by `scripts/state/resolve-root.sh`,
honoring the M008 5-rule precedence chain (`ORCHESTRATOR_ROOT` env ->
`config.yml state_root` -> `.orchestrator/` -> `.specify/orchestrator/` ->
default `.orchestrator/`). The `--output <path>` flag overrides the
resolver for offline extraction runs.

No transform script may concatenate `.specify/orchestrator/` itself — every
output path is derived from the `target_root` argument passed in by
`migrate.sh`. See AD-13 in `.specify/orchestrator/milestones/M003/M003-CONTEXT.md`
for the full rationale.

## Knowledge Graph Participation (AD-14)

Migrated knowledge entries emit `relates_to: []` during transform.
Migration's final step invokes `scripts/knowledge/rebuild-index.sh --root
<resolved>`, which regenerates `KNOWLEDGE-INDEX.md` and the M007 graph
database (`knowledge.db`). Supersession edges (`supersedes` /
`superseded_by`) ARE preserved from source and indexed by the rebuild.

Semantic relationships between migrated entries are NOT inferred during
migration. To populate `relates_to` based on content similarity, run
`bash scripts/knowledge/detect-overlap.sh` post-migration. This keeps
migration deterministic and lets users tune overlap thresholds against
their own data. See AD-14 in `M003-CONTEXT.md` for full rationale.

## Command Naming (AD-15)

This command is registered in `extension.yml` as
`speckit.orchestrator.migrate`. M008 decoupled the orchestrator from
spec-kit as a runtime dependency but did NOT rename the command cohort.
The `speckit.orchestrator.*` namespace stays intact until a coordinated
cohort rename ships in a future milestone, tracked separately. Do not
rename this command in isolation — see AD-15 in `M003-CONTEXT.md`.

## Referenced Scripts

- `scripts/migrate/migrate.sh` — migration CLI entry point
- `scripts/state/resolve-root.sh` — M008 5-rule state root resolver (AD-13)
- `scripts/knowledge/rebuild-index.sh` — index + graph DB rebuilder, called as final pipeline step (AD-14)
- `scripts/knowledge/detect-overlap.sh` — optional post-migration semantic enrichment (AD-14)
