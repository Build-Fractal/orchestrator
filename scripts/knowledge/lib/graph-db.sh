#!/usr/bin/env bash
# scripts/knowledge/lib/graph-db.sh — SQLite graph connection library
# Source this file to use graph DB functions for the knowledge system.
#
# Provides: get_db_path, db_query, db_init, db_insert_entry,
#           db_insert_edge, db_insert_scope_tag
#
# Schema: entries (14 columns + vector stub), edges (directed relationships),
#         scope_tags (normalized tag-to-entry mapping).
#
# Bash 3.2 compatible.
#
# Schema evolution note (M036/P05): the edges.edge_type CHECK enum grew from
# 2 -> 5 values. SQLite cannot ALTER a CHECK constraint; rebuild-from-source
# via rebuild-index.sh is the migration path (rebuild always stages a fresh
# tmp_db before promotion). No long-lived knowledge.db state survives a
# rebuild, so no destructive migration is needed for the orchestrator's
# own DB.

# --- Double-sourcing guard ---
[ -n "${_GRAPH_DB_SOURCED:-}" ] && return 0
_GRAPH_DB_SOURCED=1

# --- Source index-utils.sh for get_project_root() ---
GRAPH_DB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$GRAPH_DB_SCRIPT_DIR/index-utils.sh"

# --- get_db_path: returns path to knowledge.db at project root ---
get_db_path() {
  local root
  root="$(get_project_root)"
  echo "$root/knowledge.db"
}

# --- db_query: wrapper for sqlite3 CLI ---
# Usage: db_query <db_path> <sql>
# Passes SQL via heredoc. Returns sqlite3 exit code.
# Emits DB_ERROR: to stderr on failure.
db_query() {
  local db_path="$1"
  local sql="$2"
  local rc=0

  sqlite3 "$db_path" <<EOF || rc=$?
$sql
EOF

  if [ "$rc" -ne 0 ]; then
    echo "DB_ERROR: sqlite3 exited with code $rc" >&2
  fi
  return "$rc"
}

# --- db_init: create schema with all tables and indexes ---
# Usage: db_init <db_path>
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
  -- Edge-type closed enum. SSOT: references/reference-edge-types.md (M036 P00 T02).
  -- New edge types require: (a) row in the SSOT file, (b) widening this CHECK enum,
  -- (c) extension in scripts/knowledge/rebuild-index.sh (frontmatter read), (d)
  -- extension in scripts/knowledge/traverse-graph.sh if directional walking differs.
  edge_type TEXT NOT NULL CHECK(edge_type IN ('relates_to', 'supersedes', 'cites', 'derived_from', 'applies_to_field')),
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

# --- db_insert_entry: INSERT OR REPLACE a knowledge entry ---
# Usage: db_insert_entry <db_path> <id> <category> <confidence> <created_at>
#   <last_verified> <hit_count> <source_unit> <source_type> <supersedes>
#   <superseded_by> <content_hash> <description> <file_path>
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

  # Escape single quotes for SQL safety
  entry_id="$(echo "$entry_id" | sed "s/'/''/g")"
  category="$(echo "$category" | sed "s/'/''/g")"
  created_at="$(echo "$created_at" | sed "s/'/''/g")"
  last_verified="$(echo "$last_verified" | sed "s/'/''/g")"
  source_unit="$(echo "$source_unit" | sed "s/'/''/g")"
  source_type="$(echo "$source_type" | sed "s/'/''/g")"
  supersedes="$(echo "$supersedes" | sed "s/'/''/g")"
  superseded_by="$(echo "$superseded_by" | sed "s/'/''/g")"
  content_hash="$(echo "$content_hash" | sed "s/'/''/g")"
  description="$(echo "$description" | sed "s/'/''/g")"
  file_path="$(echo "$file_path" | sed "s/'/''/g")"

  # Sanitize numeric fields to prevent SQL injection (strip anything non-numeric)
  confidence="$(printf '%s' "$confidence" | grep -oE '^[0-9.]+$' || printf '0.0')"
  hit_count="$(printf '%s' "$hit_count" | grep -oE '^[0-9]+$' || printf '0')"

  local sql="INSERT OR REPLACE INTO entries (id, category, confidence, created_at, last_verified, hit_count, source_unit, source_type, supersedes, superseded_by, content_hash, description, file_path) VALUES ('${entry_id}', '${category}', ${confidence}, '${created_at}', '${last_verified}', ${hit_count}, '${source_unit}', '${source_type}', '${supersedes}', '${superseded_by}', '${content_hash}', '${description}', '${file_path}');"

  db_query "$db_path" "$sql"
}

# --- db_insert_edge: INSERT OR IGNORE a directed edge ---
# Usage: db_insert_edge <db_path> <source_id> <target_id> <edge_type>
db_insert_edge() {
  local db_path="$1"
  local source_id="$2"
  local target_id="$3"
  local edge_type="$4"

  # Escape single quotes for SQL safety
  source_id="$(echo "$source_id" | sed "s/'/''/g")"
  target_id="$(echo "$target_id" | sed "s/'/''/g")"
  edge_type="$(echo "$edge_type" | sed "s/'/''/g")"

  local sql="INSERT OR IGNORE INTO edges (source_id, target_id, edge_type) VALUES ('${source_id}', '${target_id}', '${edge_type}');"

  db_query "$db_path" "$sql"
}

# --- db_insert_scope_tag: INSERT OR IGNORE a scope tag for an entry ---
# Usage: db_insert_scope_tag <db_path> <entry_id> <tag>
db_insert_scope_tag() {
  local db_path="$1"
  local entry_id="$2"
  local tag="$3"

  # Escape single quotes for SQL safety
  entry_id="$(echo "$entry_id" | sed "s/'/''/g")"
  tag="$(echo "$tag" | sed "s/'/''/g")"

  local sql="INSERT OR IGNORE INTO scope_tags (entry_id, tag) VALUES ('${entry_id}', '${tag}');"

  db_query "$db_path" "$sql"
}
