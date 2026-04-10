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
