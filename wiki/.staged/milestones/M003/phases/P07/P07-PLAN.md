---
schema_version: "1.0"
type: phase-plan
phase: "P07"
milestone: "M003"
goal: "Refit migrate.sh and its transforms to write to the M008 resolved state root and populate the M007 knowledge graph, closing drift introduced after P01–P06 shipped."
demo_sentence: "A developer can run `bash scripts/migrate/migrate.sh --path <gsd2-project>` and find migration output written to the path returned by `scripts/state/resolve-root.sh` (not hardcoded `.specify/orchestrator/`), `KNOWLEDGE-INDEX.md` regenerated via `scripts/knowledge/rebuild-index.sh` so the M007 graph database (`knowledge.db`) is populated, and migrated knowledge entries participate in graph traversal via `scripts/knowledge/traverse-graph.sh`."
risk: "medium"
depends_on: ["P01", "P02", "P04", "P06"]
---

## Must-Haves

### Truths

- `migrate.sh` sources `scripts/state/resolve-root.sh` and computes the target root via the 5-rule resolver when `--output` is not provided.
  - Check: `bash scripts/verify/m003-p07-migrate-sources-resolver.sh`
- No migration transform script writes a hardcoded `.specify/orchestrator/` path; every output path is derived from an argument or environment variable passed in by `migrate.sh`.
  - Check: `bash scripts/verify/m003-p07-no-hardcoded-state-paths.sh`
- `migrate.sh` invokes `scripts/knowledge/rebuild-index.sh --root <resolved>` as the final step of the P02 transform block, and the run produces a non-empty `KNOWLEDGE-INDEX.md` and a populated `knowledge.db` graph file.
  - Check: `bash scripts/verify/m003-p07-rebuild-index-wired.sh`
- `lib/idempotency.sh` detects existing state at BOTH `.orchestrator/` and `.specify/orchestrator/` under the target, not just the legacy path.
  - Check: `bash scripts/verify/m003-p07-idempotency-dual-root.sh`
- `commands/migrate.md` documents AD-13 (resolved target root), AD-14 (`relates_to` stays empty; post-migration `detect-overlap.sh` enriches), and AD-15 (command-naming deferral).
  - Check: `bash scripts/verify/m003-p07-migrate-md-documents-ads.sh`
- Bash 3.2 compatibility preserved across all modified scripts: no `declare -A`, no `|&`, no `${var,,}`, no `< <(` process-substitution-as-redirection, no `sed -i.bak` without the portable `sed_i` helper.
  - Check: `bash scripts/verify/m003-p07-bash32-compat.sh`
- Running `bash scripts/migrate/migrate.sh --help` still exits 0 and lists all documented flags; running without `--path` still exits 1.
  - Check: `bash scripts/verify/m003-p07-cli-contract.sh`

### Artifacts

- `scripts/migrate/migrate.sh` (modified: sources resolver, exports `MIGRATE_TARGET_ROOT`, calls `rebuild-index.sh` at end; must still pass `grep -q 'resolve-root\|MIGRATE_TARGET_ROOT' scripts/migrate/migrate.sh`)
- `scripts/migrate/transform/milestone-rollup.sh` (modified: reads target root from caller, no `.specify/orchestrator/` literal)
- `scripts/migrate/transform/active-milestone.sh` (modified: same pattern)
- `scripts/migrate/transform/milestone-tiering.sh` (modified: same pattern)
- `scripts/migrate/lib/idempotency.sh` (modified: `enforce_conflict_policy` probes both candidate roots)
- `commands/migrate.md` (modified: AD-13/14/15 section added; min +40 lines)
- `scripts/verify/m003-p07-migrate-sources-resolver.sh` (new)
- `scripts/verify/m003-p07-no-hardcoded-state-paths.sh` (new)
- `scripts/verify/m003-p07-rebuild-index-wired.sh` (new)
- `scripts/verify/m003-p07-idempotency-dual-root.sh` (new)
- `scripts/verify/m003-p07-migrate-md-documents-ads.sh` (new)
- `scripts/verify/m003-p07-bash32-compat.sh` (new)
- `scripts/verify/m003-p07-cli-contract.sh` (new)

### Key Links

- `scripts/migrate/migrate.sh` → `scripts/state/resolve-root.sh` (calls resolver to pick target root when `--output` omitted)
- `scripts/migrate/migrate.sh` → `scripts/knowledge/rebuild-index.sh` (final step invokes index + graph DB rebuild)
- `scripts/migrate/transform/milestone-rollup.sh` → `migrate.sh`-provided target root (no literal path)
- `scripts/migrate/transform/active-milestone.sh` → `migrate.sh`-provided target root
- `scripts/migrate/transform/milestone-tiering.sh` → `migrate.sh`-provided target root
- `scripts/migrate/lib/idempotency.sh` → both `.orchestrator/` and `.specify/orchestrator/` probes
- `commands/migrate.md` → `.specify/orchestrator/milestones/M003/M003-CONTEXT.md` (AD-13/14/15)

## Tasks

### T01: Thread Resolved Target Root Through Pipeline

Source `scripts/state/resolve-root.sh` from `migrate.sh`. When the user does NOT pass `--output`, compute the target root via `bash scripts/state/resolve-root.sh --absolute` and export it as `MIGRATE_TARGET_ROOT`. When `--output` IS provided, that value wins (offline extraction path). Replace every occurrence of `${target_root}/.specify/orchestrator/` in `transform/milestone-rollup.sh` (lines 92, 96), `transform/active-milestone.sh` (line 68), and `transform/milestone-tiering.sh` (lines 58, 59) with the root passed in from `migrate.sh`. Update the `target_root` variable in `migrate.sh` around line 403 to be the resolved absolute path rather than `$(pwd)`. Preserve the existing per-transform `$target_root` argument shape so the signatures are stable.

Acceptance: `grep -rn '\.specify/orchestrator' scripts/migrate/transform/ scripts/migrate/migrate.sh` returns no matches (except in comments documenting the bridge path). `bash scripts/migrate/migrate.sh --path /tmp/nonexistent --output /tmp/x --force` emits `MIGRATE_TARGET_ROOT=/tmp/x` in log output.

### T02: Dual-Root Idempotency Check

Modify `scripts/migrate/lib/idempotency.sh`'s `enforce_conflict_policy` function to probe BOTH `$target/.orchestrator/` and `$target/.specify/orchestrator/` when detecting existing state. Pick whichever exists; if both exist, warn and prefer `.orchestrator/` (canonical). No functional change to `--merge`/`--force`/`--abort` semantics — only the existence probe changes.

Acceptance: Create a temp dir with `.orchestrator/KNOWLEDGE-INDEX.md`, run migration with `--abort` default, migration exits 4. Repeat with `.specify/orchestrator/KNOWLEDGE-INDEX.md`, same behavior. Repeat with neither, migration proceeds.

### T03: Wire Rebuild-Index Final Step

After the existing `report.sh` invocation in `migrate.sh` (around line 442), add a new step that calls `bash scripts/knowledge/rebuild-index.sh --root "$MIGRATE_TARGET_ROOT"`. Log a warning on failure but do not fail the migration (the index can be rebuilt manually). Verify that `$MIGRATE_TARGET_ROOT/knowledge.db` exists and is non-empty after a successful run against a fixture with at least one migrated entry.

Acceptance: Post-migration, `test -s "$MIGRATE_TARGET_ROOT/knowledge.db"` returns true. `bash scripts/knowledge/traverse-graph.sh --id <migrated-id>` emits a non-error response (may return empty set if no edges, but must not crash).

### T04: Document Resolver + Graph Policy in commands/migrate.md

Add a `## State Root Resolution` section referencing AD-13, a `## Knowledge Graph Participation` section referencing AD-14 (empty `relates_to` by design; run `scripts/knowledge/detect-overlap.sh` post-migration for semantic edges), and a `## Command Naming` note referencing AD-15 (cohort defers rename). Keep each section under 15 lines — progressive disclosure to the full AD text in CONTEXT.md.

Acceptance: `grep -q 'AD-13\|AD-14\|AD-15' commands/migrate.md` passes. `grep -q 'resolve-root\|detect-overlap' commands/migrate.md` passes.

### T05: Write Seven Verify Scripts

Implement one single-invocation script per truth Check above. Each must return exit 0 on pass, non-zero on fail, with a single descriptive message. All scripts live in `scripts/verify/` following the `mXXX-pYY-name.sh` naming pattern already established.

Acceptance: `for f in scripts/verify/m003-p07-*.sh; do bash "$f" || exit 1; done` exits 0 after T01–T04 land.

## Task Dependencies

```
T01 ──→ T03
T01 ──→ T02
T01 + T02 + T03 + T04 ──→ T05
```

T01 is the load-bearing refactor; T02, T03, T04 are independent of each other but all depend on T01 because they read from the resolved-root conventions T01 establishes. T05 writes verification for the landed changes; it must be last.

## Files Likely Touched

- `scripts/migrate/migrate.sh` (modify)
- `scripts/migrate/transform/milestone-rollup.sh` (modify)
- `scripts/migrate/transform/active-milestone.sh` (modify)
- `scripts/migrate/transform/milestone-tiering.sh` (modify)
- `scripts/migrate/lib/idempotency.sh` (modify)
- `commands/migrate.md` (modify)
- `scripts/verify/m003-p07-migrate-sources-resolver.sh` (create)
- `scripts/verify/m003-p07-no-hardcoded-state-paths.sh` (create)
- `scripts/verify/m003-p07-rebuild-index-wired.sh` (create)
- `scripts/verify/m003-p07-idempotency-dual-root.sh` (create)
- `scripts/verify/m003-p07-migrate-md-documents-ads.sh` (create)
- `scripts/verify/m003-p07-bash32-compat.sh` (create)
- `scripts/verify/m003-p07-cli-contract.sh` (create)
