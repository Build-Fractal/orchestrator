---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M002"
name: "create-entry.sh and rebuild-index.sh"
depends_on: ["T01"]
---

## Description

Implement the two foundational CRUD scripts: `create-entry.sh` for creating individual knowledge detail files with YAML frontmatter and updating the index, and `rebuild-index.sh` for regenerating the entire index from scanning all detail files on disk. These two scripts establish the canonical detail file format and index format that all other scripts depend on.

## Steps

### Step 1: Create `scripts/knowledge/create-entry.sh`

Write an executable script at `scripts/knowledge/create-entry.sh` that creates a new knowledge detail file at `knowledge/{category}/{entry-id}.md` and atomically updates `KNOWLEDGE-INDEX.md`.

**Interface:**

```
Usage: create-entry.sh [options]

Options:
  --id ID              Entry ID (MEM###). Auto-generated if omitted.
  --category CAT       Category name (convention, gotcha, pattern, decision, etc.) [REQUIRED]
  --confidence CONF    Confidence score 0.0-1.0 (default: 0.90)
  --scope-tags TAGS    Scope tags, e.g., "[project]" or "[milestone:M002]" [REQUIRED]
  --source-unit UNIT   Source unit, e.g., "M002/P01" [REQUIRED]
  --source-type TYPE   Source type: execution|research|verification-failure (default: execution)
  --description DESC   One-line description for index [REQUIRED]
  --body BODY          Multi-line body content for detail file [REQUIRED]
  --supersedes ID      ID of entry this supersedes (optional)
  --relates-to IDS     Comma-separated related IDs (optional)

Output:
  "CREATED: <id> at knowledge/<category>/<id>.md" on success
  Exit 0 on success (including idempotent no-op if entry already exists)
  Exit 1 on missing required arguments
```

**Idempotency:** If a detail file already exists for the given ID, print "EXISTS: <id> already exists at <path>, skipping" and exit 0 (no-op).

**Detail file format (YAML frontmatter + markdown body):**

```markdown
---
id: MEM001
scope_tags: "[project]"
category: convention
confidence: 0.90
created_at: 2026-04-09
last_verified: 2026-04-09
hit_count: 0
source_unit: "M002/P01"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: []
---

# MEM001: Screen wrappers must use SafeAreaProvider not SafeAreaView

Screen wrappers must use SafeAreaProvider not SafeAreaView because...
```

**Key implementation details:**

1. Source `scripts/knowledge/lib/index-utils.sh` for index operations
2. Auto-generate ID using `next_entry_id` if `--id` is not provided
3. Create category directory if it doesn't exist: `mkdir -p "knowledge/${category}"`
4. Write detail file with YAML frontmatter containing all metadata fields
5. Format index entry using `format_index_entry` and add via `index_add_entry`
6. Use `date +%Y-%m-%d` for `created_at` and `last_verified`
7. All error messages to stderr
8. `set -euo pipefail` at the top
9. No associative arrays, no readarray, no mapfile (Bash 3.2)

**Argument parsing pattern (Bash 3.2 compatible):**

```bash
while [ $# -gt 0 ]; do
  case "$1" in
    --id) ENTRY_ID="$2"; shift 2 ;;
    --category) CATEGORY="$2"; shift 2 ;;
    --confidence) CONFIDENCE="$2"; shift 2 ;;
    --scope-tags) SCOPE_TAGS="$2"; shift 2 ;;
    --source-unit) SOURCE_UNIT="$2"; shift 2 ;;
    --source-type) SOURCE_TYPE="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    --supersedes) SUPERSEDES="$2"; shift 2 ;;
    --relates-to) RELATES_TO="$2"; shift 2 ;;
    *) echo "ERROR: unknown option '$1'" >&2; exit 1 ;;
  esac
done
```

### Step 2: Create `scripts/knowledge/rebuild-index.sh`

Write an executable script at `scripts/knowledge/rebuild-index.sh` that scans all detail files in `knowledge/*/` (excluding `knowledge/archive/`) and regenerates `KNOWLEDGE-INDEX.md` atomically.

**Interface:**

```
Usage: rebuild-index.sh [--root <project-root>]

Options:
  --root DIR    Project root directory (default: auto-detect)

Output:
  "REBUILT: KNOWLEDGE-INDEX.md with N entries" on success
  Exit 0 on success
```

**Key implementation details:**

1. Source `scripts/knowledge/lib/index-utils.sh` for `write_full_index` and `format_index_entry`
2. Scan all `.md` files in `knowledge/*/` directories (excluding `knowledge/archive/`)
3. For each detail file, extract frontmatter fields using grep/sed (no jq, no YAML parser):
   - `id`: `grep '^id:' file | sed 's/id: *//'`
   - `scope_tags`: `grep '^scope_tags:' file | sed 's/scope_tags: *//' | sed 's/"//g'`
   - `category`: `grep '^category:' file | sed 's/category: *//'`
   - `confidence`: `grep '^confidence:' file | sed 's/confidence: *//'`
   - `created_at`: `grep '^created_at:' file | sed 's/created_at: *//'`
   - `last_verified`: `grep '^last_verified:' file | sed 's/last_verified: *//'`
   - `hit_count`: `grep '^hit_count:' file | sed 's/hit_count: *//'`
4. Extract the description from the `# MEM###: <description>` heading line in the body
5. Skip files where `superseded_by` is non-empty (superseded entries are excluded from the index)
6. Build entries string, one line per entry
7. Write full index atomically using `write_full_index`
8. Sort entries by ID for deterministic output

**Frontmatter parsing helper** (extract value between `---` delimiters):

```bash
# Extract a frontmatter field value from a detail file
# Usage: fm_field <file> <field_name>
fm_field() {
  local file="$1"
  local field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//' | sed 's/[[:space:]]*$//'
}
```

### Step 3: Make scripts executable

```bash
chmod +x scripts/knowledge/create-entry.sh
chmod +x scripts/knowledge/rebuild-index.sh
```

### Step 4: Verify with a smoke test

```bash
# Create a test entry
bash scripts/knowledge/create-entry.sh \
  --id MEM001 \
  --category convention \
  --confidence 0.90 \
  --scope-tags "[project]" \
  --source-unit "M002/P01" \
  --source-type execution \
  --description "Test entry for verification" \
  --body "This is a test knowledge entry body."

# Verify the detail file
cat knowledge/convention/MEM001.md

# Verify the index
cat KNOWLEDGE-INDEX.md

# Test idempotency — running again should be a no-op
bash scripts/knowledge/create-entry.sh \
  --id MEM001 \
  --category convention \
  --confidence 0.90 \
  --scope-tags "[project]" \
  --source-unit "M002/P01" \
  --source-type execution \
  --description "Test entry for verification" \
  --body "This is a test knowledge entry body."

# Create a second entry
bash scripts/knowledge/create-entry.sh \
  --id MEM002 \
  --category gotcha \
  --confidence 0.85 \
  --scope-tags "[milestone:M002]" \
  --source-unit "M002/P01" \
  --source-type research \
  --description "Second test entry" \
  --body "Another test body." \
  --relates-to "MEM001"

# Rebuild the index and verify it matches
bash scripts/knowledge/rebuild-index.sh

# Clean up test data
rm -f knowledge/convention/MEM001.md knowledge/gotcha/MEM002.md
rmdir knowledge/convention knowledge/gotcha 2>/dev/null || true
rm -f KNOWLEDGE-INDEX.md
```

## Must-Haves

This task addresses the following phase must-haves:

**Truths:**
- create-entry.sh produces a detail file with YAML frontmatter containing id, category, confidence, hit_count, created_at, last_verified, source_unit, supersedes, superseded_by, relates_to fields
- create-entry.sh atomically updates KNOWLEDGE-INDEX.md when creating an entry (writes to temp file, then mv)
- rebuild-index.sh regenerates KNOWLEDGE-INDEX.md by scanning all detail files in knowledge/
- All scripts are Bash 3.2 compatible (no associative arrays, no readarray, no mapfile)
- All index writes use the atomic temp-file-then-mv pattern
- All operations are idempotent (creating an existing entry is a no-op)

**Artifacts:**
- scripts/knowledge/create-entry.sh (min 80 lines, contains "set -euo pipefail")
- scripts/knowledge/rebuild-index.sh (min 60 lines, contains "KNOWLEDGE-INDEX")

**Key Links:**
- scripts/knowledge/create-entry.sh -> KNOWLEDGE-INDEX.md (index update on create)
- scripts/knowledge/rebuild-index.sh -> KNOWLEDGE-INDEX.md (full index rebuild)

## Verification

```bash
# Artifact checks
test -f scripts/knowledge/create-entry.sh && echo "PASS: create-entry.sh exists"
test -f scripts/knowledge/rebuild-index.sh && echo "PASS: rebuild-index.sh exists"
test -x scripts/knowledge/create-entry.sh && echo "PASS: create-entry.sh is executable"
test -x scripts/knowledge/rebuild-index.sh && echo "PASS: rebuild-index.sh is executable"

# Content checks
grep -q "set -euo pipefail" scripts/knowledge/create-entry.sh && echo "PASS: create-entry.sh has strict mode"
grep -q "KNOWLEDGE-INDEX" scripts/knowledge/rebuild-index.sh && echo "PASS: rebuild-index.sh references index"
grep -qE 'mv.*tmp.*INDEX|mv.*KNOWLEDGE-INDEX' scripts/knowledge/create-entry.sh && echo "PASS: create-entry.sh uses atomic mv (via index-utils)"

# Bash 3.2 compatibility
! grep -rE 'declare -A|readarray|mapfile' scripts/knowledge/create-entry.sh scripts/knowledge/rebuild-index.sh && echo "PASS: no Bash 4+ features"

# Functional test
bash scripts/knowledge/create-entry.sh --id MEM999 --category test --confidence 0.90 --scope-tags "[project]" --source-unit "test" --source-type execution --description "Verification test" --body "Test"
grep -q "MEM999" KNOWLEDGE-INDEX.md && echo "PASS: entry appears in index"
grep -q "^id: MEM999" knowledge/test/MEM999.md && echo "PASS: detail file has correct frontmatter"

# Clean up
rm -f knowledge/test/MEM999.md KNOWLEDGE-INDEX.md
rmdir knowledge/test 2>/dev/null || true
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/index-utils.sh` (from T01)
  - Key API:
    - `get_project_root()` — returns absolute path to project root
    - `get_index_path()` — returns absolute path to KNOWLEDGE-INDEX.md
    - `init_index()` — creates index with header if it doesn't exist
    - `index_add_entry(entry_line)` — atomically appends an entry line to the index
    - `index_remove_entry(entry_id)` — atomically removes an entry by MEM### ID
    - `index_has_entry(entry_id)` — returns 0 if entry ID exists in index, 1 if not
    - `format_index_entry(id, scope_tags, category, confidence, created_at, last_verified, hit_count, description)` — formats a pipe-delimited index line
    - `next_entry_id()` — returns the next available MEM### ID
    - `write_full_index(entries_string)` — atomically writes the complete index with header
  - Behavior: All write functions use temp-file-then-mv for atomicity. The index file path is `KNOWLEDGE-INDEX.md` at the project root.
- `scripts/knowledge/lib/staleness.sh` (from T01) — not directly used by this task, but available for reference
- `knowledge/` and `knowledge/archive/` directories (from T01) — directory structure exists with `.gitkeep` files

### From Disk (Pre-existing)

- `scripts/knowledge/append-knowledge.sh` — existing M001 knowledge append script. The new `create-entry.sh` is a separate script (does not replace append-knowledge.sh; both coexist). The old script operates on the flat `KNOWLEDGE.md` format; the new script uses individual detail files.

## Expected Output

After this task completes:

1. `scripts/knowledge/create-entry.sh` exists and is executable
2. Running `create-entry.sh` with required arguments creates a detail file at `knowledge/{category}/{id}.md` with YAML frontmatter and body
3. Running `create-entry.sh` also adds an entry to `KNOWLEDGE-INDEX.md`
4. Running `create-entry.sh` for an existing ID is a no-op (idempotent)
5. `scripts/knowledge/rebuild-index.sh` exists and is executable
6. Running `rebuild-index.sh` scans all non-archived detail files and regenerates the index
7. The index format matches: `MEM### | [scope_tags] | category | confidence | created_at | verified:date | hits:N | description`
