---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M007"
name: "SQL schema design + graph-db.sh library + verification scripts"
depends_on: []
---

## Description

Create the SQLite graph connection library at `scripts/knowledge/lib/graph-db.sh`
and all seven verification scripts for phase P01 under
`scripts/verify/m007-p01-*.sh`.

The library provides the SQL schema and helper functions for all SQLite
operations in the knowledge system. It follows the same patterns as the
existing `index-utils.sh` and `detail-utils.sh` in the same directory.

### SQL Schema

Three tables:

**`entries`** — one row per knowledge entry:
- `id` TEXT PRIMARY KEY (e.g., "MEM042")
- `category` TEXT NOT NULL
- `confidence` REAL NOT NULL DEFAULT 0.0
- `created_at` TEXT NOT NULL
- `last_verified` TEXT NOT NULL
- `hit_count` INTEGER NOT NULL DEFAULT 0
- `source_unit` TEXT NOT NULL DEFAULT ''
- `source_type` TEXT NOT NULL DEFAULT ''
- `supersedes` TEXT NOT NULL DEFAULT ''
- `superseded_by` TEXT NOT NULL DEFAULT ''
- `content_hash` TEXT NOT NULL DEFAULT ''
- `description` TEXT NOT NULL DEFAULT ''
- `file_path` TEXT NOT NULL DEFAULT ''
- `vector` BLOB DEFAULT NULL (reserved for future sqlite-vec integration)

**`edges`** — one row per directed relationship:
- `source_id` TEXT NOT NULL (FK -> entries.id)
- `target_id` TEXT NOT NULL (FK -> entries.id)
- `edge_type` TEXT NOT NULL ('relates_to' or 'supersedes')
- PRIMARY KEY (source_id, target_id, edge_type)

**`scope_tags`** — one row per tag-to-entry association:
- `entry_id` TEXT NOT NULL (FK -> entries.id)
- `tag` TEXT NOT NULL (e.g., "[project]", "[milestone:M001]")
- PRIMARY KEY (entry_id, tag)

Indexes: `idx_edges_target` on edges(target_id) for reverse lookups,
`idx_scope_tags_tag` on scope_tags(tag) for tag-based filtering.

### Library Functions

1. `get_db_path()` — resolves the knowledge.db path. Uses `get_project_root`
   from index-utils.sh and returns `$root/knowledge.db` (same directory as
   KNOWLEDGE-INDEX.md, which is at the project root).

2. `db_query()` — wrapper for `sqlite3` CLI calls. Takes a database path and
   SQL string. Passes SQL via heredoc to sqlite3. Returns sqlite3 exit code.
   Emits errors to stderr with a `DB_ERROR:` prefix.

3. `db_init()` — creates the schema. Takes a database path. Runs CREATE TABLE
   IF NOT EXISTS for all three tables and the two indexes. Uses a single
   sqlite3 invocation with all DDL in one heredoc. Returns 0 on success.

4. `db_insert_entry()` — inserts one entry row. Takes the database path and
   all entry fields as positional arguments: db_path, id, category, confidence,
   created_at, last_verified, hit_count, source_unit, source_type, supersedes,
   superseded_by, content_hash, description, file_path. Uses INSERT OR REPLACE
   to handle re-runs.

5. `db_insert_edge()` — inserts one edge row. Takes db_path, source_id,
   target_id, edge_type. Uses INSERT OR IGNORE (duplicate edges are no-ops).

6. `db_insert_scope_tag()` — inserts one scope_tag row. Takes db_path,
   entry_id, tag. Uses INSERT OR IGNORE.

### Double-Sourcing Guard

Follows the `errors.sh` pattern:
```
[ -n "${_GRAPH_DB_SOURCED:-}" ] && return 0
_GRAPH_DB_SOURCED=1
```

### Dependency on index-utils.sh

The library sources `index-utils.sh` for `get_project_root()`. This is
consistent with how `detail-utils.sh` depends on `index-utils.sh`.

## Steps

### Step 1 -- Create `scripts/knowledge/lib/graph-db.sh`

Create the file with the following content:

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/graph-db.sh — SQLite graph backend for knowledge system.
# Provides schema definition, connection helpers, and insert functions for the
# knowledge.db database. The DB is a derived artifact rebuilt from knowledge
# entry files — entry markdown files remain the source of truth.
#
# Requires: sqlite3 CLI (ships with macOS), index-utils.sh (for get_project_root).
# Bash 3.2 compatible (NFR-200). No associative arrays, no mapfile/readarray.

# --- Double-sourcing guard ---
[ -n "${_GRAPH_DB_SOURCED:-}" ] && return 0
_GRAPH_DB_SOURCED=1

# Source index-utils.sh for get_project_root
GRAPH_DB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=index-utils.sh
source "$GRAPH_DB_SCRIPT_DIR/index-utils.sh"

# --- DB path resolution ---
# get_db_path
# Returns the absolute path to knowledge.db (next to KNOWLEDGE-INDEX.md
# at the project root).
get_db_path() {
  local root
  root="$(get_project_root)"
  echo "$root/knowledge.db"
}

# --- Query helper ---
# db_query <db_path> <sql>
# Executes SQL against the given database via sqlite3 CLI.
# Returns sqlite3 exit code. Errors emitted to stderr with DB_ERROR: prefix.
db_query() {
  local db_path="$1"
  local sql="$2"
  local rc=0
  sqlite3 "$db_path" <<EOF_SQL || rc=$?
$sql
EOF_SQL
  if [ "$rc" -ne 0 ]; then
    echo "DB_ERROR: sqlite3 exited with code $rc" >&2
  fi
  return "$rc"
}

# --- Schema initialization ---
# db_init <db_path>
# Creates all tables and indexes. Uses CREATE TABLE IF NOT EXISTS so it is
# safe to call on an existing database.
db_init() {
  local db_path="$1"
  sqlite3 "$db_path" <<'EOF_SCHEMA'
CREATE TABLE IF NOT EXISTS entries (
  id TEXT PRIMARY KEY,
  category TEXT NOT NULL DEFAULT '',
  confidence REAL NOT NULL DEFAULT 0.0,
  created_at TEXT NOT NULL DEFAULT '',
  last_verified TEXT NOT NULL DEFAULT '',
  hit_count INTEGER NOT NULL DEFAULT 0,
  source_unit TEXT NOT NULL DEFAULT '',
  source_type TEXT NOT NULL DEFAULT '',
  supersedes TEXT NOT NULL DEFAULT '',
  superseded_by TEXT NOT NULL DEFAULT '',
  content_hash TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  file_path TEXT NOT NULL DEFAULT '',
  vector BLOB DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS edges (
  source_id TEXT NOT NULL,
  target_id TEXT NOT NULL,
  edge_type TEXT NOT NULL,
  PRIMARY KEY (source_id, target_id, edge_type)
);

CREATE TABLE IF NOT EXISTS scope_tags (
  entry_id TEXT NOT NULL,
  tag TEXT NOT NULL,
  PRIMARY KEY (entry_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_edges_target ON edges(target_id);
CREATE INDEX IF NOT EXISTS idx_scope_tags_tag ON scope_tags(tag);
EOF_SCHEMA
}

# --- Insert helpers ---

# db_insert_entry <db_path> <id> <category> <confidence> <created_at>
#   <last_verified> <hit_count> <source_unit> <source_type> <supersedes>
#   <superseded_by> <content_hash> <description> <file_path>
# Inserts or replaces one entry row.
db_insert_entry() {
  local db_path="$1"
  local entry_id="$2"
  local category="$3"
  local confidence="$4"
  local created_at="$5"
  local last_verified="$6"
  local hit_count="$7"
  local source_unit="$8"
  local source_type="$9"
  shift 9
  local supersedes="$1"
  local superseded_by="$2"
  local content_hash="$3"
  local description="$4"
  local file_path="$5"

  # Escape single quotes in text fields for SQL safety
  entry_id="$(printf '%s' "$entry_id" | sed "s/'/''/g")"
  category="$(printf '%s' "$category" | sed "s/'/''/g")"
  created_at="$(printf '%s' "$created_at" | sed "s/'/''/g")"
  last_verified="$(printf '%s' "$last_verified" | sed "s/'/''/g")"
  source_unit="$(printf '%s' "$source_unit" | sed "s/'/''/g")"
  source_type="$(printf '%s' "$source_type" | sed "s/'/''/g")"
  supersedes="$(printf '%s' "$supersedes" | sed "s/'/''/g")"
  superseded_by="$(printf '%s' "$superseded_by" | sed "s/'/''/g")"
  content_hash="$(printf '%s' "$content_hash" | sed "s/'/''/g")"
  description="$(printf '%s' "$description" | sed "s/'/''/g")"
  file_path="$(printf '%s' "$file_path" | sed "s/'/''/g")"

  sqlite3 "$db_path" "INSERT OR REPLACE INTO entries (id, category, confidence, created_at, last_verified, hit_count, source_unit, source_type, supersedes, superseded_by, content_hash, description, file_path, vector) VALUES ('$entry_id', '$category', $confidence, '$created_at', '$last_verified', $hit_count, '$source_unit', '$source_type', '$supersedes', '$superseded_by', '$content_hash', '$description', '$file_path', NULL);"
}

# db_insert_edge <db_path> <source_id> <target_id> <edge_type>
# Inserts one edge row. Duplicate edges are silently ignored.
db_insert_edge() {
  local db_path="$1"
  local source_id="$2"
  local target_id="$3"
  local edge_type="$4"
  sqlite3 "$db_path" "INSERT OR IGNORE INTO edges (source_id, target_id, edge_type) VALUES ('$source_id', '$target_id', '$edge_type');"
}

# db_insert_scope_tag <db_path> <entry_id> <tag>
# Inserts one scope_tag row. Duplicates are silently ignored.
db_insert_scope_tag() {
  local db_path="$1"
  local entry_id="$2"
  local tag="$3"
  # Escape single quotes in tag
  tag="$(printf '%s' "$tag" | sed "s/'/''/g")"
  sqlite3 "$db_path" "INSERT OR IGNORE INTO scope_tags (entry_id, tag) VALUES ('$entry_id', '$tag');"
}
```

Make executable:

```bash
chmod +x scripts/knowledge/lib/graph-db.sh
```

### Step 2 -- Create verification scripts

Create seven verification scripts under `scripts/verify/`. Each is a
standalone single-script-file check (AD-19 compliant). The content of each
script is specified in the phase plan Truths — Check commands. The scripts
are already created by the plan-phase process. Verify they exist and are
executable.

```bash
chmod +x scripts/verify/m007-p01-*.sh
```

### Step 3 -- Smoke test graph-db.sh

Source graph-db.sh and verify the schema can be created:

```bash
# Create a test database in /tmp
source scripts/knowledge/lib/graph-db.sh
test_db="/tmp/test-knowledge-$$.db"
db_init "$test_db"

# Verify tables exist
sqlite3 "$test_db" ".tables"
# Expected output should include: entries  edges  scope_tags

# Verify entries table has vector column
sqlite3 "$test_db" "PRAGMA table_info(entries);" | grep -q "vector"
echo "Schema OK"

# Clean up
rm -f "$test_db"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "graph-db.sh library exists with double-sourcing guard",
  "SQL schema defines entries table with all frontmatter columns plus vector",
  "SQL schema defines edges table", "SQL schema defines scope_tags table".
- **Artifacts**: `scripts/knowledge/lib/graph-db.sh`, all seven
  `scripts/verify/m007-p01-*.sh` scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m007-p01-graph-db-lib.sh
bash scripts/verify/m007-p01-schema-entries.sh
bash scripts/verify/m007-p01-schema-edges.sh
bash scripts/verify/m007-p01-schema-scope-tags.sh
```

All four should print PASS lines. The remaining three verification scripts
(m007-p01-rebuild-populates-db.sh, m007-p01-atomic-rebuild.sh,
m007-p01-rebuild-db-counts.sh) will FAIL at this point because T02 has not
yet modified rebuild-index.sh. This is expected.

### Files Touched By This Task

- `scripts/knowledge/lib/graph-db.sh` (create)
- `scripts/verify/m007-p01-graph-db-lib.sh` (create)
- `scripts/verify/m007-p01-schema-entries.sh` (create)
- `scripts/verify/m007-p01-schema-edges.sh` (create)
- `scripts/verify/m007-p01-schema-scope-tags.sh` (create)
- `scripts/verify/m007-p01-rebuild-populates-db.sh` (create)
- `scripts/verify/m007-p01-atomic-rebuild.sh` (create)
- `scripts/verify/m007-p01-rebuild-db-counts.sh` (create)

## Inputs

### From Previous Tasks

None -- T01 is the phase entry point.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/index-utils.sh` -- provides `get_project_root()`.
  Sourced by graph-db.sh. The function walks up from script location to find
  `extension.yml`, or uses `$PROJECT_ROOT` env var if set. Returns the
  absolute path to the project root.

- `scripts/knowledge/lib/detail-utils.sh` -- reference for double-sourcing
  guard pattern and `fm_field()` helper. The guard shape is:
  ```
  [ -n "${_DETAIL_UTILS_SOURCED:-}" ] && return 0
  _DETAIL_UTILS_SOURCED=1
  ```
  graph-db.sh replicates this with `_GRAPH_DB_SOURCED`.

- `scripts/lib/errors.sh` -- reference for double-sourcing guard pattern
  (same approach, different variable name).

- `sqlite3` -- the SQLite CLI. Available on macOS as `/usr/bin/sqlite3`.
  Tested by running `sqlite3 :memory: "SELECT 1;"`. If this fails, the
  system does not have sqlite3 installed.

## Expected Output

After completing this task:

1. `scripts/knowledge/lib/graph-db.sh` exists, is chmod +x, has the
   double-sourcing guard `_GRAPH_DB_SOURCED`, and exports six functions:
   `get_db_path`, `db_query`, `db_init`, `db_insert_entry`,
   `db_insert_edge`, `db_insert_scope_tag`.
2. `db_init` on a fresh DB path creates three tables (`entries`, `edges`,
   `scope_tags`) and two indexes.
3. The `entries` table has 14 columns including a `vector BLOB DEFAULT NULL`
   column.
4. The `edges` table has a composite primary key on (source_id, target_id,
   edge_type).
5. The `scope_tags` table has a composite primary key on (entry_id, tag).
6. Seven `scripts/verify/m007-p01-*.sh` files exist and are chmod +x.
7. `bash scripts/verify/m007-p01-graph-db-lib.sh` prints PASS.
8. `bash scripts/verify/m007-p01-schema-entries.sh` prints PASS.
9. `bash scripts/verify/m007-p01-schema-edges.sh` prints PASS.
10. `bash scripts/verify/m007-p01-schema-scope-tags.sh` prints PASS.
11. `git status` shows 8 new files (1 lib + 7 verify scripts). Nothing else
    touched.
