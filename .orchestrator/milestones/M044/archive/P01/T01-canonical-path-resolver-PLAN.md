---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M044"
name: "Canonical index/db path resolver consolidation (FR-11)"
depends_on: []
---

## Prerequisites

- `scripts/knowledge/lib/index-utils.sh` exists and defines `get_index_path()` at line 39 (returns `$(get_project_root)/$DEFAULT_INDEX_PATH`).
- `scripts/knowledge/lib/graph-db.sh` exists and defines `get_db_path()` at line 29.
- `scripts/dispatch/build-context.sh` exists and resolves `KNOWLEDGE-INDEX.md` via hardcoded path joins at `:176-179` (M031 Quick path, `_M031_PROJECT_ROOT/KNOWLEDGE-INDEX.md`) and `:462-465` (full-mode path, `$PROJECT_ROOT`/`$MILESTONE_DIR`).

## Description

FR-11 / SC-12: there must be exactly one `get_index_path` and one `get_db_path` definition, and every index reader must route through them. The definitions already exist canonically; the divergence is that `build-context.sh` resolves the index path itself via hardcoded joins instead of calling `get_index_path`. Consolidate by sourcing `index-utils.sh` in `build-context.sh` and calling `get_index_path` — while honoring the dispatch-time project-root override (`PROJECT_ROOT` / `_M031_PROJECT_ROOT`), which the lib's `get_project_root` may not resolve identically in a dispatched subprocess.

## Steps

1. Read `scripts/knowledge/lib/index-utils.sh` lines 1-60 to confirm `get_index_path` / `get_project_root` honor `PROJECT_ROOT` env (or add an env-first branch to `get_project_root` if it does not already prefer `$PROJECT_ROOT`). Do **not** change the public contract — only ensure `PROJECT_ROOT`, when exported, wins (this is how `rebuild-index.sh --root` already exports it at `:24`).
2. In `build-context.sh`, source the lib once near the top of the M031 block: `. "$_M031_PROJECT_ROOT/scripts/knowledge/lib/index-utils.sh" 2>/dev/null || true` (guarded; the consumer must still degrade if the lib is unreachable). Set `PROJECT_ROOT="$_M031_PROJECT_ROOT"` before the call so `get_index_path` resolves against the dispatch root.
3. Replace the hardcoded resolution at `:176-179` with: resolve `_M031_KNOWLEDGE_INDEX` via `get_index_path` when the lib sourced successfully, else fall back to the existing `$_M031_PROJECT_ROOT/KNOWLEDGE-INDEX.md` join (so behavior is unchanged when the lib is absent). Apply the same pattern at `:462-465` (full-mode), preserving the `$MILESTONE_DIR` fallback branch.
4. Add a one-line canonical-location note to `references/knowledge-management.md` ("Canonical index path: `get_index_path()` in `scripts/knowledge/lib/index-utils.sh`; canonical db path: `get_db_path()` in `scripts/knowledge/lib/graph-db.sh`. All readers route through these — no hardcoded `KNOWLEDGE-INDEX.md` joins.") and a one-line docstring note above `get_index_path`.
5. Author `tools/verify/m044-p01-t01-canonical-path.sh`: asserts `grep -c '^get_index_path()' scripts/knowledge/lib/index-utils.sh` == 1 AND `grep -c '^get_db_path()' scripts/knowledge/lib/graph-db.sh` == 1 AND no *other* file defines either (`grep -rl 'get_index_path()\s*{' scripts/` returns only index-utils.sh). Emit `PASS:`/`FAIL:`.
6. Author `tools/verify/m044-p01-t01-no-vestigial-path.sh`: asserts `build-context.sh` contains a `get_index_path` call AND that any surviving literal `KNOWLEDGE-INDEX.md` reference in build-context.sh is inside a guarded fallback branch (heuristic: the file sources `index-utils.sh`). Emit `PASS:`/`FAIL:`.

## Must-Haves

- FR-11: single resolver, all in-scope readers route through it.
- SC-12: exactly one `get_index_path`/`get_db_path` definition; no vestigial divergent path; canonical location documented.

## Verification

`bash tools/verify/m044-p01-t01-canonical-path.sh`
`bash tools/verify/m044-p01-t01-no-vestigial-path.sh`

## Inputs

### From Disk (Pre-existing)
- `scripts/knowledge/lib/index-utils.sh` — `get_index_path()` (returns index path), `get_project_root()` (root resolver; confirm `$PROJECT_ROOT` env precedence).
- `scripts/knowledge/lib/graph-db.sh` — `get_db_path()` (returns `knowledge.db` path).
- `scripts/dispatch/build-context.sh` — two vestigial path joins (`:176-179`, `:462-465`).

## Constraints

- Bash 3.2; no behavior change when the lib is unreachable (guarded fallback preserved). CON-3 determinism unaffected. No new SQL. Keep edits surgical (Principle XV) — do not refactor unrelated build-context.sh logic.

## Expected Output

`build-context.sh` resolves the index path via `get_index_path` (with a guarded literal fallback); both T01 verifiers emit `PASS:`.
