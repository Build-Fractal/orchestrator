---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M036"
name: "Schema + indexer extension (graph-db CHECK + rebuild-index frontmatter reads)"
depends_on: []
---

## Prerequisites

- `references/reference-edge-types.md` exists (P00 T02 deliverable) and declares 5 edge types: `cites`, `derived_from`, `applies_to_field`, `relates_to`, `supersedes`. Verified at plan-authoring time: file is on disk, 105 lines, contains all 5 edge headings.
- `references/reference-frontmatter-contract.md` exists (P00 T01 deliverable) and declares the chunk-frontmatter graph-edge fields. Verified at plan-authoring time.
- `scripts/knowledge/lib/graph-db.sh` exists ([M020](../../../../../milestones/M020/index.md)) and contains `CHECK(edge_type IN ('relates_to', 'supersedes'))` at line 73.
- `scripts/knowledge/rebuild-index.sh` exists (M020) and reads `relates_to`/`supersedes` frontmatter at lines ~102/100, calling `db_insert_edge` at lines 128/138.

## Description

Extend the SQLite graph schema (`scripts/knowledge/lib/graph-db.sh`) and the index-rebuilder (`scripts/knowledge/rebuild-index.sh`) so the three new edge types declared in the P00 SSOT (`cites`, `derived_from`, `applies_to_field`) flow through the data path:

1. **Schema CHECK widening** — extend the `edges` table CHECK constraint from the 2-element enum to the 5-element enum, matching the P00 SSOT exactly.
2. **Frontmatter→edge inserts** — extend the per-file extraction loop to read three new frontmatter fields and insert one edge row per target, mirroring the existing `relates_to` array-handling pattern.

This is **schema evolution**. SQLite cannot ALTER a CHECK constraint in place. The migration path: `db_init` is `CREATE TABLE IF NOT EXISTS`, so an existing DB will not gain the new constraint. **The rebuild path handles this**: `rebuild-index.sh` always operates against a freshly-staged `tmp_db` (see lines ~70-80 of rebuild-index.sh), so on the next rebuild, the new CHECK fires. No explicit migration step needed for the orchestrator's own `knowledge.db`. (For hypothetical long-lived DBs that bypass rebuild, document the rebuild as the migration mechanism in a code comment.)

The `applies_to_field` edge is special: its targets are **field names**, not `MEM###`/`SPEC-*`/`REF-*` chunk IDs. The edges table treats them uniformly as opaque text in `target_id`. The traverser (T02) decides whether to dereference field-name targets back to entries (it doesn't, by default — they're terminal nodes for graph walks).

## Steps

1. **Edit `scripts/knowledge/lib/graph-db.sh`** — replace the CHECK constraint:

   Current (line 73):
   ```sql
   edge_type TEXT NOT NULL CHECK(edge_type IN ('relates_to', 'supersedes')),
   ```

   New:
   ```sql
   edge_type TEXT NOT NULL CHECK(edge_type IN ('relates_to', 'supersedes', 'cites', 'derived_from', 'applies_to_field')),
   ```

   Add a comment block above the CHECK constraint pointing readers at the SSOT:
   ```sql
   -- Edge-type closed enum. SSOT: references/reference-edge-types.md (M036 P00 T02).
   -- New edge types require: (a) row in the SSOT file, (b) widening this CHECK enum,
   -- (c) extension in scripts/knowledge/rebuild-index.sh (frontmatter read), (d)
   -- extension in scripts/knowledge/traverse-graph.sh if directional walking differs.
   ```

   Add a code-level migration note at the top of the file in a header comment:
   ```bash
   # Schema evolution note (M036/P05): the edges.edge_type CHECK enum grew from
   # 2 → 5 values. SQLite cannot ALTER a CHECK constraint; rebuild-from-source
   # via rebuild-index.sh is the migration path (rebuild always stages a fresh
   # tmp_db before promotion). No long-lived knowledge.db state survives a
   # rebuild, so no destructive migration is needed for the orchestrator's
   # own DB.
   ```

2. **Edit `scripts/knowledge/rebuild-index.sh`** — extend the per-file extraction loop (currently around lines 89–140) to read the three new frontmatter fields and insert their edges. Pattern mirrors the existing `relates_to` loop verbatim.

   Add three new field extractions immediately after the `relates_to_raw` line (~line 102):
   ```bash
   cites_raw="$(fm_field "$file" "cites")"
   derived_from_raw="$(fm_field "$file" "derived_from")"
   applies_to_field_raw="$(fm_field "$file" "applies_to_field")"
   ```

   Add three new edge-insertion blocks immediately after the existing `supersedes` block (~line 140), each one a verbatim adaptation of the `relates_to` block at lines 119–134. The pattern for each:
   ```bash
   # --- Insert edges for cites ---
   if [ -n "$cites_raw" ] && [ "$cites_raw" != "[]" ]; then
     cites_clean="$(printf '%s' "$cites_raw" | tr -d '[]' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
     if [ -n "$cites_clean" ]; then
       old_ifs="$IFS"
       IFS=','
       for cite_target in $cites_clean; do
         cite_target="$(printf '%s' "$cite_target" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
         if [ -n "$cite_target" ]; then
           db_insert_edge "$tmp_db" "$id" "$cite_target" "cites"
           db_edge_count=$((db_edge_count + 1))
         fi
       done
       IFS="$old_ifs"
     fi
   fi
   ```
   Repeat for `derived_from` (target_id is the upstream chunk) and `applies_to_field` (target_id is a field name string — opaque to the edge layer). Keep the variable names locally scoped (`derived_target`, `field_target`) to avoid shadowing.

3. **Author `tools/verify/m036-p05-edges-schema-accepts-new.sh`** — single-script-file shape verifier. Stages an empty mktemp DB, calls `db_init`, then attempts three `INSERT INTO edges` rows (one per new edge type). Assert exit 0 and three rows landed in the `edges` table:
   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p05-edges-schema-accepts-new.sh — assert the widened
   # CHECK enum accepts cites / derived_from / applies_to_field inserts.
   set -euo pipefail
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   . "$ROOT/scripts/knowledge/lib/graph-db.sh"
   tmpdir="$(mktemp -d)"
   trap 'rm -rf "$tmpdir"' EXIT
   db="$tmpdir/test.db"
   db_init "$db"
   db_insert_edge "$db" "SPEC-A" "REF-B" "cites"
   db_insert_edge "$db" "REF-C" "REF-D" "derived_from"
   db_insert_edge "$db" "REF-E" "staff_count" "applies_to_field"
   count="$(sqlite3 "$db" "SELECT COUNT(*) FROM edges;")"
   if [ "$count" = "3" ]; then
     echo "PASS: m036-p05-edges-schema-accepts-new (3 new-edge rows)"
     exit 0
   fi
   echo "FAIL: m036-p05-edges-schema-accepts-new (expected 3 rows, got $count)" >&2
   exit 1
   ```

4. **Author `tools/verify/m036-p05-edges-schema-accepts-old.sh`** — companion verifier asserting `relates_to` and `supersedes` still work. Same shape as step 3, but with two insert calls using the pre-existing edge types. CON-5 regression guard at the schema layer.

5. **Author `tools/verify/m036-p05-rebuild-emits-new-edges.sh`** — stages a fixture chunk file under a mktemp `knowledge/spec/requirement/` tree with frontmatter declaring `cites: [REF-X]`. Invokes `bash scripts/knowledge/rebuild-index.sh` against the staged tree (via `PROJECT_ROOT=$tmpdir` env override the existing scripts already honor — see `_spec_id_meta` in `scope-filter.sh:518` for the pattern). Asserts the resulting `knowledge.db` contains an edge row `(SPEC-A, REF-X, 'cites')`.

   Fixture chunk content (single-quoted heredoc to avoid expansion — heredoc is fine inside script body, only forbidden in inline Truth Check shape):
   ```yaml
   ---
   id: SPEC-A
   category: spec/requirement
   confidence: 0.9
   created_at: 2026-05-01
   last_verified: 2026-05-01
   hit_count: 0
   cites: [REF-X]
   ---
   # SPEC-A: fixture
   ```

## Must-Haves

Truths from the phase plan addressed by this task:

- "Graph DB schema accepts `cites` / `derived_from` / `applies_to_field` edge inserts without CHECK violation" — covered by the new verifier (step 3).
- "Pre-existing `relates_to` and `supersedes` edge inserts continue to succeed" — covered by step 4.
- "`rebuild-index.sh` populates edges from `cites` / `derived_from` / `applies_to_field` frontmatter" — covered by step 5.

## Verification

```bash
bash tools/verify/m036-p05-edges-schema-accepts-new.sh
```

```bash
bash tools/verify/m036-p05-edges-schema-accepts-old.sh
```

```bash
bash tools/verify/m036-p05-rebuild-emits-new-edges.sh
```

## Inputs

### From Previous Tasks

(None — T01 has no upstream task in this phase.)

### From Disk (Pre-existing)

- `references/reference-edge-types.md` — SSOT for the 5-edge enum; the CHECK constraint must match this list verbatim. Read for the canonical edge-type names.
- `scripts/knowledge/lib/graph-db.sh` — the file to modify. Key API:
  - `db_init(db_path)` — creates schema, idempotent via `CREATE TABLE IF NOT EXISTS`.
  - `db_insert_edge(db_path, source_id, target_id, edge_type)` — `INSERT OR IGNORE`; will fail with SQLite CHECK violation (exit 19) if `edge_type` is not in the enum.
  - `db_query(db_path, sql)` — wrapper for `sqlite3`; emits `DB_ERROR:` to stderr on non-zero rc.
- `scripts/knowledge/rebuild-index.sh` — the file to modify. Key behavior:
  - Iterates files under `knowledge/`, calls `fm_field "$file" "<name>"` to extract YAML frontmatter values.
  - Calls `db_insert_entry` then per-edge-type loops calling `db_insert_edge`.
  - Stages all writes against a `tmp_db` then promotes with `mv` (atomic-replace pattern; the existing relates_to loop is the canonical sample).
- `scripts/knowledge/lib/index-utils.sh` — provides `get_project_root()` and `fm_field()`. Honors `PROJECT_ROOT` env override for staged-fixture testing.

## Constraints

- **Bash 3.2 / POSIX-sh compatibility** — no associative arrays, no `mapfile`, no process substitution. (CON-2 of the feature spec.)
- **No relates_to/supersedes semantics change** — the existing two CTE branches in `traverse-graph.sh` for `relates_to` are unchanged by this task. Only the CHECK enum widens; existing edges keep their existing semantics. CON-5.
- **CHECK widening is additive** — never remove `relates_to` or `supersedes` from the enum. The migration story is one-way (extend forward; no rollback to a 2-element enum without deleting all new edges).
- **Frontmatter field names are exact** — `cites`, `derived_from`, `applies_to_field` are the literal field names declared in `references/reference-frontmatter-contract.md`. Any typo (e.g., `cite` singular, `derived-from` hyphenated) silently no-ops the edge insert because `fm_field` returns empty.
- **Verifier path discipline** — all three new verifiers MUST live under `tools/verify/` (project-owned per-phase verifiers, slug-bearing). All three MUST use the milestone-prefix `m036-p05-*` to avoid collision with the existing [M030](../../../../../milestones/M030/index.md) `p05-*.sh` verifier set.
- **Single-script-file Truth Check shape (AD-19)** — the three Verification commands above are each a single `bash <path>` invocation. No `&&`-chains, no `$(...)` containing pipes, no subshells, no heredocs feeding pipes. Heredocs INSIDE the verifier script bodies are fine (they don't surface to the harness shape-classifier).

## Expected Output

Each verifier prints exactly one `PASS:` line on success and exits 0. Failure prints `FAIL:` to stderr and exits 1.

After T01 lands:
- `scripts/knowledge/lib/graph-db.sh` line 73 reads `CHECK(edge_type IN ('relates_to', 'supersedes', 'cites', 'derived_from', 'applies_to_field'))`.
- `scripts/knowledge/rebuild-index.sh` reads three new frontmatter fields and emits up to three new edge-insertion loops.
- A fresh `bash scripts/knowledge/rebuild-index.sh` against the live `knowledge/` tree completes with the same row count for relates_to/supersedes edges as before, plus zero new edges (no live chunks declare the new fields yet — those land in M036/P01–P04). The CON-5 truth holds: pre-feature behavior is byte-identical because no live chunk declares the new fields.
