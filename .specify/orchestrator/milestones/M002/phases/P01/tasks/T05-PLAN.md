---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M002"
name: "scope-filter.sh Integration and End-to-End Verification"
depends_on: ["T04"]
---

## Description

Update the existing `scripts/dispatch/scope-filter.sh` to support the new index-based knowledge format (`KNOWLEDGE-INDEX.md`). The updated scope-filter must be able to filter the pipe-delimited index by scope tag, category, and confidence threshold using grep/awk — without reading any detail files. Also perform end-to-end verification of all P01 scripts working together.

## Steps

### Step 1: Update `scripts/dispatch/scope-filter.sh`

The existing `scope-filter.sh` (227 lines) filters the old flat `KNOWLEDGE.md` format and `DECISIONS.md` tables. It needs a new code path for filtering `KNOWLEDGE-INDEX.md`.

**Current behavior to preserve:**
- `--type knowledge` with a `KNOWLEDGE.md` file: existing `filter_knowledge()` function (lines 94-153)
- `--type decisions` with a `DECISIONS.md` file: existing `filter_decisions()` function (lines 158-210)
- Argument parsing: `<file-path> <scope-context> [--type knowledge|decisions] [--depends P01,P03]`

**New behavior to add:**
- When `--type knowledge` is specified AND the file path is `KNOWLEDGE-INDEX.md` (or ends with `INDEX.md`), use the new `filter_knowledge_index()` function
- Support additional options:
  - `--min-confidence CONF` — filter entries with confidence >= threshold (default: 0.0, include all)
  - `--category CAT` — filter entries by category name (optional)
- Auto-detect index format: if the file contains pipe-delimited lines starting with `MEM`, use index filtering

**New `filter_knowledge_index()` function:**

This function reads the pipe-delimited index and filters entries by scope tag matching (same logic as existing scope filter), plus optional confidence and category filters.

```bash
filter_knowledge_index() {
  local min_confidence="${MIN_CONFIDENCE:-0.0}"
  local filter_category="${FILTER_CATEGORY:-}"

  while IFS= read -r line || [ -n "$line" ]; do
    # Pass through header/comment lines
    case "$line" in
      '#'*|'<'*|'') echo "$line"; continue ;;
    esac

    # Parse pipe-delimited fields:
    # MEM### | [scope_tags] | category | confidence | created_at | verified:date | hits:N | description
    local entry_id scope_tags category confidence
    entry_id=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); print $1}')
    scope_tags=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
    category=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')
    confidence=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4}')

    # Filter by category if specified
    if [ -n "$filter_category" ] && [ "$category" != "$filter_category" ]; then
      continue
    fi

    # Filter by minimum confidence
    if [ -n "$min_confidence" ]; then
      local passes
      passes=$(awk "BEGIN { print ($confidence >= $min_confidence) ? 1 : 0 }")
      if [ "$passes" = "0" ]; then
        continue
      fi
    fi

    # Filter by scope tag (reuse existing scope matching logic)
    local include=false

    if [ -z "$scope_tags" ]; then
      # No scope tag — include by default (project-level)
      include=true
    elif echo "$scope_tags" | grep -q "\[project\]"; then
      include=true
    elif echo "$scope_tags" | grep -qE '\[milestone:'; then
      local tag_milestone
      tag_milestone=$(echo "$scope_tags" | grep -oE '\[milestone:[A-Za-z0-9]+\]' | sed 's/\[milestone://' | sed 's/\]//')
      if [ "$tag_milestone" = "$MILESTONE_ID" ]; then
        include=true
      fi
    elif echo "$scope_tags" | grep -qE '\[phase:'; then
      local tag_scope
      tag_scope=$(echo "$scope_tags" | grep -oE '\[phase:[A-Za-z0-9/]+\]' | sed 's/\[phase://' | sed 's/\]//')
      local tag_milestone tag_phase
      tag_milestone=$(echo "$tag_scope" | cut -d/ -f1)
      tag_phase=$(echo "$tag_scope" | cut -d/ -f2)
      if [ "$tag_milestone" = "$MILESTONE_ID" ]; then
        if deps_match "$tag_phase"; then
          include=true
        fi
      fi
    fi

    if [ "$include" = true ]; then
      echo "$line"
    fi
  done < "$FILE_PATH"
}
```

**Integration into the existing main dispatch block (around line 215):**

Update the `case "$FILE_TYPE"` block to detect index format:

```bash
case "$FILE_TYPE" in
  knowledge)
    # Detect if this is the new index format or old flat format
    if echo "$FILE_PATH" | grep -qiE 'INDEX\.md$'; then
      filter_knowledge_index
    elif head -5 "$FILE_PATH" 2>/dev/null | grep -qE '^MEM[0-9]+ \|'; then
      filter_knowledge_index
    else
      filter_knowledge
    fi
    ;;
  decisions)
    filter_decisions
    ;;
  *)
    echo "scope-filter.sh: unknown file type '$FILE_TYPE' (use knowledge or decisions)" >&2
    exit 1
    ;;
esac
```

**Updated argument parsing** — add `--min-confidence` and `--category` options to the existing while loop (around line 22):

```bash
MIN_CONFIDENCE=""
FILTER_CATEGORY=""

# Add to the case block:
    --min-confidence)
      MIN_CONFIDENCE="$2"; shift 2 ;;
    --category)
      FILTER_CATEGORY="$2"; shift 2 ;;
```

### Step 2: End-to-End Verification Script

After updating scope-filter.sh, run a comprehensive end-to-end test sequence that exercises all P01 scripts together. This is a manual verification — run each command and check the output.

**End-to-end test sequence:**

```bash
#!/usr/bin/env bash
# End-to-end test for P01 knowledge storage foundation
set -euo pipefail
echo "=== P01 End-to-End Verification ==="

PASS=0
FAIL=0
check() {
  if eval "$1" >/dev/null 2>&1; then
    echo "PASS: $2"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $2"
    FAIL=$((FAIL + 1))
  fi
}

# --- Setup: Create test entries ---
echo ""
echo "--- Creating test entries ---"
bash scripts/knowledge/create-entry.sh --id MEM701 --category convention --confidence 0.95 --scope-tags "[project]" --source-unit "M002/P01" --source-type execution --description "Project-wide convention" --body "All screens must use SafeAreaProvider."

bash scripts/knowledge/create-entry.sh --id MEM702 --category gotcha --confidence 0.85 --scope-tags "[milestone:M002]" --source-unit "M002/P01" --source-type research --description "M002-scoped gotcha" --body "Watch out for Bash 3.2 arrays." --relates-to "MEM701"

bash scripts/knowledge/create-entry.sh --id MEM703 --category pattern --confidence 0.70 --scope-tags "[phase:M002/P01]" --source-unit "M002/P01" --source-type verification-failure --description "Phase-scoped pattern" --body "Use temp-file-then-mv for atomicity."

bash scripts/knowledge/create-entry.sh --id MEM704 --category gotcha --confidence 0.60 --scope-tags "[milestone:M001]" --source-unit "M001/P03" --source-type execution --description "Old milestone gotcha" --body "This should not match M002 scope."

# --- Verify detail files ---
echo ""
echo "--- Verifying detail files ---"
check "test -f knowledge/convention/MEM701.md" "MEM701 detail file exists"
check "test -f knowledge/gotcha/MEM702.md" "MEM702 detail file exists"
check "test -f knowledge/pattern/MEM703.md" "MEM703 detail file exists"
check "test -f knowledge/gotcha/MEM704.md" "MEM704 detail file exists"
check "grep -q '^id: MEM701' knowledge/convention/MEM701.md" "MEM701 has id frontmatter"
check "grep -q '^relates_to:' knowledge/gotcha/MEM702.md" "MEM702 has relates_to frontmatter"

# --- Verify index ---
echo ""
echo "--- Verifying index ---"
check "test -f KNOWLEDGE-INDEX.md" "Index file exists"
check "grep -q '^MEM701 |' KNOWLEDGE-INDEX.md" "MEM701 in index"
check "grep -q '^MEM702 |' KNOWLEDGE-INDEX.md" "MEM702 in index"
check "grep -q '^MEM703 |' KNOWLEDGE-INDEX.md" "MEM703 in index"
check "grep -q '^MEM704 |' KNOWLEDGE-INDEX.md" "MEM704 in index"

# --- Test idempotency ---
echo ""
echo "--- Testing idempotency ---"
bash scripts/knowledge/create-entry.sh --id MEM701 --category convention --confidence 0.95 --scope-tags "[project]" --source-unit "M002/P01" --source-type execution --description "Project-wide convention" --body "All screens must use SafeAreaProvider."
INDEX_LINES=$(grep -c '^MEM701 |' KNOWLEDGE-INDEX.md)
check "[ '$INDEX_LINES' = '1' ]" "Idempotent create does not duplicate index entry"

# --- Test update ---
echo ""
echo "--- Testing update ---"
bash scripts/knowledge/update-entry.sh --id MEM701 --confidence 0.80 --last-verified now
check "grep -q 'confidence: 0.80' knowledge/convention/MEM701.md" "Confidence updated in detail file"

# --- Test supersede ---
echo ""
echo "--- Testing supersede ---"
bash scripts/knowledge/supersede-entry.sh --old-id MEM704 --new-id MEM702
check "grep -q 'superseded_by:.*MEM702' knowledge/gotcha/MEM704.md" "superseded_by set on old entry"
check "! grep -q '^MEM704 |' KNOWLEDGE-INDEX.md" "Superseded entry removed from index"
check "test -f knowledge/gotcha/MEM704.md" "Superseded detail file preserved"

# --- Test archive ---
echo ""
echo "--- Testing archive ---"
bash scripts/knowledge/archive-entry.sh --id MEM703
check "test -f knowledge/archive/MEM703.md" "Archived file in cold storage"
check "! test -f knowledge/pattern/MEM703.md" "Archived file removed from warm"
check "! grep -q '^MEM703 |' KNOWLEDGE-INDEX.md" "Archived entry removed from index"

# --- Test promote ---
echo ""
echo "--- Testing promote ---"
bash scripts/knowledge/promote-entry.sh --id MEM703
check "test -f knowledge/pattern/MEM703.md" "Promoted file back in warm storage"
check "! test -f knowledge/archive/MEM703.md" "Promoted file removed from archive"
check "grep -q '^MEM703 |' KNOWLEDGE-INDEX.md" "Promoted entry restored to index"

# --- Test rebuild ---
echo ""
echo "--- Testing rebuild ---"
bash scripts/knowledge/rebuild-index.sh
check "grep -q '^MEM701 |' KNOWLEDGE-INDEX.md" "MEM701 in rebuilt index"
check "grep -q '^MEM702 |' KNOWLEDGE-INDEX.md" "MEM702 in rebuilt index"
check "grep -q '^MEM703 |' KNOWLEDGE-INDEX.md" "MEM703 in rebuilt index"
check "! grep -q '^MEM704 |' KNOWLEDGE-INDEX.md" "Superseded MEM704 excluded from rebuilt index"

# --- Test scope-filter on index ---
echo ""
echo "--- Testing scope-filter on index ---"
FILTERED=$(bash scripts/dispatch/scope-filter.sh KNOWLEDGE-INDEX.md M002/P01 --type knowledge)
check "echo '$FILTERED' | grep -q 'MEM701'" "scope-filter includes project-scoped MEM701"
check "echo '$FILTERED' | grep -q 'MEM702'" "scope-filter includes M002-scoped MEM702"
check "echo '$FILTERED' | grep -q 'MEM703'" "scope-filter includes P01-scoped MEM703"

# --- Cleanup ---
echo ""
echo "--- Cleaning up test data ---"
rm -f knowledge/convention/MEM701.md knowledge/gotcha/MEM702.md knowledge/pattern/MEM703.md knowledge/gotcha/MEM704.md
rmdir knowledge/convention knowledge/gotcha knowledge/pattern 2>/dev/null || true
rm -f KNOWLEDGE-INDEX.md

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
```

This test sequence is for manual verification. Do not commit it as a permanent test file — it creates and deletes test data in the working directory.

### Step 3: Verify must-haves pass

After the scope-filter update is complete, verify the phase must-haves:

```bash
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M002/phases/P01
```

All checks should output `PASS:`.

## Must-Haves

This task addresses the following phase must-haves:

**Truths:**
- scope-filter.sh can filter KNOWLEDGE-INDEX.md by scope tag, category, and confidence threshold using grep/awk

**Artifacts:**
- scripts/dispatch/scope-filter.sh (min 100 lines, contains "KNOWLEDGE-INDEX")

**Key Links:**
- scripts/dispatch/scope-filter.sh -> KNOWLEDGE-INDEX.md (index-based filtering)

## Verification

```bash
# Artifact check
test -f scripts/dispatch/scope-filter.sh && echo "PASS: scope-filter.sh exists"
wc -l < scripts/dispatch/scope-filter.sh | awk '{if ($1 >= 100) print "PASS: scope-filter.sh has "$1" lines (min 100)"; else print "FAIL: only "$1" lines"}'
grep -q "KNOWLEDGE-INDEX" scripts/dispatch/scope-filter.sh && echo "PASS: scope-filter.sh references KNOWLEDGE-INDEX"

# Functional check: filter an index
bash scripts/knowledge/create-entry.sh --id MEM601 --category test --confidence 0.90 --scope-tags "[project]" --source-unit "test" --source-type execution --description "Filter test" --body "Body"
RESULT=$(bash scripts/dispatch/scope-filter.sh KNOWLEDGE-INDEX.md M002/P01 --type knowledge)
echo "$RESULT" | grep -q "MEM601" && echo "PASS: scope-filter matched project-scoped entry"

# Cleanup
rm -f knowledge/test/MEM601.md KNOWLEDGE-INDEX.md
rmdir knowledge/test 2>/dev/null || true

# Run phase must-haves check
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M002/phases/P01
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/index-utils.sh` (from T01)
  - Key API: `index_add_entry`, `index_remove_entry`, `format_index_entry`, `get_project_root`
  - Behavior: All writes use temp-file-then-mv. Index at `KNOWLEDGE-INDEX.md`.

- `scripts/knowledge/create-entry.sh` (from T02)
  - Used in verification to create test entries

- `scripts/knowledge/rebuild-index.sh` (from T02)
  - Used in verification to test rebuild

- `scripts/knowledge/update-entry.sh` (from T03)
  - Used in verification to test update

- `scripts/knowledge/supersede-entry.sh` (from T03)
  - Used in verification to test supersede

- `scripts/knowledge/archive-entry.sh` (from T04)
  - Used in verification to test archive

- `scripts/knowledge/promote-entry.sh` (from T04)
  - Used in verification to test promote

- `knowledge/` and `knowledge/archive/` directories (from T01) — exist

### From Disk (Pre-existing)

- `scripts/dispatch/scope-filter.sh` — existing scope filter script (227 lines). Preserves existing `filter_knowledge()` and `filter_decisions()` functions. Adds `filter_knowledge_index()` and new CLI options (`--min-confidence`, `--category`).
  - Existing interface: `scope-filter.sh <file-path> <scope-context> [--type knowledge|decisions] [--depends P01,P03]`
  - Existing functions: `deps_match()` (line 71-89), `filter_knowledge()` (line 94-153), `filter_decisions()` (line 158-210)
  - Modification target: argument parsing loop (line 22-38), main dispatch block (line 215-226)

- `scripts/verify/check-must-haves.sh` — used to verify phase plan must-haves mechanically

## Expected Output

After this task completes:

1. `scripts/dispatch/scope-filter.sh` is updated with a new `filter_knowledge_index()` function
2. Scope filter auto-detects index format (pipe-delimited `MEM###` lines) and routes to the correct filter function
3. Filtering works by scope tag (project, milestone, phase), category, and confidence threshold
4. Existing flat-format filtering (`filter_knowledge`, `filter_decisions`) is preserved and unmodified
5. All P01 scripts work together end-to-end: create -> update -> supersede -> archive -> promote -> rebuild -> scope-filter
6. Phase must-haves check passes: `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M002/phases/P01`
