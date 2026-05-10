---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M011"
name: "Add non-goal exclusion to scope-filter.sh and create end-to-end verification"
depends_on: [T01]
---

## Prerequisites

T01 must be complete:
- `create-entry.sh` accepts `--id SPEC-*` with `--category spec/*`
- `knowledge/spec/non-goal/` directory exists
- SPEC-prefixed entries can be created and indexed

## Description

Modify `scripts/dispatch/scope-filter.sh` to add default exclusion of `spec/non-goal` category entries and a `--include-non-goals` flag to override this behavior. This implements AD-7 (Category-Based Non-Goal Exclusion) from the M011 context document. The exclusion applies to both the flat-file index filtering mode (`filter_knowledge_index`) and the SQLite graph filtering mode (`filter_knowledge_graph`). The end-to-end verification scripts validate the complete P01 surface: SPEC- ID creation, nested directory scanning, non-goal exclusion, and Bash 3.2 compatibility.

## Steps

### Step 1: Add --include-non-goals flag to argument parsing

In `scripts/dispatch/scope-filter.sh`, add a new variable after the existing variable declarations (after line 31):

**Insert after line 31** (after `GRAPH_MODE=false`):

```bash
INCLUDE_NON_GOALS=false
```

Then add the flag handling in the argument parsing `case` block (after line 44, the `--graph)` case):

**Insert after the `--graph)` case**:

```bash
    --include-non-goals)
      INCLUDE_NON_GOALS=true; shift ;;
```

### Step 2: Add non-goal exclusion to filter_knowledge_index()

In the `filter_knowledge_index()` function, after parsing the `category` field (after line 204 where `category` is extracted), add the non-goal exclusion check:

**Insert after line 206** (after `category=...`):

```bash
    # --- Non-goal exclusion (AD-7): skip spec/non-goal unless --include-non-goals ---
    if [[ "$INCLUDE_NON_GOALS" != true && "$category" = "spec/non-goal" ]]; then
      continue
    fi
```

This must be placed before the category filter check (line 207) so that non-goals are excluded even when no `--category` filter is specified.

### Step 3: Add non-goal exclusion to filter_knowledge_graph()

In the `filter_knowledge_graph()` function, add a non-goal exclusion clause to the SQL query. After the `superseded_clause` variable (line 384), add:

**Insert after line 384** (after the `superseded_clause`):

```bash
  # --- Non-goal exclusion (AD-7) ---
  local nongoal_clause=""
  if [ "$INCLUDE_NON_GOALS" != true ]; then
    nongoal_clause="AND e.category != 'spec/non-goal'"
  fi
```

Then add `${nongoal_clause}` to the SQL query WHERE clause. In the SQL string (around line 400), add it after `${superseded_clause}`:

**Modify the SQL query** to include the new clause:

```sql
WHERE 1=1
  ${scope_clause}
  ${conf_clause}
  ${cat_clause}
  ${superseded_clause}
  ${nongoal_clause}
GROUP BY e.id
```

### Step 4: Update filter_knowledge_index to recognize SPEC- prefixed data lines

The current data line detector on line 193 only matches `MEM[0-9]+ \|`:

```bash
if ! echo "$line" | grep -qE '^MEM[0-9]+ \|'; then
```

**Replace line 193** with a pattern that also matches SPEC-prefixed entries:

```bash
if ! echo "$line" | grep -qE '^(MEM[0-9]+|SPEC-[A-Z]+-[0-9]+) \|'; then
```

This allows the index filter to process SPEC-prefixed data lines (e.g., `SPEC-FR-001 | ...`).

### Step 5: Update the usage header comment

Update the script header comment (around lines 3-8) to document the new flag:

**Add to the usage line** (after `--graph`):

```
#                        [--include-non-goals]
```

And add to the flag descriptions:

```
#   --include-non-goals: include spec/non-goal entries (excluded by default per AD-7)
```

### Step 6: Run verification

```
bash scripts/verify/m011-p01-nongoal-exclusion.sh
bash scripts/verify/m011-p01-nongoal-inclusion.sh
bash scripts/verify/m011-p01-bash32-compat.sh
```

All three must print `PASS:` and exit 0.

## Must-Haves

- `scope-filter.sh` excludes `spec/non-goal` category entries by default in both index and graph modes
- `scope-filter.sh --include-non-goals` includes `spec/non-goal` entries when the flag is present
- All modified scripts pass Bash 3.2 syntax check

## Verification

```
bash scripts/verify/m011-p01-nongoal-exclusion.sh
bash scripts/verify/m011-p01-nongoal-inclusion.sh
bash scripts/verify/m011-p01-bash32-compat.sh
```

Each must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks
- `scripts/knowledge/create-entry.sh` (from T01) — accepts `--id SPEC-*` with `--category spec/*`. Used by verification scripts to create test fixtures with `spec/non-goal` category.

### From Disk (Pre-existing)
- `scripts/dispatch/scope-filter.sh` — the script being modified. Argument parsing on lines 33-57 uses `while [[ $# -gt 0 ]]` with `case`. Variables declared on lines 24-31. Three filtering functions: `filter_knowledge()` (markdown sections), `filter_knowledge_index()` (pipe-delimited KNOWLEDGE-INDEX.md), `filter_knowledge_graph()` (SQLite). The index filter on line 193 matches only `^MEM[0-9]+ \|` — needs extending for SPEC- lines. The graph filter builds SQL dynamically with variable clauses (scope, confidence, category, superseded).
- `scripts/knowledge/lib/graph-db.sh` — SQLite operations sourced by scope-filter.sh in graph mode. No changes needed — the `entries` table `category` column is TEXT and supports arbitrary values.

## Constraints

- Bash 3.2 compatible. The `[[ ]]` syntax is already used throughout scope-filter.sh (established pattern).
- The `--include-non-goals` flag is boolean (no value argument). It follows the same pattern as `--use-effective-confidence` and `--graph` in the existing argument parser.
- The non-goal exclusion check must run before the category filter check, so that `--category spec/non-goal` combined with `--include-non-goals` correctly includes non-goal entries.
- The data line regex must accept both MEM### and SPEC-XX-NNN formats without breaking existing MEM-only index files.
- The SQL clause uses `!= 'spec/non-goal'` (exact match) rather than `NOT LIKE 'spec/non-goal%'` to avoid excluding hypothetical future subcategories.

## Expected Output

- `scripts/dispatch/scope-filter.sh` modified: `--include-non-goals` flag added, non-goal exclusion in `filter_knowledge_index()` and `filter_knowledge_graph()`, SPEC- data line recognition in `filter_knowledge_index()`, usage header updated.
- No new files created (verification scripts already exist from phase plan).
- Non-goal entries excluded by default, included when flag is present.
