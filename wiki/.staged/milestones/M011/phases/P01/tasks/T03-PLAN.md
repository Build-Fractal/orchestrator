---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M011"
name: "Update next_entry_id() to skip SPEC- prefixed entries"
depends_on: []
---

## Prerequisites

No upstream tasks. The file `scripts/knowledge/lib/index-utils.sh` exists and contains the `next_entry_id()` function (lines 164-204).

## Description

Update `next_entry_id()` in `scripts/knowledge/lib/index-utils.sh` to skip SPEC-prefixed entries when computing the next MEM### sequence number. Currently, the function scans both the KNOWLEDGE-INDEX.md file and `knowledge/*/MEM*.md` detail files to find the highest MEM### number. The index scan reads every line and extracts `MEM[0-9]+` — this already ignores SPEC- lines because the regex `^MEM[0-9]+` does not match `SPEC-*`. However, the detail file scan glob `knowledge/*/MEM*.md` also needs to account for the nested `knowledge/spec/*/` directories where SPEC- files live, ensuring those files are not accidentally matched.

The key change: the detail file scan glob on line 190 already only matches `MEM*.md` filenames, so SPEC-prefixed files are inherently excluded. No code change is needed for the glob itself. However, the glob does not scan nested directories (`knowledge/spec/*/MEM*.md`), which is fine because no MEM### files should exist under `knowledge/spec/`. To be robust, we add the nested glob path so that if a MEM file were ever placed there, it would be found — and we add a comment clarifying that SPEC- files are intentionally excluded.

## Steps

### Step 1: Extend the detail file scan to cover nested directories

In `scripts/knowledge/lib/index-utils.sh`, the detail file scan on line 190:

```bash
for file in "$root"/knowledge/*/MEM*.md "$root"/knowledge/archive/MEM*.md; do
```

**Replace line 190** with:

```bash
for file in "$root"/knowledge/*/MEM*.md "$root"/knowledge/*/*/MEM*.md "$root"/knowledge/archive/MEM*.md; do
```

This adds `"$root"/knowledge/*/*/MEM*.md` to cover the nested `knowledge/spec/*/` directories. Since the glob matches only `MEM*.md`, SPEC-prefixed files are excluded by filename pattern.

### Step 2: Add clarifying comment about SPEC- exclusion

**Insert a comment before line 190** (the for loop):

```bash
  # Scan detail files for MEM### IDs only. SPEC- prefixed files are excluded
  # by the MEM*.md glob — they never affect the MEM### auto-increment sequence.
```

### Step 3: Verify the index scan also excludes SPEC- lines

Review the index scan on lines 172-183. The regex `grep -oE '^MEM[0-9]+'` on line 173 only matches lines starting with `MEM` followed by digits. Lines starting with `SPEC-` do not match. No change needed — add a comment for clarity:

**Insert a comment before line 172** (the while loop):

```bash
  if [ -f "$index_path" ]; then
    # Extract MEM### IDs only — SPEC- prefixed lines are excluded by the regex.
    local num
```

### Step 4: Run verification

```
bash scripts/verify/m011-p01-next-id-skips-spec.sh
```

Must print `PASS:` and exit 0.

## Must-Haves

- `next_entry_id()` in index-utils.sh returns the correct next MEM### ID even when SPEC-prefixed files exist in the knowledge tree

## Verification

```
bash scripts/verify/m011-p01-next-id-skips-spec.sh
```

Must print `PASS:` and exit 0.

## Inputs

### From Disk (Pre-existing)
- `scripts/knowledge/lib/index-utils.sh` — contains `next_entry_id()` function (lines 164-204). The index scan on lines 169-183 reads KNOWLEDGE-INDEX.md and extracts `MEM[0-9]+` via `grep -oE`. The detail file scan on lines 188-200 iterates over `knowledge/*/MEM*.md` and `knowledge/archive/MEM*.md` globs. Both scans find the highest MEM number and return `MEM{N+1}` with zero-padded 3-digit format.
- `KNOWLEDGE-INDEX.md` — pipe-delimited index file. After T01/T02 complete, this may contain SPEC-prefixed lines. The regex filter in `next_entry_id()` already excludes them.

## Constraints

- Bash 3.2 compatible. Glob patterns with `*/*/` are valid in Bash 3.2.
- The `MEM*.md` glob inherently excludes SPEC-prefixed files. This is by design — SPEC- IDs are externally assigned, not auto-incremented.
- The function must continue to return `MEM001` when no MEM entries exist (even if SPEC entries exist).
- Zero-padding format `MEM%03d` must be preserved.

## Expected Output

- `scripts/knowledge/lib/index-utils.sh` modified: nested glob added to detail file scan, clarifying comments added.
- No new files created (verification script already exists from phase plan).
- `next_entry_id()` returns correct MEM### IDs regardless of SPEC- file presence.
