---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M011"
name: "Extend rebuild-index.sh for nested spec directory scanning"
depends_on: [T01]
---

## Prerequisites

T01 must be complete:
- `knowledge/spec/` directory tree exists with 6 subdirectories
- `create-entry.sh` accepts `--id SPEC-*` with `--category spec/*`
- SPEC-prefixed entries can be created at nested paths like `knowledge/spec/requirement/SPEC-FR-001.md`

## Description

Modify `scripts/knowledge/rebuild-index.sh` to discover and index knowledge entries stored in nested `knowledge/spec/*/` directories. Currently, the script scans only `knowledge/*/*.md` (one level of nesting). After this change, it also scans `knowledge/spec/*/*.md` (two levels of nesting for the spec subtree). Both MEM### and SPEC-prefixed entries are indexed into KNOWLEDGE-INDEX.md and knowledge.db.

## Steps

### Step 1: Extend the file scanning glob in rebuild-index.sh

In `scripts/knowledge/rebuild-index.sh`, the main scan loop is on line 65:

```bash
for file in "$knowledge_dir"/*/*.md; do
```

This only matches files one level deep (e.g., [`knowledge/patterns/MEM001.md`](../../../../../knowledge/patterns/MEM001.md)). It does not match files two levels deep (e.g., `knowledge/spec/requirement/SPEC-FR-001.md`).

**Replace line 65** with a two-pass scan that covers both depths:

```bash
for file in "$knowledge_dir"/*/*.md "$knowledge_dir"/*/*/*.md; do
```

This adds a second glob `/*/*/*.md` that matches the nested spec directories. On Bash 3.2, non-matching globs return the literal pattern string, which is handled by the existing `[ ! -f "$file" ]` guard on line 67.

### Step 2: Update the basename filter to accept SPEC- prefixed files

Currently, lines 79-86 skip any file whose basename does not start with `MEM`:

```bash
basename_file="$(basename "$file" .md)"
case "$basename_file" in
  MEM*)
    ;;
  *)
    continue
    ;;
esac
```

**Replace lines 79-86** with a filter that accepts both `MEM*` and `SPEC-*` prefixes:

```bash
basename_file="$(basename "$file" .md)"
case "$basename_file" in
  MEM*|SPEC-*)
    ;;
  *)
    continue
    ;;
esac
```

### Step 3: Update the description extraction for SPEC- entries

Line 104 extracts the description from the heading format `# MEM###: <description>`:

```bash
description="$(grep "^# ${id}:" "$file" | head -1 | sed "s/^# ${id}:[[:space:]]*//")"
```

This already works for SPEC- IDs because `${id}` expands to the actual ID value (e.g., `SPEC-FR-001`). The `grep` pattern `^# SPEC-FR-001:` correctly matches the heading `# SPEC-FR-001: Test requirement`. No change needed here — just verify.

### Step 4: Update the header comment

Update the script header comment (lines 4-5) to document the new scanning behavior:

**Before**:
```
# Scans all detail files in knowledge/*/ (excluding knowledge/archive/) and
# regenerates KNOWLEDGE-INDEX.md atomically via write_full_index().
```

**After**:
```
# Scans all detail files in knowledge/*/ and knowledge/*/*/ (including nested
# spec/ subdirectories, excluding knowledge/archive/) and regenerates
# KNOWLEDGE-INDEX.md atomically via write_full_index().
```

### Step 5: Run verification

```
bash scripts/verify/m011-p01-rebuild-nested-scan.sh
```

Must print `PASS:` and exit 0.

## Must-Haves

- `rebuild-index.sh` discovers and indexes entries under nested `knowledge/spec/*/` directories alongside flat `knowledge/*/` entries

## Verification

```
bash scripts/verify/m011-p01-rebuild-nested-scan.sh
```

Must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks
- `knowledge/spec/` directory tree (from T01) — 6 subdirectories exist. `create-entry.sh` can create SPEC-prefixed entries here.

### From Disk (Pre-existing)
- `scripts/knowledge/rebuild-index.sh` — the script being modified. Main scan loop on line 65 uses glob `"$knowledge_dir"/*/*.md`. Basename filter on lines 79-86 accepts only `MEM*`. Sources `lib/index-utils.sh` and `lib/graph-db.sh`. Uses `fm_field()` helper (lines 36-39) to extract YAML frontmatter fields. Populates both KNOWLEDGE-INDEX.md (via `write_full_index()`) and knowledge.db (via `db_insert_entry()`, `db_insert_edge()`, `db_insert_scope_tag()`).
- `scripts/knowledge/lib/graph-db.sh` — SQLite operations. `db_insert_entry()` accepts `id`, `category`, and other fields. The `category` field is a plain TEXT column — no schema change needed for nested `spec/requirement` values.
- `scripts/knowledge/lib/index-utils.sh` — `format_index_entry()` and `write_full_index()` are format-agnostic (they format whatever ID/category strings are passed). No changes needed.

## Constraints

- Bash 3.2 compatible. The `/*/*/*.md` glob pattern is valid in Bash 3.2.
- Archive exclusion must still work: the existing `case "$file" in */archive/*) continue` on lines 72-75 correctly skips archive files regardless of nesting depth.
- The sort order of KNOWLEDGE-INDEX.md entries (`sort` on line 177) produces a mix of MEM### and SPEC-* entries sorted lexicographically. This is acceptable — MEM entries sort before SPEC entries.
- The SQLite database schema does not need modification. The `entries` table `category` column is TEXT and accepts slash-delimited values like `spec/requirement`.

## Expected Output

- `scripts/knowledge/rebuild-index.sh` modified: glob extended to `/*/*/*.md`, basename filter accepts `SPEC-*`, header comment updated.
- No new files created (verification script already exists from phase plan).
- After running rebuild-index.sh on a tree with both MEM and SPEC entries, KNOWLEDGE-INDEX.md contains all entries and knowledge.db has all entries in the `entries` table.
