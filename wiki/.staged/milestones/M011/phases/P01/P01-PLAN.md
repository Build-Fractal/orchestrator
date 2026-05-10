---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M011"
goal: "Extend knowledge infrastructure for spec chunks with SPEC-prefixed IDs, nested categories, and non-goal exclusion"
demo_sentence: "A developer runs create-entry.sh --id SPEC-FR-001 --category spec/requirement and the entry is created at .orchestrator/knowledge/spec/requirement/SPEC-FR-001.md, indexed in KNOWLEDGE-INDEX.md, and queryable via scope-filter.sh --graph --category spec/requirement"
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- `create-entry.sh --id SPEC-FR-001 --category spec/requirement` creates a detail file at `knowledge/spec/requirement/SPEC-FR-001.md` with `id: SPEC-FR-001` and `category: spec/requirement` in frontmatter
  - Check: `bash scripts/verify/m011-p01-create-entry-spec-id.sh`
- `create-entry.sh` with no `--id` flag still auto-generates MEM### IDs (backwards compatible)
  - Check: `bash scripts/verify/m011-p01-create-entry-mem-compat.sh`
- `create-entry.sh` rejects `--id` values with `SPEC-` prefix when `--category` does not start with `spec/`
  - Check: `bash scripts/verify/m011-p01-create-entry-spec-validation.sh`
- `rebuild-index.sh` discovers and indexes entries under nested `knowledge/spec/*/` directories alongside flat `knowledge/*/` entries
  - Check: `bash scripts/verify/m011-p01-rebuild-nested-scan.sh`
- `next_entry_id()` in index-utils.sh returns the correct next MEM### ID even when SPEC-prefixed files exist in the knowledge tree
  - Check: `bash scripts/verify/m011-p01-next-id-skips-spec.sh`
- `scope-filter.sh` excludes `spec/non-goal` category entries by default in both index and graph modes
  - Check: `bash scripts/verify/m011-p01-nongoal-exclusion.sh`
- `scope-filter.sh --include-non-goals` includes `spec/non-goal` entries when the flag is present
  - Check: `bash scripts/verify/m011-p01-nongoal-inclusion.sh`
- The 6 spec subdirectories exist under `knowledge/spec/` with `.gitkeep` files: `story/`, `requirement/`, `constraint/`, `nfr/`, `acceptance/`, `non-goal/`
  - Check: `bash scripts/verify/m011-p01-spec-dirs-exist.sh`
- All modified scripts pass Bash 3.2 syntax check (`bash -n` under `/bin/bash`)
  - Check: `bash scripts/verify/m011-p01-bash32-compat.sh`

### Artifacts

- `knowledge/spec/story/.gitkeep` (exists)
- `knowledge/spec/requirement/.gitkeep` (exists)
- `knowledge/spec/constraint/.gitkeep` (exists)
- `knowledge/spec/nfr/.gitkeep` (exists)
- `knowledge/spec/acceptance/.gitkeep` (exists)
- `knowledge/spec/non-goal/.gitkeep` (exists)
- `scripts/knowledge/create-entry.sh` (contains "SPEC-")
- `scripts/knowledge/rebuild-index.sh` (contains "spec/")
- `scripts/knowledge/lib/index-utils.sh` (contains "SPEC")
- `scripts/dispatch/scope-filter.sh` (contains "include-non-goals")
- `scripts/verify/m011-p01-create-entry-spec-id.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m011-p01-create-entry-mem-compat.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m011-p01-create-entry-spec-validation.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m011-p01-rebuild-nested-scan.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m011-p01-next-id-skips-spec.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m011-p01-nongoal-exclusion.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m011-p01-nongoal-inclusion.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m011-p01-spec-dirs-exist.sh` (min 5 lines, contains "PASS")
- `scripts/verify/m011-p01-bash32-compat.sh` (min 5 lines, contains "PASS")

### Key Links

- `scripts/knowledge/create-entry.sh` -> `scripts/knowledge/lib/index-utils.sh` (sources shared utilities, calls `next_entry_id()` and `format_index_entry()`)
- `scripts/knowledge/rebuild-index.sh` -> `scripts/knowledge/lib/graph-db.sh` (sources SQLite operations for knowledge.db rebuild)
- `scripts/knowledge/rebuild-index.sh` -> `scripts/knowledge/lib/index-utils.sh` (sources `write_full_index()` for KNOWLEDGE-INDEX.md)
- `scripts/dispatch/scope-filter.sh` -> `scripts/knowledge/lib/graph-db.sh` (sources graph DB functions for `--graph` mode)

## Tasks

### T01: Scaffold spec directory tree and extend create-entry.sh for SPEC- IDs

See `tasks/T01-PLAN.md`.

### T02: Extend rebuild-index.sh for nested spec directory scanning

See `tasks/T02-PLAN.md`.

### T03: Update next_entry_id() to skip SPEC- prefixed entries

See `tasks/T03-PLAN.md`.

### T04: Add non-goal exclusion to scope-filter.sh and create end-to-end verification

See `tasks/T04-PLAN.md`.

## Task Dependencies

```
T01 (no deps)
T02 depends on T01
T03 (no deps, parallel with T01)
T04 depends on T01
```

T01 and T03 can run in parallel (no dependencies between them). T02 and T04 both depend on T01 (need the spec directory tree and SPEC- ID support in create-entry.sh to create test fixtures). T02 and T04 can run in parallel after T01.

## Files Likely Touched

- `knowledge/spec/story/.gitkeep` (create)
- `knowledge/spec/requirement/.gitkeep` (create)
- `knowledge/spec/constraint/.gitkeep` (create)
- `knowledge/spec/nfr/.gitkeep` (create)
- `knowledge/spec/acceptance/.gitkeep` (create)
- `knowledge/spec/non-goal/.gitkeep` (create)
- `scripts/knowledge/create-entry.sh` (modify)
- `scripts/knowledge/rebuild-index.sh` (modify)
- `scripts/knowledge/lib/index-utils.sh` (modify)
- `scripts/dispatch/scope-filter.sh` (modify)
- `scripts/verify/m011-p01-create-entry-spec-id.sh` (create)
- `scripts/verify/m011-p01-create-entry-mem-compat.sh` (create)
- `scripts/verify/m011-p01-create-entry-spec-validation.sh` (create)
- `scripts/verify/m011-p01-rebuild-nested-scan.sh` (create)
- `scripts/verify/m011-p01-next-id-skips-spec.sh` (create)
- `scripts/verify/m011-p01-nongoal-exclusion.sh` (create)
- `scripts/verify/m011-p01-nongoal-inclusion.sh` (create)
- `scripts/verify/m011-p01-spec-dirs-exist.sh` (create)
- `scripts/verify/m011-p01-bash32-compat.sh` (create)
