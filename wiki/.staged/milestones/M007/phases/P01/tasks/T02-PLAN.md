---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M007"
name: "Update rebuild-index.sh to populate SQLite DB"
depends_on: ["T01"]
---

## Description

Update `scripts/knowledge/rebuild-index.sh` to source `graph-db.sh` and
populate the SQLite database alongside the existing flat index rebuild.

The existing script already scans all `knowledge/*/MEM*.md` files and extracts
frontmatter fields (id, scope_tags, category, confidence, created_at,
last_verified, hit_count, superseded_by). This task extends it to:

1. Source `graph-db.sh` for SQLite helper functions.
2. Extract additional frontmatter fields needed for the DB: `source_unit`,
   `source_type`, `supersedes`, `content_hash`, `relates_to`.
3. Initialize a temp database and populate it during the existing scan loop.
4. For each entry: insert into `entries` table, parse `relates_to` array
   and insert edges, parse `scope_tags` and insert normalized tags, insert
   `supersedes` edge if non-empty.
5. After the scan loop: atomically move the temp DB to the final path.
6. Report DB statistics alongside the existing flat index count.

### Atomic Rebuild Pattern

The temp-file-then-mv pattern is already used by `write_full_index()` in
index-utils.sh. The same pattern applies to the DB:

```
tmp_db="${db_path}.tmp.$$"
# ... populate tmp_db ...
mv "$tmp_db" "$db_path"
```

This ensures no consumer ever sees a partially populated database.

### relates_to Parsing

The `relates_to` field in frontmatter uses YAML inline list syntax:
- `relates_to: []` -- empty, no edges
- `relates_to: [MEM001, MEM002]` -- two related entries

Parsing: strip `[` and `]`, split on `, ` (comma + space), trim whitespace.
For each resulting ID, insert an edge of type `relates_to` from the current
entry to the target. The `relates_to` relationship is stored as-is (directed
from the entry that declares it). Downstream phases handle bidirectional
traversal via SQL queries on both source_id and target_id.

### scope_tags Parsing

The `scope_tags` field can contain:
- `"[project]"` -- single tag
- `"[milestone:M001]"` -- qualified tag
- `"[phase:M001/P02]"` -- deeply qualified tag

The value may be quoted in frontmatter. After extracting with `fm_field`,
the raw value includes the brackets. Insert the full tag string (including
brackets) as-is into the `scope_tags` table. If the field contains multiple
tags (space-separated), each is inserted as a separate row.

### supersedes Edge

If the `supersedes` field is non-empty (e.g., `supersedes: "MEM001"`), insert
an edge of type `supersedes` from the current entry to the superseded entry.

## Steps

### Step 1 -- Source graph-db.sh

Add a source line for graph-db.sh after the existing source of index-utils.sh
(line 15).

Insert after the `source "$SCRIPT_DIR/lib/index-utils.sh"` line:

```bash
# shellcheck source=lib/graph-db.sh
source "$SCRIPT_DIR/lib/graph-db.sh"
```

### Step 2 -- Initialize temp database before the scan loop

After resolving the project root and checking the knowledge directory exists
(after line 47), add:

```bash
# --- Initialize SQLite graph database ---
db_path="$(get_db_path)"
tmp_db="${db_path}.tmp.$$"
# Remove stale temp DB if it exists
rm -f "$tmp_db"
db_init "$tmp_db"
db_entry_count=0
db_edge_count=0
db_tag_count=0
```

### Step 3 -- Extract additional frontmatter fields in the scan loop

Inside the scan loop, after the existing `superseded_by` extraction (after
line 84), add extractions for the additional fields needed by the DB:

```bash
  source_unit="$(fm_field "$file" "source_unit")"
  source_type="$(fm_field "$file" "source_type")"
  supersedes="$(fm_field "$file" "supersedes")"
  content_hash="$(fm_field "$file" "content_hash")"
  relates_to_raw="$(fm_field "$file" "relates_to")"
```

### Step 4 -- Insert entry into the database

After extracting the description (after line 96 in the current file), insert
the entry into the temp database. This goes BEFORE the superseded_by skip
check, because we want ALL entries in the database (including superseded ones).
The flat index skips superseded entries, but the graph DB keeps them for
provenance chain queries.

Actually -- the skip logic for `superseded_by` must be restructured. Currently
the script skips superseded entries entirely (they never reach the index
formatting code). For the DB, we need to insert ALL entries, but only add
non-superseded entries to the flat index. So:

Move the database insertion to occur BEFORE the superseded_by skip. After
extracting all frontmatter fields and the description, insert into the DB:

```bash
  # --- Populate SQLite database (all entries, including superseded) ---
  # Compute relative file path from project root
  rel_path="${file#$root/}"
  db_insert_entry "$tmp_db" "$id" "$category" "$confidence" "$created_at" \
    "$last_verified" "$hit_count" "$source_unit" "$source_type" \
    "$supersedes" "$superseded_by" "$content_hash" "$description" "$rel_path"
  db_entry_count=$((db_entry_count + 1))

  # --- Insert edges for relates_to ---
  if [ -n "$relates_to_raw" ] && [ "$relates_to_raw" != "[]" ]; then
    # Strip brackets and split on comma
    relates_clean="$(printf '%s' "$relates_to_raw" | tr -d '[]' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    if [ -n "$relates_clean" ]; then
      old_ifs="$IFS"
      IFS=','
      for rel_target in $relates_clean; do
        # Trim whitespace
        rel_target="$(printf '%s' "$rel_target" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
        if [ -n "$rel_target" ]; then
          db_insert_edge "$tmp_db" "$id" "$rel_target" "relates_to"
          db_edge_count=$((db_edge_count + 1))
        fi
      done
      IFS="$old_ifs"
    fi
  fi

  # --- Insert edge for supersedes ---
  if [ -n "$supersedes" ]; then
    db_insert_edge "$tmp_db" "$id" "$supersedes" "supersedes"
    db_edge_count=$((db_edge_count + 1))
  fi

  # --- Insert scope_tags ---
  if [ -n "$scope_tags" ]; then
    # scope_tags may be a single tag like "[project]" or space-separated
    # Handle both quoted and unquoted forms
    tags_clean="$(printf '%s' "$scope_tags" | sed 's/^"//;s/"$//')"
    # Split on spaces that are between ] and [  (e.g., "[project] [milestone:M001]")
    # Simple approach: use sed to put each [...] on its own line, then iterate
    tag_list="$(printf '%s' "$tags_clean" | sed 's/\] \[/]\n[/g')"
    while IFS= read -r single_tag; do
      single_tag="$(printf '%s' "$single_tag" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
      if [ -n "$single_tag" ]; then
        db_insert_scope_tag "$tmp_db" "$id" "$single_tag"
        db_tag_count=$((db_tag_count + 1))
      fi
    done <<EOF_TAGS
$tag_list
EOF_TAGS
  fi
```

### Step 5 -- Restructure the superseded_by skip

The current superseded_by skip (lines 87-89) needs to be moved AFTER the
database insertion code from Step 4 but BEFORE the flat index formatting.
This way superseded entries are in the DB but not in the flat index.

The restructured flow inside the loop body becomes:
1. Extract all frontmatter fields (existing + new)
2. Extract description (existing)
3. Insert into SQLite DB (new -- all entries including superseded)
4. Skip superseded entries for flat index (existing check, relocated)
5. Format flat index entry and append (existing)

### Step 6 -- Atomically move the temp database to the final path

After the scan loop ends and before (or alongside) the flat index write,
move the temp DB:

```bash
# --- Finalize SQLite database (atomic move) ---
mv "$tmp_db" "$db_path"
```

### Step 7 -- Update output reporting

After the existing `echo "REBUILT: KNOWLEDGE-INDEX.md with $entry_count entries"`
line, add:

```bash
echo "REBUILT: knowledge.db with $db_entry_count entries, $db_edge_count edges, $db_tag_count scope_tags"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "rebuild-index.sh populates knowledge.db alongside flat index",
  "knowledge.db is rebuilt atomically using temp-file-then-mv",
  "rebuild-index.sh reports entry, edge, and scope_tag counts".
- **Artifacts**: modified `scripts/knowledge/rebuild-index.sh`.
- **Key Links**: `scripts/knowledge/lib/graph-db.sh -> scripts/knowledge/rebuild-index.sh`.

## Verification

Run the verification scripts:

```bash
bash scripts/verify/m007-p01-rebuild-populates-db.sh
bash scripts/verify/m007-p01-atomic-rebuild.sh
bash scripts/verify/m007-p01-rebuild-db-counts.sh
```

All three should print PASS.

Additionally, run rebuild-index.sh against the project to verify end-to-end:

```bash
bash scripts/knowledge/rebuild-index.sh --root .
```

Expected output includes both lines:
```
REBUILT: KNOWLEDGE-INDEX.md with N entries
REBUILT: knowledge.db with N entries, E edges, S scope_tags
```

(Where N/E/S are counts. If no knowledge entries exist, counts will be 0.)

### Files Touched By This Task

- `scripts/knowledge/rebuild-index.sh` (modify -- source graph-db.sh, add
  SQLite population in scan loop, atomic DB move, count reporting)

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/graph-db.sh` (from T01) -- provides `get_db_path`,
  `db_init`, `db_insert_entry`, `db_insert_edge`, `db_insert_scope_tag`.
  Usage patterns:
  - `get_db_path` returns the absolute path to `knowledge.db`
  - `db_init "$tmp_db"` creates the schema on a fresh temp database
  - `db_insert_entry "$tmp_db" "$id" "$category" "$confidence" "$created_at" "$last_verified" "$hit_count" "$source_unit" "$source_type" "$supersedes" "$superseded_by" "$content_hash" "$description" "$rel_path"` inserts one entry (14 positional args after db_path)
  - `db_insert_edge "$tmp_db" "$id" "$target" "relates_to"` inserts one edge
  - `db_insert_scope_tag "$tmp_db" "$id" "$tag"` inserts one scope_tag

### From Disk (Pre-existing)

- `scripts/knowledge/rebuild-index.sh` -- the file to modify. Current structure
  (121 lines):
  - Lines 1-8: shebang, usage comment, set -euo pipefail
  - Lines 10-15: resolve script dir, source index-utils.sh
  - Lines 17-29: argument parsing (--root)
  - Lines 31-38: fm_field() local helper
  - Lines 40-47: resolve project root, check knowledge/ dir exists
  - Lines 49-51: initialize entries string and counter
  - Lines 53-109: scan loop over knowledge/*/MEM*.md files:
    - Skip archive/ and non-MEM files
    - Extract frontmatter: id, scope_tags, category, confidence, created_at,
      last_verified, hit_count, superseded_by
    - Skip superseded entries (non-empty superseded_by)
    - Extract description from heading
    - Format entry and append to entries string
  - Lines 112-115: sort entries
  - Lines 117-118: write_full_index
  - Line 120: echo REBUILT count

- `scripts/knowledge/lib/index-utils.sh` -- already sourced. Provides
  `get_project_root`, `write_full_index`, `format_index_entry`.

- Knowledge entry files `knowledge/{category}/MEM###.md` -- the source data.
  Frontmatter fields are documented in the phase plan. The `relates_to`
  field uses YAML inline list syntax: `relates_to: [MEM001, MEM002]` or
  `relates_to: []`.

## Expected Output

After completing this task:

1. `scripts/knowledge/rebuild-index.sh` sources `graph-db.sh`.
2. Running `bash scripts/knowledge/rebuild-index.sh --root .` produces both
   the flat index and the SQLite database.
3. The `knowledge.db` file is created at the project root (same location as
   KNOWLEDGE-INDEX.md).
4. The DB contains all entries (including superseded ones) in the `entries`
   table.
5. The `edges` table contains rows for `relates_to` and `supersedes`
   relationships.
6. The `scope_tags` table contains normalized tag-to-entry mappings.
7. The rebuild uses the temp-file-then-mv pattern for the DB.
8. Output includes: `REBUILT: knowledge.db with N entries, E edges, S scope_tags`
9. All three verification scripts print PASS.
10. `git status` shows 1 modified file. Nothing else touched.
