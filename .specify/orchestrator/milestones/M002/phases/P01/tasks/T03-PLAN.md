---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M002"
name: "update-entry.sh and supersede-entry.sh"
depends_on: ["T02"]
---

## Description

Implement two lifecycle scripts: `update-entry.sh` for modifying confidence, last_verified, and hit_count on an existing entry (with index synchronization), and `supersede-entry.sh` for marking an entry as superseded by a replacement entry (setting `superseded_by`, removing from index, preserving the detail file for audit trail).

## Steps

### Step 1: Create `scripts/knowledge/update-entry.sh`

Write an executable script at `scripts/knowledge/update-entry.sh` that modifies metadata fields on an existing knowledge entry's detail file and atomically updates the index.

**Interface:**

```
Usage: update-entry.sh --id ID [options]

Options:
  --id ID                Entry ID (MEM###) [REQUIRED]
  --confidence CONF      New confidence score 0.0-1.0
  --last-verified DATE   New last_verified date (YYYY-MM-DD), or "now" for today
  --hit-count N          New hit_count value
  --increment-hits       Increment hit_count by 1 (mutually exclusive with --hit-count)

Output:
  "UPDATED: <id> (<fields changed>)" on success
  Exit 0 on success
  Exit 1 if entry not found or no fields specified
```

**Key implementation details:**

1. Source `scripts/knowledge/lib/index-utils.sh`
2. Locate the detail file by scanning `knowledge/*/ID.md` (the category subdirectory is not known in advance)
3. If the detail file doesn't exist, print error to stderr and exit 1
4. For each specified field, update the YAML frontmatter in-place using sed:
   - `sed -i '' "s/^confidence:.*/confidence: ${NEW_VALUE}/" "$detail_file"` (BSD sed on macOS)
   - Handle both BSD sed (`-i ''`) and GNU sed (`-i`) for portability
5. After updating the detail file, re-read the frontmatter and update the index entry atomically using `index_update_entry`
6. If `--last-verified now` is passed, use `date +%Y-%m-%d`
7. If `--increment-hits` is passed, read current hit_count, add 1, write back

**Portable sed -i helper:**

```bash
# Portable in-place sed (BSD macOS vs GNU Linux)
sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}
```

**Finding the detail file by ID (category-agnostic):**

```bash
find_detail_file() {
  local entry_id="$1"
  local root
  root="$(get_project_root)"
  local file
  for file in "$root"/knowledge/*/"${entry_id}.md"; do
    if [ -f "$file" ]; then
      echo "$file"
      return 0
    fi
  done
  # Also check archive
  if [ -f "$root/knowledge/archive/${entry_id}.md" ]; then
    echo "$root/knowledge/archive/${entry_id}.md"
    return 0
  fi
  return 1
}
```

### Step 2: Create `scripts/knowledge/supersede-entry.sh`

Write an executable script at `scripts/knowledge/supersede-entry.sh` that marks an old entry as superseded by a new entry.

**Interface:**

```
Usage: supersede-entry.sh --old-id OLD_ID --new-id NEW_ID

Options:
  --old-id ID    Entry being superseded [REQUIRED]
  --new-id ID    Entry that supersedes the old one [REQUIRED]

Output:
  "SUPERSEDED: <old-id> by <new-id>" on success
  Exit 0 on success (including idempotent case where already superseded)
  Exit 1 if old entry not found, or new entry not found
```

**What supersession does:**

1. Verify both entries exist as detail files on disk
2. Set `superseded_by: NEW_ID` in the old entry's frontmatter
3. Set `supersedes: OLD_ID` in the new entry's frontmatter (if not already set)
4. Remove the old entry from `KNOWLEDGE-INDEX.md` (superseded entries are excluded from the index per the roadmap boundary map)
5. The old detail file stays in place (not moved to archive) — it's preserved for audit trail
6. If old entry is already superseded by the specified new-id, print "ALREADY_SUPERSEDED: <old-id> by <new-id>" and exit 0 (idempotent)

**Key implementation details:**

1. Source `scripts/knowledge/lib/index-utils.sh` for `index_remove_entry`
2. Use the `find_detail_file` helper (defined in step 1 — either inline it or put it in a shared location)
3. Use the `sed_i` portable helper for frontmatter modification
4. Update `superseded_by` in old file: `sed_i "s/^superseded_by:.*/superseded_by: \"${NEW_ID}\"/" "$old_file"`
5. Update `supersedes` in new file: `sed_i "s/^supersedes:.*/supersedes: \"${OLD_ID}\"/" "$new_file"`
6. Remove old entry from index: `index_remove_entry "$OLD_ID"`

**Shared helpers:** Both scripts need `find_detail_file`, `sed_i`, and the frontmatter field reader `fm_field`. Put these in a new shared helper or inline them in each script. Recommended approach: add them to `scripts/knowledge/lib/index-utils.sh` or create `scripts/knowledge/lib/detail-utils.sh`. The choice is left to the implementing agent, but the functions must be available to both scripts.

### Step 3: Make scripts executable

```bash
chmod +x scripts/knowledge/update-entry.sh
chmod +x scripts/knowledge/supersede-entry.sh
```

## Must-Haves

This task addresses the following phase must-haves:

**Truths:**
- update-entry.sh can modify confidence, last_verified, and hit_count on an existing entry
- supersede-entry.sh marks an old entry with superseded_by and removes it from the index
- All scripts are Bash 3.2 compatible
- All index writes use the atomic temp-file-then-mv pattern
- All operations are idempotent

**Artifacts:**
- scripts/knowledge/update-entry.sh (min 50 lines, contains "set -euo pipefail")
- scripts/knowledge/supersede-entry.sh (min 60 lines, contains "superseded_by")

**Key Links:**
- scripts/knowledge/supersede-entry.sh -> KNOWLEDGE-INDEX.md (index removal on supersede)

## Verification

```bash
# Artifact checks
test -f scripts/knowledge/update-entry.sh && echo "PASS: update-entry.sh exists"
test -f scripts/knowledge/supersede-entry.sh && echo "PASS: supersede-entry.sh exists"
test -x scripts/knowledge/update-entry.sh && echo "PASS: update-entry.sh is executable"
test -x scripts/knowledge/supersede-entry.sh && echo "PASS: supersede-entry.sh is executable"

# Content checks
grep -q "confidence" scripts/knowledge/update-entry.sh && echo "PASS: update-entry handles confidence"
grep -q "last_verified" scripts/knowledge/update-entry.sh && echo "PASS: update-entry handles last_verified"
grep -q "hit_count" scripts/knowledge/update-entry.sh && echo "PASS: update-entry handles hit_count"
grep -q "superseded_by" scripts/knowledge/supersede-entry.sh && echo "PASS: supersede-entry sets superseded_by"

# Bash 3.2 compatibility
! grep -rE 'declare -A|readarray|mapfile' scripts/knowledge/update-entry.sh scripts/knowledge/supersede-entry.sh && echo "PASS: no Bash 4+ features"

# Functional test sequence
bash scripts/knowledge/create-entry.sh --id MEM901 --category test --confidence 0.90 --scope-tags "[project]" --source-unit "test" --source-type execution --description "Update test" --body "Body"
bash scripts/knowledge/create-entry.sh --id MEM902 --category test --confidence 0.95 --scope-tags "[project]" --source-unit "test" --source-type execution --description "Superseding entry" --body "Better body"

# Test update
bash scripts/knowledge/update-entry.sh --id MEM901 --confidence 0.80 --last-verified now
grep -q "confidence: 0.80" knowledge/test/MEM901.md && echo "PASS: confidence updated"

# Test supersede
bash scripts/knowledge/supersede-entry.sh --old-id MEM901 --new-id MEM902
grep -q 'superseded_by:.*MEM902' knowledge/test/MEM901.md && echo "PASS: superseded_by set"
! grep -q "^MEM901 |" KNOWLEDGE-INDEX.md && echo "PASS: superseded entry removed from index"

# Clean up
rm -f knowledge/test/MEM901.md knowledge/test/MEM902.md KNOWLEDGE-INDEX.md
rmdir knowledge/test 2>/dev/null || true
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/index-utils.sh` (from T01)
  - Key API:
    - `index_update_entry(entry_id, new_entry_line)` — atomically replaces an entry in the index
    - `index_remove_entry(entry_id)` — atomically removes an entry from the index
    - `index_has_entry(entry_id)` — returns 0 if entry exists in index
    - `index_get_entry(entry_id)` — outputs the full pipe-delimited line for an entry
    - `format_index_entry(id, scope_tags, category, confidence, created_at, last_verified, hit_count, description)` — formats a pipe-delimited index line
    - `get_project_root()` — returns absolute path to project root
  - Behavior: All write functions use temp-file-then-mv. Index path is `KNOWLEDGE-INDEX.md` at project root.

- `scripts/knowledge/create-entry.sh` (from T02)
  - Key API: Creates detail files at `knowledge/{category}/{id}.md` with YAML frontmatter fields: `id`, `scope_tags`, `category`, `confidence`, `created_at`, `last_verified`, `hit_count`, `source_unit`, `source_type`, `supersedes`, `superseded_by`, `relates_to`
  - Behavior: Also adds the entry to `KNOWLEDGE-INDEX.md`. Used in verification tests to set up test data.

- `scripts/knowledge/lib/staleness.sh` (from T01) — not directly used by these scripts, but available

- `knowledge/` directory structure (from T01) — directories exist

### From Disk (Pre-existing)

- No additional pre-existing files needed beyond T01/T02 outputs.

## Expected Output

After this task completes:

1. `scripts/knowledge/update-entry.sh` exists and is executable
2. Running `update-entry.sh --id MEM### --confidence 0.80` updates the detail file's frontmatter and the index
3. Running `update-entry.sh --id MEM### --last-verified now` sets last_verified to today's date
4. Running `update-entry.sh --id MEM### --increment-hits` increments hit_count by 1
5. `scripts/knowledge/supersede-entry.sh` exists and is executable
6. Running `supersede-entry.sh --old-id MEM### --new-id MEM###` sets superseded_by on the old entry, sets supersedes on the new entry, and removes the old entry from the index
7. Both scripts handle the "entry not found" case with error messages to stderr
8. Both scripts are idempotent
