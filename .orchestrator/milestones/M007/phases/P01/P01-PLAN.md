---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M007"
goal: "Create SQLite graph backend for the knowledge system"
demo_sentence: "A developer runs rebuild-index.sh and a knowledge.db SQLite database is created alongside the flat index, containing entries, edges, and scope_tags tables populated from knowledge entry frontmatter — with a NULL vector column ready for future sqlite-vec integration."
risk: "medium"
depends_on: []
---

<!--
  P01 -- SQLite Graph Backend
  ============================

  Context: the knowledge system stores structured entries with explicit
  relationships (relates_to, superseded_by, scope_tags) in YAML frontmatter.
  Currently, retrieval is limited to 1-hop BFS in a 172-line Bash script.
  A SQLite backend enables recursive CTE queries for multi-hop traversal,
  provenance chains, and graph-aware diagnostics — all via the `sqlite3` CLI
  that ships with macOS, preserving the pure-Bash architecture.

  Architectural decisions:
    AD-1  SQLite via `sqlite3` CLI — no Python, no compiled extensions.
    AD-2  No graceful degradation — SQLite is the required backend (always
          available on macOS).
    AD-3  Knowledge entry files remain source of truth — SQLite DB is a
          derived artifact rebuilt from files.

  Schema design:
    - `entries` table: all frontmatter fields + NULL vector column for future
      sqlite-vec integration.
    - `edges` table: relates_to + supersedes relationships as directed edges.
    - `scope_tags` table: normalized tag-to-entry mapping.

  Cross-milestone dependencies:
    - M002 delivered the knowledge scripts (create-entry.sh, update-entry.sh,
      rebuild-index.sh) and index-utils.sh.
    - M005 P01 delivered content hashing (scripts/lib/hash.sh).
    Both are committed on main.
-->

## Must-Haves

### Truths

- graph-db.sh library exists with double-sourcing guard, get_db_path, db_query, and db_init functions.
  - Check: `bash scripts/verify/m007-p01-graph-db-lib.sh`
- SQL schema defines entries table with all frontmatter columns plus a NULL vector column.
  - Check: `bash scripts/verify/m007-p01-schema-entries.sh`
- SQL schema defines edges table for relates_to and supersedes relationships.
  - Check: `bash scripts/verify/m007-p01-schema-edges.sh`
- SQL schema defines scope_tags table for normalized tag-to-entry mapping.
  - Check: `bash scripts/verify/m007-p01-schema-scope-tags.sh`
- rebuild-index.sh populates knowledge.db alongside the flat index rebuild.
  - Check: `bash scripts/verify/m007-p01-rebuild-populates-db.sh`
- knowledge.db is rebuilt atomically using the temp-file-then-mv pattern.
  - Check: `bash scripts/verify/m007-p01-atomic-rebuild.sh`
- rebuild-index.sh reports entry, edge, and scope_tag counts for the database.
  - Check: `bash scripts/verify/m007-p01-rebuild-db-counts.sh`

### Artifacts

- scripts/knowledge/lib/graph-db.sh (min 60 lines, contains "db_init" and "db_query" and "get_db_path")
- scripts/knowledge/rebuild-index.sh (min 150 lines, contains "knowledge.db" and "graph-db.sh")
- scripts/verify/m007-p01-graph-db-lib.sh (min 10 lines, contains "graph-db.sh")
- scripts/verify/m007-p01-schema-entries.sh (min 10 lines, contains "entries")
- scripts/verify/m007-p01-schema-edges.sh (min 10 lines, contains "edges")
- scripts/verify/m007-p01-schema-scope-tags.sh (min 10 lines, contains "scope_tags")
- scripts/verify/m007-p01-rebuild-populates-db.sh (min 10 lines, contains "knowledge.db")
- scripts/verify/m007-p01-atomic-rebuild.sh (min 10 lines, contains "tmp")
- scripts/verify/m007-p01-rebuild-db-counts.sh (min 10 lines, contains "REBUILT")

### Key Links

- scripts/knowledge/lib/graph-db.sh -> scripts/knowledge/rebuild-index.sh
- scripts/knowledge/lib/index-utils.sh -> scripts/knowledge/rebuild-index.sh
- scripts/knowledge/lib/detail-utils.sh -> scripts/knowledge/lib/graph-db.sh (fm_field pattern)
- knowledge/{category}/MEM###.md -> scripts/knowledge/rebuild-index.sh (input files)

## Tasks

### T01: SQL Schema Design + graph-db.sh library

Creates `scripts/knowledge/lib/graph-db.sh` with the SQLite connection library.
Defines the SQL schema: `entries` table (all frontmatter fields + NULL vector
column), `edges` table (relates_to and supersedes relationships as directed
edges), `scope_tags` table (normalized tag-to-entry mapping). Provides helper
functions: `get_db_path()` for DB path resolution, `db_query()` for sqlite3
CLI wrapper with error handling, `db_init()` for schema creation/recreation,
and `db_insert_entry()`, `db_insert_edge()`, `db_insert_scope_tag()` for row
insertion. Also creates all seven verification scripts for phase must-haves.

Full plan: `tasks/T01-PLAN.md`

### T02: Update rebuild-index.sh to populate SQLite DB

Updates `scripts/knowledge/rebuild-index.sh` to source `graph-db.sh` and
populate the SQLite database alongside the existing flat index rebuild. Parses
the same frontmatter fields already extracted, plus `relates_to`, `supersedes`,
and `source_unit`/`source_type`. Handles `relates_to` array parsing (strips
brackets, splits on comma+space). Creates edges for both `relates_to` and
`supersedes` relationships. Normalizes `scope_tags` into the `scope_tags`
table. Uses atomic temp-file-then-mv pattern for the `.db` file. Reports
database counts in output alongside existing flat index count.

Full plan: `tasks/T02-PLAN.md`

### T03: Integration testing + verification script updates

Creates fixture knowledge entry files in a temp directory, runs
`rebuild-index.sh` against them, and verifies the resulting `knowledge.db`
contains correct data. Validates: tables exist with correct columns, entries
match source files, edges are present for relates_to and supersedes, scope_tags
are normalized correctly, vector column is NULL. Updates any verification
scripts that require a live database to function. Cleans up temp fixtures.

Full plan: `tasks/T03-PLAN.md`

## Task Dependencies

```
T01 (graph-db.sh library + schema + verification scripts)
  |
  +---> T02 (rebuild-index.sh SQLite integration)
          |
          +---> T03 (integration tests + verification updates)
```

T01 is the critical-path gate -- T02 consumes the graph-db.sh library.
T03 depends on T02 because it needs rebuild-index.sh to be able to populate
the database in order to test the full pipeline.

## Files Likely Touched

- scripts/knowledge/lib/graph-db.sh (create)
- scripts/knowledge/rebuild-index.sh (modify)
- scripts/verify/m007-p01-graph-db-lib.sh (create)
- scripts/verify/m007-p01-schema-entries.sh (create)
- scripts/verify/m007-p01-schema-edges.sh (create)
- scripts/verify/m007-p01-schema-scope-tags.sh (create)
- scripts/verify/m007-p01-rebuild-populates-db.sh (create)
- scripts/verify/m007-p01-atomic-rebuild.sh (create)
- scripts/verify/m007-p01-rebuild-db-counts.sh (create)
