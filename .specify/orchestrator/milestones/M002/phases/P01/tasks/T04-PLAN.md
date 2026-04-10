---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M002"
name: "archive-entry.sh and promote-entry.sh"
depends_on: ["T03"]
---

## Description

Implement the two cold storage lifecycle scripts: `archive-entry.sh` for moving an entry from warm storage (`knowledge/{category}/`) to cold storage (`knowledge/archive/`) and removing it from the index, and `promote-entry.sh` for moving an entry back from cold storage to warm storage with a confidence reset and index update.

## Steps

### Step 1: Create `scripts/knowledge/archive-entry.sh`

Write an executable script at `scripts/knowledge/archive-entry.sh` that moves a knowledge entry to cold storage.

**Interface:**

```
Usage: archive-entry.sh --id ID

Options:
  --id ID    Entry ID (MEM###) [REQUIRED]

Output:
  "ARCHIVED: <id> moved to knowledge/archive/<id>.md" on success
  "ALREADY_ARCHIVED: <id> is already in knowledge/archive/" if already archived (idempotent)
  Exit 0 on success (including idempotent case)
  Exit 1 if entry not found in either warm or cold storage
```

**What archival does:**

1. Find the detail file in warm storage: scan `knowledge/*/ID.md` (excluding `knowledge/archive/`)
2. If the file is already in `knowledge/archive/`, print "ALREADY_ARCHIVED" and exit 0 (idempotent)
3. If the file is not found anywhere, print error and exit 1
4. Move the file: `mv "knowledge/{category}/{id}.md" "knowledge/archive/{id}.md"`
5. Remove the entry from `KNOWLEDGE-INDEX.md` using `index_remove_entry`
6. If the source category directory is now empty, remove it: `rmdir "knowledge/{category}" 2>/dev/null || true`

**Key implementation details:**

1. Source `scripts/knowledge/lib/index-utils.sh`
2. Use the `find_detail_file` helper or equivalent glob pattern to locate the entry
3. Must distinguish "in warm storage" from "in archive" from "not found at all"
4. `set -euo pipefail` at the top
5. Bash 3.2 compatible

**Finding warm vs. cold storage:**

```bash
find_warm_file() {
  local entry_id="$1"
  local root
  root="$(get_project_root)"
  local file
  for file in "$root"/knowledge/*/"${entry_id}.md"; do
    if [ -f "$file" ]; then
      # Exclude archive directory
      case "$file" in
        */archive/*) continue ;;
      esac
      echo "$file"
      return 0
    fi
  done
  return 1
}

is_archived() {
  local entry_id="$1"
  local root
  root="$(get_project_root)"
  [ -f "$root/knowledge/archive/${entry_id}.md" ]
}
```

### Step 2: Create `scripts/knowledge/promote-entry.sh`

Write an executable script at `scripts/knowledge/promote-entry.sh` that moves an entry from cold storage back to warm storage.

**Interface:**

```
Usage: promote-entry.sh --id ID [--confidence CONF] [--category CAT]

Options:
  --id ID              Entry ID (MEM###) [REQUIRED]
  --confidence CONF    Reset confidence to this value (default: 0.80)
  --category CAT       Category to place entry in (default: read from frontmatter)

Output:
  "PROMOTED: <id> moved to knowledge/<category>/<id>.md with confidence <conf>" on success
  "NOT_ARCHIVED: <id> is not in archive, nothing to promote" if not archived (idempotent)
  Exit 0 on success (including idempotent case)
  Exit 1 if entry not found at all
```

**What promotion does:**

1. Verify the entry exists in `knowledge/archive/{id}.md`
2. If the entry is already in warm storage (not in archive), print "NOT_ARCHIVED" and exit 0 (idempotent)
3. Read the `category` field from the archived file's frontmatter (or use `--category` override)
4. Create the category directory if needed: `mkdir -p "knowledge/{category}"`
5. Move the file: `mv "knowledge/archive/{id}.md" "knowledge/{category}/{id}.md"`
6. Update the frontmatter in the promoted file:
   - Set `confidence` to the reset value (default 0.80)
   - Set `last_verified` to today's date
   - Clear `superseded_by` if it was set (re-activation clears supersession)
7. Re-read frontmatter and add the entry to the index using `index_add_entry`

**Key implementation details:**

1. Source `scripts/knowledge/lib/index-utils.sh`
2. Use `sed_i` portable helper for frontmatter updates (same pattern as T03)
3. Use `fm_field` to read category from frontmatter
4. `set -euo pipefail` at the top
5. Bash 3.2 compatible

**Frontmatter reader (same as T03, inline or shared):**

```bash
fm_field() {
  local file="$1"
  local field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//' | sed 's/[[:space:]]*$//'
}
```

### Step 3: Make scripts executable

```bash
chmod +x scripts/knowledge/archive-entry.sh
chmod +x scripts/knowledge/promote-entry.sh
```

## Must-Haves

This task addresses the following phase must-haves:

**Truths:**
- archive-entry.sh moves an entry to knowledge/archive/ and removes it from the index
- promote-entry.sh moves an entry from knowledge/archive/ back to warm storage and updates the index
- All scripts are Bash 3.2 compatible
- All index writes use the atomic temp-file-then-mv pattern
- All operations are idempotent (archiving an already-archived entry is a no-op)

**Artifacts:**
- scripts/knowledge/archive-entry.sh (min 50 lines, contains "knowledge/archive")
- scripts/knowledge/promote-entry.sh (min 50 lines, contains "knowledge/archive")

**Key Links:**
- scripts/knowledge/archive-entry.sh -> knowledge/archive/ (cold storage target)
- scripts/knowledge/promote-entry.sh -> knowledge/archive/ (cold storage source)

## Verification

```bash
# Artifact checks
test -f scripts/knowledge/archive-entry.sh && echo "PASS: archive-entry.sh exists"
test -f scripts/knowledge/promote-entry.sh && echo "PASS: promote-entry.sh exists"
test -x scripts/knowledge/archive-entry.sh && echo "PASS: archive-entry.sh is executable"
test -x scripts/knowledge/promote-entry.sh && echo "PASS: promote-entry.sh is executable"

# Content checks
grep -q "knowledge/archive" scripts/knowledge/archive-entry.sh && echo "PASS: archive-entry references archive dir"
grep -q "knowledge/archive" scripts/knowledge/promote-entry.sh && echo "PASS: promote-entry references archive dir"

# Bash 3.2 compatibility
! grep -rE 'declare -A|readarray|mapfile' scripts/knowledge/archive-entry.sh scripts/knowledge/promote-entry.sh && echo "PASS: no Bash 4+ features"

# Functional test sequence
bash scripts/knowledge/create-entry.sh --id MEM801 --category test --confidence 0.90 --scope-tags "[project]" --source-unit "test" --source-type execution --description "Archive test" --body "Body"
grep -q "MEM801" KNOWLEDGE-INDEX.md && echo "PASS: entry in index before archive"

# Test archive
bash scripts/knowledge/archive-entry.sh --id MEM801
test -f knowledge/archive/MEM801.md && echo "PASS: detail file moved to archive"
! test -f knowledge/test/MEM801.md && echo "PASS: detail file removed from warm"
! grep -q "^MEM801 |" KNOWLEDGE-INDEX.md && echo "PASS: entry removed from index"

# Test idempotent archive
bash scripts/knowledge/archive-entry.sh --id MEM801
echo "PASS: idempotent archive (no error)"

# Test promote
bash scripts/knowledge/promote-entry.sh --id MEM801
test -f knowledge/test/MEM801.md && echo "PASS: detail file moved back to warm"
! test -f knowledge/archive/MEM801.md && echo "PASS: detail file removed from archive"
grep -q "^MEM801 |" KNOWLEDGE-INDEX.md && echo "PASS: entry restored to index"

# Test idempotent promote
bash scripts/knowledge/promote-entry.sh --id MEM801
echo "PASS: idempotent promote (no error)"

# Clean up
rm -f knowledge/test/MEM801.md KNOWLEDGE-INDEX.md
rmdir knowledge/test 2>/dev/null || true
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/index-utils.sh` (from T01)
  - Key API:
    - `index_add_entry(entry_line)` — atomically appends an entry to the index
    - `index_remove_entry(entry_id)` — atomically removes an entry from the index by ID
    - `format_index_entry(id, scope_tags, category, confidence, created_at, last_verified, hit_count, description)` — formats a pipe-delimited index line
    - `get_project_root()` — returns absolute path to project root
  - Behavior: All write functions use temp-file-then-mv. Index path is `KNOWLEDGE-INDEX.md` at project root.

- `scripts/knowledge/create-entry.sh` (from T02)
  - Behavior: Creates detail files at `knowledge/{category}/{id}.md` with YAML frontmatter. Used in verification to create test data.
  - Detail file frontmatter fields: `id`, `scope_tags`, `category`, `confidence`, `created_at`, `last_verified`, `hit_count`, `source_unit`, `source_type`, `supersedes`, `superseded_by`, `relates_to`

- Shared helpers from T03 (either inlined or in a shared lib):
  - `find_detail_file(entry_id)` — locates detail file by ID across all category directories including archive. Returns full path to stdout, exit 1 if not found.
  - `sed_i(args...)` — portable sed in-place edit (handles BSD vs GNU sed). Usage: `sed_i "s/old/new/" file`
  - `fm_field(file, field_name)` — extracts a YAML frontmatter field value from a detail file. Returns the value to stdout.

- `knowledge/` and `knowledge/archive/` directories (from T01) — directory structure exists

### From Disk (Pre-existing)

- No additional pre-existing files needed beyond T01/T02/T03 outputs.

## Expected Output

After this task completes:

1. `scripts/knowledge/archive-entry.sh` exists and is executable
2. Running `archive-entry.sh --id MEM###` moves the detail file to `knowledge/archive/` and removes the entry from the index
3. Running `archive-entry.sh` on an already-archived entry is a no-op
4. `scripts/knowledge/promote-entry.sh` exists and is executable
5. Running `promote-entry.sh --id MEM###` moves the detail file from archive back to `knowledge/{category}/`, resets confidence, sets last_verified to today, and adds the entry to the index
6. Running `promote-entry.sh` on a non-archived entry is a no-op
7. Both scripts are idempotent and Bash 3.2 compatible
