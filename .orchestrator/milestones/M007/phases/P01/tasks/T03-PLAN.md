---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M007"
name: "Integration testing + verification script validation"
depends_on: ["T02"]
---

## Description

Validate the full SQLite graph backend pipeline by running `rebuild-index.sh`
against fixture knowledge entry files and verifying the resulting
`knowledge.db` contains correct data. This task does NOT create permanent
test files — it uses a temporary directory with fixture entries, runs the
rebuild, inspects the database, and cleans up.

The verification is performed by running rebuild-index.sh with `--root` pointed
at a temp directory containing fixture entries, then querying the resulting
knowledge.db with sqlite3 to confirm:

1. All three tables exist with the correct columns.
2. Entries match the fixture files (correct id, category, confidence, etc.).
3. Edges exist for `relates_to` and `supersedes` relationships.
4. Scope tags are normalized correctly.
5. The `vector` column is NULL for all entries.
6. The flat index (KNOWLEDGE-INDEX.md) is also generated correctly.

After validation, run all seven phase verification scripts to confirm they
pass against the actual modified code.

## Steps

### Step 1 -- Run all seven verification scripts

Execute each verification script and confirm it prints PASS:

```bash
bash scripts/verify/m007-p01-graph-db-lib.sh
bash scripts/verify/m007-p01-schema-entries.sh
bash scripts/verify/m007-p01-schema-edges.sh
bash scripts/verify/m007-p01-schema-scope-tags.sh
bash scripts/verify/m007-p01-rebuild-populates-db.sh
bash scripts/verify/m007-p01-atomic-rebuild.sh
bash scripts/verify/m007-p01-rebuild-db-counts.sh
```

All seven must print PASS. If any fail, the corresponding code from T01 or
T02 has an issue that must be fixed before proceeding.

### Step 2 -- Create fixture directory with test knowledge entries

Create a temporary directory with the required structure and fixture files.
The directory needs:
- `extension.yml` (minimal, so get_project_root finds it)
- `knowledge/patterns/MEM001.md` (basic entry with relates_to)
- `knowledge/patterns/MEM002.md` (entry related to MEM001)
- `knowledge/conventions/MEM003.md` (entry that supersedes MEM001)
- `knowledge/archive/MEM999.md` (archived entry, should be skipped)

Use a temp directory:

```bash
fixture_dir="$(mktemp -d)"
mkdir -p "$fixture_dir/knowledge/patterns"
mkdir -p "$fixture_dir/knowledge/conventions"
mkdir -p "$fixture_dir/knowledge/archive"
touch "$fixture_dir/extension.yml"
```

**MEM001.md** — basic entry with relates_to:

```markdown
---
id: MEM001
scope_tags: "[project]"
category: patterns
confidence: 0.85
created_at: 2026-01-01
last_verified: 2026-01-01
hit_count: 3
source_unit: "M001"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: [MEM002]
content_hash: "sha256:abc123"
---

# MEM001: Test pattern entry

This is a test knowledge entry for integration testing.
```

**MEM002.md** — entry related to MEM001:

```markdown
---
id: MEM002
scope_tags: "[milestone:M001]"
category: patterns
confidence: 0.90
created_at: 2026-01-02
last_verified: 2026-01-02
hit_count: 1
source_unit: "M001"
source_type: discovery
supersedes: ""
superseded_by: ""
relates_to: [MEM001, MEM003]
content_hash: "sha256:def456"
---

# MEM002: Another test pattern

This entry relates to both MEM001 and MEM003.
```

**MEM003.md** — entry that supersedes MEM001:

```markdown
---
id: MEM003
scope_tags: "[phase:M001/P02]"
category: conventions
confidence: 0.95
created_at: 2026-01-03
last_verified: 2026-01-03
hit_count: 0
source_unit: "M001/P02"
source_type: ratification
supersedes: "MEM001"
superseded_by: ""
relates_to: []
content_hash: "sha256:ghi789"
---

# MEM003: Superseding convention

This entry supersedes MEM001 with an updated convention.
```

**MEM999.md** (archive) — should be skipped by rebuild:

```markdown
---
id: MEM999
scope_tags: "[project]"
category: patterns
confidence: 0.50
created_at: 2025-01-01
last_verified: 2025-01-01
hit_count: 0
source_unit: "M000"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
---

# MEM999: Archived entry

This should not appear in the database.
```

### Step 3 -- Run rebuild-index.sh against fixtures

```bash
bash scripts/knowledge/rebuild-index.sh --root "$fixture_dir"
```

Expected output:
```
REBUILT: KNOWLEDGE-INDEX.md with 2 entries
REBUILT: knowledge.db with 3 entries, 4 edges, 3 scope_tags
```

Why 2 flat index entries: MEM003 supersedes MEM001, but the flat index skips
entries based on `superseded_by` not `supersedes`. MEM001 has empty
`superseded_by`, so it appears. Actually, in these fixtures, MEM001's
`superseded_by` is empty, so all 3 appear in the flat index. The archived
MEM999 is skipped (archive/ directory). So the flat index has 3 entries.

Why 3 DB entries: MEM001, MEM002, MEM003 (archive is skipped by directory
filter).

Why 4 edges: MEM001->MEM002 (relates_to), MEM002->MEM001 (relates_to),
MEM002->MEM003 (relates_to), MEM003->MEM001 (supersedes).

Why 3 scope_tags: MEM001->"[project]", MEM002->"[milestone:M001]",
MEM003->"[phase:M001/P02]".

### Step 4 -- Query the database to verify contents

```bash
db_file="$fixture_dir/knowledge.db"

# Verify tables exist
tables="$(sqlite3 "$db_file" ".tables")"
echo "$tables" | grep -q "entries" || { echo "FAIL: entries table missing"; exit 1; }
echo "$tables" | grep -q "edges" || { echo "FAIL: edges table missing"; exit 1; }
echo "$tables" | grep -q "scope_tags" || { echo "FAIL: scope_tags table missing"; exit 1; }

# Verify entry count
entry_count="$(sqlite3 "$db_file" "SELECT COUNT(*) FROM entries;")"
test "$entry_count" -eq 3 || { echo "FAIL: expected 3 entries, got $entry_count"; exit 1; }

# Verify edge count
edge_count="$(sqlite3 "$db_file" "SELECT COUNT(*) FROM edges;")"
test "$edge_count" -eq 4 || { echo "FAIL: expected 4 edges, got $edge_count"; exit 1; }

# Verify scope_tag count
tag_count="$(sqlite3 "$db_file" "SELECT COUNT(*) FROM scope_tags;")"
test "$tag_count" -eq 3 || { echo "FAIL: expected 3 scope_tags, got $tag_count"; exit 1; }

# Verify vector column is NULL for all entries
null_vectors="$(sqlite3 "$db_file" "SELECT COUNT(*) FROM entries WHERE vector IS NULL;")"
test "$null_vectors" -eq 3 || { echo "FAIL: expected 3 NULL vectors, got $null_vectors"; exit 1; }

# Verify specific entry data
mem001_cat="$(sqlite3 "$db_file" "SELECT category FROM entries WHERE id='MEM001';")"
test "$mem001_cat" = "patterns" || { echo "FAIL: MEM001 category=$mem001_cat, expected patterns"; exit 1; }

# Verify supersedes edge exists
supersedes_count="$(sqlite3 "$db_file" "SELECT COUNT(*) FROM edges WHERE edge_type='supersedes';")"
test "$supersedes_count" -eq 1 || { echo "FAIL: expected 1 supersedes edge, got $supersedes_count"; exit 1; }

# Verify relates_to edges
relates_count="$(sqlite3 "$db_file" "SELECT COUNT(*) FROM edges WHERE edge_type='relates_to';")"
test "$relates_count" -eq 3 || { echo "FAIL: expected 3 relates_to edges, got $relates_count"; exit 1; }

echo "All database assertions passed"
```

### Step 5 -- Verify flat index was also generated

```bash
index_file="$fixture_dir/KNOWLEDGE-INDEX.md"
test -f "$index_file" || { echo "FAIL: KNOWLEDGE-INDEX.md not created"; exit 1; }
grep -q "MEM001" "$index_file" || { echo "FAIL: MEM001 missing from index"; exit 1; }
grep -q "MEM002" "$index_file" || { echo "FAIL: MEM002 missing from index"; exit 1; }
echo "Flat index assertions passed"
```

### Step 6 -- Clean up

```bash
rm -rf "$fixture_dir"
```

## Must-Haves

From phase plan, this task validates ALL truths via the verification scripts
and provides end-to-end integration testing with fixture data.

## Verification

All seven verification scripts must print PASS:

```bash
bash scripts/verify/m007-p01-graph-db-lib.sh
bash scripts/verify/m007-p01-schema-entries.sh
bash scripts/verify/m007-p01-schema-edges.sh
bash scripts/verify/m007-p01-schema-scope-tags.sh
bash scripts/verify/m007-p01-rebuild-populates-db.sh
bash scripts/verify/m007-p01-atomic-rebuild.sh
bash scripts/verify/m007-p01-rebuild-db-counts.sh
```

The integration test with fixtures confirms the data is correct beyond what
static file checks can verify.

### Files Touched By This Task

No permanent files are created or modified by this task. The fixture directory
is temporary and cleaned up. If any verification scripts need updates to pass
against the actual code (e.g., a grep pattern that does not match), those
scripts are modified in place.

Possible modifications (only if needed):
- `scripts/verify/m007-p01-*.sh` (fix grep patterns if they do not match
  actual code)

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/graph-db.sh` (from T01) -- the library to test.
- `scripts/knowledge/rebuild-index.sh` (from T02) -- the updated script that
  populates the database.
- `scripts/verify/m007-p01-*.sh` (from T01) -- the verification scripts to run.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/index-utils.sh` -- sourced by rebuild-index.sh.
  Provides `get_project_root`, `write_full_index`, `format_index_entry`.
- `sqlite3` CLI -- used to query the database in verification steps.

## Expected Output

After completing this task:

1. All seven `scripts/verify/m007-p01-*.sh` scripts print PASS.
2. The integration test with fixtures confirms:
   - 3 entries in the database (MEM001, MEM002, MEM003)
   - 4 edges (3 relates_to + 1 supersedes)
   - 3 scope_tags
   - All vector columns are NULL
   - Entry data matches fixture frontmatter
3. The flat index (KNOWLEDGE-INDEX.md) is also generated correctly.
4. No temporary files remain after cleanup.
5. If any verification scripts were modified, `git status` shows those
   changes. Otherwise, no files are touched.
