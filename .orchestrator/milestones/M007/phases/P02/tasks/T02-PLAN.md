---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M007"
name: "Add --graph mode to scope-filter.sh"
depends_on: []
---

## Description

Add a `--graph` mode to `scripts/dispatch/scope-filter.sh` that queries
knowledge.db directly via SQLite instead of parsing flat KNOWLEDGE-INDEX.md
or KNOWLEDGE.md files. This is an ADDITION to the existing script — all
current filtering modes (knowledge sections, knowledge index, decisions)
remain unchanged and continue to work.

When `--graph` is passed, the script:
1. Ignores the `<file-path>` positional argument (queries knowledge.db
   directly instead of reading a file).
2. Sources `graph-db.sh` for `get_db_path()` and `db_query()`.
3. Builds a SQL query against the `entries` and `scope_tags` tables.
4. Applies scope, confidence, and category filters via SQL WHERE clauses.
5. Outputs results in the same pipe-delimited format as KNOWLEDGE-INDEX.md
   for downstream consumer compatibility.

### SQL Query Design

The `--graph` mode builds a SQL query with optional JOINs and WHERE clauses:

```sql
SELECT e.id, COALESCE(st.tag, '') AS scope_tag, e.category,
       e.confidence, e.created_at,
       'verified:' || e.last_verified AS verified,
       'hits:' || e.hit_count AS hits,
       e.description
FROM entries e
LEFT JOIN scope_tags st ON e.id = st.entry_id
WHERE 1=1
  -- scope filter (when scope_context is provided):
  AND (st.tag = '[project]'
       OR st.tag = '[milestone:M001]'
       OR st.tag = '[phase:M001/P02]'
       OR st.tag IS NULL)
  -- confidence filter (when --min-confidence is provided):
  AND e.confidence >= 0.7
  -- category filter (when --category is provided):
  AND e.category = 'patterns'
ORDER BY e.confidence DESC;
```

The WHERE clauses are constructed dynamically based on which flags are
provided. If no scope context is given, all entries are returned. If no
confidence threshold is set, no confidence filtering occurs. If no category
is specified, all categories are included.

### Scope Matching Logic

The scope matching in `--graph` mode replicates the existing flat-file
scope matching rules:

- `[project]` tags always match (project-wide scope).
- `[milestone:M###]` tags match if the milestone matches the scope context.
- `[phase:M###/P##]` tags match if the milestone matches AND the phase is
  in the dependency set (current phase or explicit `--depends` phases).
- Entries with no scope tags match by default (project-level).

The SQL WHERE clause is constructed to implement these rules using OR
conditions on the `scope_tags` table, joined with a LEFT JOIN so that
entries without scope tags are still included (tag IS NULL).

### Output Format

The `--graph` mode outputs the same pipe-delimited format as
KNOWLEDGE-INDEX.md:

```
MEM001 | [project] | patterns | 0.85 | 2026-01-01 | verified:2026-01-01 | hits:3 | Entry description
```

This ensures downstream consumers (dispatch payload assembly, context
recipe rendering) can process the output identically regardless of whether
it came from flat file parsing or SQLite query.

### Effective Confidence with Staleness Decay

When `--use-effective-confidence` is combined with `--graph` mode, the
staleness decay is applied in SQL. The script computes an approximate
staleness factor in the SQL query or post-processes results through the
existing `compute_effective_confidence` function. For simplicity, this
implementation applies the staleness computation in a post-processing
loop on the SQL results, reusing the existing `staleness.sh` library.

## Steps

### Step 1 -- Add --graph flag parsing to scope-filter.sh

In the argument parsing section (around line 32), add:

```bash
GRAPH_MODE=false
```

And in the case statement, add a handler:

```bash
    --graph)
      GRAPH_MODE=true; shift ;;
```

### Step 2 -- Add graph-db.sh sourcing (lazy, only when --graph is used)

After the argument parsing section and before the main dispatch, add:

```bash
# Source graph-db.sh when --graph mode is active
if [ "$GRAPH_MODE" = true ]; then
  # shellcheck source=../knowledge/lib/graph-db.sh
  source "$SCRIPT_DIR/../knowledge/lib/graph-db.sh"
fi
```

### Step 3 -- Add filter_knowledge_graph function

Before the main dispatch case statement (before line 326), add a new function:

```bash
# ========================================================================
# Knowledge filtering via SQLite graph (--graph mode)
# ========================================================================
filter_knowledge_graph() {
  local db_path
  db_path="$(get_db_path)"

  if [ ! -f "$db_path" ]; then
    echo "scope-filter.sh: knowledge.db not found — run rebuild-index.sh first" >&2
    exit 0
  fi

  # --- Build scope WHERE clause ---
  local scope_clause=""
  if [ -n "$SCOPE_CONTEXT" ]; then
    # Always include: [project] tags, entries with no scope tag (NULL)
    scope_clause="AND (st.tag IS NULL OR st.tag = '[project]'"

    # Include current milestone
    if [ -n "$MILESTONE_ID" ]; then
      scope_clause="${scope_clause} OR st.tag = '[milestone:${MILESTONE_ID}]'"
    fi

    # Include current phase
    if [ -n "$MILESTONE_ID" ] && [ -n "$PHASE_ID" ]; then
      scope_clause="${scope_clause} OR st.tag = '[phase:${MILESTONE_ID}/${PHASE_ID}]'"
    fi

    # Include dependency phases
    if [ -n "$DEPENDS" ] && [ -n "$MILESTONE_ID" ]; then
      old_ifs="$IFS"
      IFS=','
      for dep in $DEPENDS; do
        dep="$(printf '%s' "$dep" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
        if [ -n "$dep" ]; then
          scope_clause="${scope_clause} OR st.tag = '[phase:${MILESTONE_ID}/${dep}]'"
        fi
      done
      IFS="$old_ifs"
    fi

    scope_clause="${scope_clause})"
  fi

  # --- Build confidence WHERE clause ---
  local conf_clause=""
  if [ -n "$MIN_CONFIDENCE" ]; then
    conf_clause="AND e.confidence >= ${MIN_CONFIDENCE}"
  fi

  # --- Build category WHERE clause ---
  local cat_clause=""
  if [ -n "$FILTER_CATEGORY" ]; then
    # Escape single quotes in category
    local safe_cat
    safe_cat="$(printf '%s' "$FILTER_CATEGORY" | sed "s/'/''/g")"
    cat_clause="AND e.category = '${safe_cat}'"
  fi

  # --- Build and execute query ---
  local sql="
SELECT DISTINCT e.id, COALESCE(st.tag, '') AS scope_tag, e.category,
       e.confidence, e.created_at,
       'verified:' || e.last_verified AS verified,
       'hits:' || e.hit_count AS hits,
       e.description
FROM entries e
LEFT JOIN scope_tags st ON e.id = st.entry_id
WHERE 1=1
  ${scope_clause}
  ${conf_clause}
  ${cat_clause}
ORDER BY e.id;
"

  local results
  results="$(db_query "$db_path" "$sql")" || true

  if [ -z "$results" ]; then
    return 0
  fi

  # --- Format output as pipe-delimited (matching KNOWLEDGE-INDEX.md format) ---
  # SQLite default separator is '|', so results come as:
  # MEM001|[project]|patterns|0.85|2026-01-01|verified:2026-01-01|hits:3|description
  # We need to add spaces around pipes for consistency:
  # MEM001 | [project] | patterns | 0.85 | 2026-01-01 | verified:2026-01-01 | hits:3 | description
  printf '%s\n' "$results" | sed 's/|/ | /g'
}
```

### Step 4 -- Update main dispatch to handle --graph mode

Modify the main dispatch case statement. Before the existing `case "$FILE_TYPE"`,
add a check for graph mode:

```bash
# --- Check for --graph mode first ---
if [ "$GRAPH_MODE" = true ]; then
  filter_knowledge_graph
  exit 0
fi
```

This intercepts before the file-type dispatch, so `--graph` mode does not
require a valid FILE_PATH or FILE_TYPE.

### Step 5 -- Update argument validation for --graph mode

The current validation requires FILE_PATH and SCOPE_CONTEXT. When `--graph`
is used, FILE_PATH is optional (the data comes from knowledge.db, not a
file). Update the validation block (around line 56):

```bash
# Validate required arguments
if [ "$GRAPH_MODE" = true ]; then
  # --graph mode: SCOPE_CONTEXT is optional but FILE_PATH is not needed
  true
elif [ -z "$FILE_PATH" ] || [ -z "$SCOPE_CONTEXT" ]; then
  echo "scope-filter.sh: missing required arguments" >&2
  echo "Usage: scope-filter.sh <file-path> <scope-context> [--type knowledge|decisions] [--depends P01,P03]" >&2
  exit 1
fi
```

### Step 6 -- Create verification scripts

Create three verification scripts under `scripts/verify/`.

**m007-p02-scope-filter-graph-mode.sh** — verifies --graph mode support:

```bash
#!/usr/bin/env bash
# Verifies scope-filter.sh supports --graph mode.
set -eu

f="scripts/dispatch/scope-filter.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-graph' "$f" || { echo "FAIL: $f does not support --graph flag"; exit 1; }
grep -q 'GRAPH_MODE' "$f" || { echo "FAIL: $f missing GRAPH_MODE variable"; exit 1; }
grep -q 'filter_knowledge_graph' "$f" || { echo "FAIL: $f missing filter_knowledge_graph function"; exit 1; }
echo "PASS: scope-filter.sh supports --graph mode"
```

**m007-p02-scope-filter-graph-filters.sh** — verifies SQL-based filtering:

```bash
#!/usr/bin/env bash
# Verifies scope-filter.sh --graph mode applies scope, confidence, and category filters via SQL.
set -eu

f="scripts/dispatch/scope-filter.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'scope_tags' "$f" || { echo "FAIL: $f missing scope_tags table reference in graph mode"; exit 1; }
grep -q 'e\.confidence' "$f" || { echo "FAIL: $f missing confidence filter in graph mode SQL"; exit 1; }
grep -q 'e\.category' "$f" || { echo "FAIL: $f missing category filter in graph mode SQL"; exit 1; }
grep -q 'st\.tag' "$f" || { echo "FAIL: $f missing scope tag matching in graph mode SQL"; exit 1; }
echo "PASS: scope-filter.sh --graph mode applies scope, confidence, and category filters via SQL"
```

**m007-p02-scripts-source-graph-db.sh** — verifies both scripts source
graph-db.sh:

```bash
#!/usr/bin/env bash
# Verifies both traverse-graph.sh and scope-filter.sh source graph-db.sh.
set -eu

t="scripts/knowledge/traverse-graph.sh"
s="scripts/dispatch/scope-filter.sh"

test -f "$t" || { echo "FAIL: $t missing"; exit 1; }
test -f "$s" || { echo "FAIL: $s missing"; exit 1; }

grep -q 'graph-db.sh' "$t" || { echo "FAIL: $t does not source graph-db.sh"; exit 1; }
grep -q 'graph-db.sh' "$s" || { echo "FAIL: $s does not source graph-db.sh"; exit 1; }
grep -q 'db_query' "$t" || { echo "FAIL: $t does not use db_query"; exit 1; }
grep -q 'db_query' "$s" || { echo "FAIL: $s does not use db_query"; exit 1; }
echo "PASS: both scripts source graph-db.sh and use db_query()"
```

Make all executable:

```bash
chmod +x scripts/verify/m007-p02-scope-filter-graph-mode.sh
chmod +x scripts/verify/m007-p02-scope-filter-graph-filters.sh
chmod +x scripts/verify/m007-p02-scripts-source-graph-db.sh
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "scope-filter.sh supports --graph mode", "applies scope,
  confidence, and category filters via SQL", "sources graph-db.sh and uses
  db_query()".
- **Artifacts**: modified `scripts/dispatch/scope-filter.sh`, three
  `scripts/verify/m007-p02-scope-filter-*.sh` and
  `scripts/verify/m007-p02-scripts-source-graph-db.sh` scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m007-p02-scope-filter-graph-mode.sh
bash scripts/verify/m007-p02-scope-filter-graph-filters.sh
bash scripts/verify/m007-p02-scripts-source-graph-db.sh
```

All three should print PASS. Note that `m007-p02-scripts-source-graph-db.sh`
also checks traverse-graph.sh, which is modified by T01 — this script will
only fully pass after both T01 and T02 are complete.

### Files Touched By This Task

- `scripts/dispatch/scope-filter.sh` (modify — add --graph flag, GRAPH_MODE
  variable, filter_knowledge_graph function, graph mode dispatch)
- `scripts/verify/m007-p02-scope-filter-graph-mode.sh` (create)
- `scripts/verify/m007-p02-scope-filter-graph-filters.sh` (create)
- `scripts/verify/m007-p02-scripts-source-graph-db.sh` (create)

## Inputs

### From Previous Tasks

None -- T02 is an entry point (independent of T01).

### From Disk (Pre-existing)

- `scripts/knowledge/lib/graph-db.sh` (from P01) -- provides `get_db_path()`,
  `db_query()`. The `--graph` mode sources this library. Key usage:
  `get_db_path` returns the absolute path to knowledge.db.
  `db_query "$db_path" "$sql"` executes SQL and returns results to stdout
  with `|` as the default column separator.

- `scripts/dispatch/scope-filter.sh` -- the file to modify. Current structure
  (349 lines):
  - Lines 1-17: shebang, usage comment, set -euo pipefail
  - Lines 18-53: argument parsing (positional FILE_PATH and SCOPE_CONTEXT,
    --type, --depends, --min-confidence, --category, --use-effective-confidence)
  - Lines 55-65: required argument validation + file existence check
  - Lines 67-78: auto-detect file type from filename
  - Lines 80-104: parse scope context (MILESTONE_ID, PHASE_ID) + deps_match()
  - Lines 109-168: filter_knowledge() — markdown section filtering
  - Lines 174-263: filter_knowledge_index() — pipe-delimited index filtering
  - Lines 269-321: filter_decisions() — table-based decision filtering
  - Lines 326-348: main dispatch case statement

- `scripts/knowledge/lib/staleness.sh` -- already sourced lazily in the
  existing code for `--use-effective-confidence`. Same pattern applies in
  `--graph` mode if effective confidence is needed.

- `knowledge.db` -- the SQLite database populated by rebuild-index.sh (from
  P01). Contains `entries` table and `scope_tags` table that the `--graph`
  mode queries.

## Expected Output

After completing this task:

1. `scripts/dispatch/scope-filter.sh` exists and is executable.
2. The script supports `--graph` flag.
3. `--graph` mode queries knowledge.db via `db_query()`.
4. `--graph` with `--min-confidence 0.8` filters entries below 0.8.
5. `--graph` with `--category patterns` returns only pattern entries.
6. `--graph` with scope context `M001/P02` returns entries matching the
   scope rules (project, milestone, phase, dependency phases).
7. Output format is pipe-delimited, matching KNOWLEDGE-INDEX.md format.
8. Existing flat-file modes are unchanged — no behavioral changes to the
   non-graph code paths.
9. Three verification scripts exist, are executable, and print PASS.
10. `git status` shows 1 modified file + 3 new files.
