---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P07"
milestone: "M003"
name: "Wire Rebuild-Index Final Step"
depends_on: ["T01"]
---

## Prerequisites

- T01 has landed: `migrate.sh` resolves `$target_root` to an absolute orchestrator state root (no `.specify/orchestrator/` segment baked in by transforms) and exports `MIGRATE_TARGET_ROOT`.
- `scripts/knowledge/rebuild-index.sh` exists. Interface:
  - `bash scripts/knowledge/rebuild-index.sh --root <project-root>` — sets `PROJECT_ROOT=<root>`, then walks `<root>/knowledge/*/` (excluding `archive/`), writes `<root>/KNOWLEDGE-INDEX.md` atomically, and (re)builds the M007 SQLite graph at `<root>/knowledge.db` via `lib/graph-db.sh`.
  - Exits 1 if `<root>/knowledge` does not exist; otherwise exits 0.
  - Sources `lib/index-utils.sh` and `lib/graph-db.sh` from its own script dir.
- `scripts/knowledge/traverse-graph.sh` exists. Interface:
  - `bash scripts/knowledge/traverse-graph.sh --id <MEMxxx> [--max-depth N] [--max-entries N] [--ranked] [--provenance]` — emits related entry IDs (one per line) by querying `knowledge.db`. Exits 0 even when no relations exist.
- The current `migrate.sh` ends the P02 transform block with a call to `transform/report.sh` around line 442, then logs `Migration complete.` and exits 0.

## Description

Append a final pipeline step to `migrate.sh` that calls `rebuild-index.sh --root "$MIGRATE_TARGET_ROOT"` after `report.sh` runs. This satisfies AD-14 (migration emits empty `relates_to`, then rebuilds the index + graph DB so the M007 query surface works against migrated entries; semantic enrichment via `detect-overlap.sh` is left to the user).

A failure of `rebuild-index.sh` must NOT fail the migration — it logs a warning and continues. Rationale: index/graph rebuild is a cosmetic/queryability step; if it fails (e.g. `sqlite3` missing in some environment), the migrated entries are still on disk and the user can re-run `rebuild-index.sh` manually.

## Steps

### Step 1: Add the rebuild step to `migrate.sh`

In `scripts/migrate/migrate.sh`, locate the existing P03 report block:

```bash
# =============================================================================
# P03 — Report Generation
# =============================================================================
log_step "Migration Pipeline — P03: Report"
bash "${_MIGRATE_DIR}/transform/report.sh" "$output_dir" "$target_root" "$opt_source" 2>/dev/null || log_warn "Report generation failed"

echo ""
log_info "Migration complete. Output at: $target_root"
log_info "Review MIGRATION-REPORT.md for statistics and next steps."
exit 0
```

Insert a new step BEFORE the trailing `echo`/`log_info` lines:

```bash
# =============================================================================
# P04 — Knowledge Index + Graph Rebuild (AD-14)
# =============================================================================
# Migrated entries emit empty relates_to. Rebuild the index and the M007
# graph DB so traverse-graph.sh works against migrated state. Semantic
# relationship inference is deferred to detect-overlap.sh per AD-14.
log_step "Migration Pipeline — P04: Knowledge Index + Graph Rebuild"
rebuild_script="$(cd "${_MIGRATE_DIR}/.." && pwd)/knowledge/rebuild-index.sh"
if [ -f "$rebuild_script" ]; then
    if bash "$rebuild_script" --root "$target_root"; then
        log_info "Knowledge index and graph DB rebuilt at: $target_root"
        if [ -s "$target_root/knowledge.db" ]; then
            log_info "Graph DB present: $target_root/knowledge.db"
        else
            log_warn "Graph DB missing or empty after rebuild (no entries?)"
        fi
    else
        log_warn "rebuild-index.sh failed; KNOWLEDGE-INDEX.md and knowledge.db may be stale"
        log_warn "Re-run manually: bash scripts/knowledge/rebuild-index.sh --root $target_root"
    fi
else
    log_warn "rebuild-index.sh not found at $rebuild_script — skipping graph rebuild"
fi
```

The `_MIGRATE_DIR` variable is already defined at the top of `migrate.sh` as the absolute path of `scripts/migrate/`. The `cd "${_MIGRATE_DIR}/.." && pwd` idiom resolves the parent (`scripts/`) and yields `scripts/knowledge/rebuild-index.sh` portably.

### Step 2: Verify the script path resolves correctly

Without running migration end-to-end, verify the path:

```
ls -la "$(cd scripts/migrate/.. && pwd)/knowledge/rebuild-index.sh"
```

…must show the existing `rebuild-index.sh` file. If `_MIGRATE_DIR` is structured differently than expected, adjust the `cd` accordingly.

### Step 3: Smoke run on the orchestrator repo itself

```
tmp=$(mktemp -d)
bash scripts/migrate/migrate.sh --path . --output "$tmp" --force
ls -la "$tmp/KNOWLEDGE-INDEX.md" "$tmp/knowledge.db" 2>/dev/null
```

Expected:
- Both files exist after the run (assuming the source has any knowledge entries to migrate).
- Migration log shows the `==> Migration Pipeline — P04:` step.

If the source has zero knowledge entries, `knowledge.db` may be present but empty — that is acceptable, the warning fires.

## Must-Haves

This task addresses these phase truths:
- `migrate.sh` invokes `scripts/knowledge/rebuild-index.sh --root <resolved>` as the final step of the transform block.
- A migration run produces a non-empty `KNOWLEDGE-INDEX.md` and a populated `knowledge.db` graph file when the source has at least one knowledge entry.

## Verification

```
tmp=$(mktemp -d)
bash scripts/migrate/migrate.sh --path . --output "$tmp" --force
test -f "$tmp/KNOWLEDGE-INDEX.md" && echo OK_INDEX
test -f "$tmp/knowledge.db" && echo OK_DB
bash scripts/knowledge/traverse-graph.sh --id MEM001
echo "exit=$?"
```

Expected output includes `OK_INDEX`, `OK_DB`, and a `traverse-graph.sh` exit code of 0 (whether or not it returns related entries — empty result with exit 0 is the success case for `traverse-graph.sh`).

## Inputs

### From Previous Tasks

- `scripts/migrate/migrate.sh` (from T01)
  - Key API: writes `target_root` log line; passes `target_root` to every transform.
  - Behavioral contract: `target_root` is the absolute orchestrator state root.

### From Disk (Pre-existing)

- `scripts/knowledge/rebuild-index.sh` — invoked as `bash <path> --root <target_root>`. Reads `<target_root>/knowledge/*/`, writes `<target_root>/KNOWLEDGE-INDEX.md` and `<target_root>/knowledge.db`. Exit 0 success, 1 if `<target_root>/knowledge` missing.
- `scripts/knowledge/traverse-graph.sh` — used in verification only.

## Constraints

- **Bash 3.2 only**. The new block uses no associative arrays, no `mapfile`, no `< <(…)`, no `|&`.
- **Failure of `rebuild-index.sh` MUST NOT fail the migration**. The `if … else log_warn` pattern enforces this.
- **Do not move the `report.sh` call**. The new block runs strictly AFTER report generation so the report's own counts reflect pre-rebuild state.
- **Do not introduce a new positional argument to any transform**. The rebuild step is invoked from `migrate.sh` only.
- **Do not source `rebuild-index.sh`**. It must be invoked via `bash`, because it is `set -euo pipefail` and would alter the caller's shell options if sourced.
- **AD-14 boundary**: do NOT call `detect-overlap.sh` from `migrate.sh`. Semantic inference is a user-driven post-migration step.

## Expected Output

After this task:
- A successful migration run produces both `$target_root/KNOWLEDGE-INDEX.md` and `$target_root/knowledge.db`.
- `bash scripts/knowledge/traverse-graph.sh --id <any-migrated-id>` runs against the new graph DB without crashing (returns empty set if no edges, which is correct per AD-14).
- A failed `rebuild-index.sh` invocation logs a warning with a manual re-run hint but does not fail the migration.
