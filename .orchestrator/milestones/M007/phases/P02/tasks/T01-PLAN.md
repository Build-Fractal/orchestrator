---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M007"
name: "Rewrite traverse-graph.sh with recursive CTE"
depends_on: []
---

## Description

Rewrite `scripts/knowledge/traverse-graph.sh` from a 172-line Bash BFS
implementation to a SQLite recursive CTE query against knowledge.db. The
current script uses temp files for visited-set tracking, frontier management,
and file-by-file frontmatter parsing. The replacement sources `graph-db.sh`,
builds a single recursive CTE query, and executes it via `db_query()`.

### Recursive CTE Design

The core query traverses the `edges` table bidirectionally. The `relates_to`
relationship is stored as directed edges (source_id -> target_id), but
semantically the relationship is bidirectional — if MEM001 relates_to MEM002,
then MEM002 is also related to MEM001. The CTE therefore queries BOTH
directions:

```sql
WITH RECURSIVE reachable(id, depth) AS (
  -- Base case: direct neighbors (both directions) at depth 1
  SELECT target_id, 1 FROM edges
    WHERE source_id = :start_id AND edge_type = 'relates_to'
  UNION
  SELECT source_id, 1 FROM edges
    WHERE target_id = :start_id AND edge_type = 'relates_to'
  UNION ALL
  -- Recursive step: expand from reachable nodes (both directions)
  SELECT e.target_id, r.depth + 1
    FROM edges e JOIN reachable r ON e.source_id = r.id
    WHERE r.depth < :max_hops AND e.edge_type = 'relates_to'
      AND e.target_id != :start_id
  UNION ALL
  SELECT e.source_id, r.depth + 1
    FROM edges e JOIN reachable r ON e.target_id = r.id
    WHERE r.depth < :max_hops AND e.edge_type = 'relates_to'
      AND e.source_id != :start_id
)
SELECT DISTINCT e.id, e.confidence, MIN(r.depth) AS min_depth,
  e.confidence * (1.0 / MIN(r.depth)) AS ranked_score
FROM entries e
JOIN reachable r ON e.id = r.id
WHERE e.id != :start_id
GROUP BY e.id
ORDER BY ranked_score DESC
LIMIT :max_entries;
```

Key design choices:
- `UNION` for base case (deduplicates), `UNION ALL` for recursive step
  (SQLite requires UNION ALL in recursive CTEs; deduplication is handled
  by the outer GROUP BY).
- `MIN(r.depth)` picks the shortest path when an entry is reachable via
  multiple routes.
- `GROUP BY e.id` collapses duplicate reachable rows into one per entry.
- `ranked_score = confidence * (1.0 / min_depth)` — closer entries with
  higher confidence rank first.

### CLI Interface

Preserved flags:
- `--id <entry_id>` (required) — the starting entry ID
- `--max-depth <N>` (default 1) — maximum traversal depth
- `--max-entries <N>` (default 5) — maximum results returned

New flags:
- `--hops <N>` — alias for `--max-depth`
- `--ranked` — output includes confidence, depth, and ranked_score per entry

Default output format (no --ranked):
```
MEM002
MEM003
```

Ranked output format (--ranked):
```
MEM002|0.90|1|0.900000
MEM003|0.85|2|0.425000
```

Fields: `id|confidence|depth|ranked_score`, pipe-delimited.

### Error Handling

- If `--id` is missing, print usage to stderr and exit 1.
- If knowledge.db does not exist, print a warning to stderr and exit 0
  (no results is valid — consistent with current behavior when no detail
  files exist).
- If the starting entry has no edges, output nothing and exit 0.
- If max_entries is reached, emit a WARNING to stderr (same as current).

## Steps

### Step 1 -- Rewrite traverse-graph.sh

Replace the entire file content. The new script:

```bash
#!/usr/bin/env bash
# scripts/knowledge/traverse-graph.sh — Traverse knowledge entry relationship graph
# Given an entry ID, returns related entry IDs using a recursive CTE against knowledge.db.
#
# Usage: traverse-graph.sh --id MEM042 [--max-depth 1] [--hops 1] [--max-entries 5] [--ranked]
#
# Output (default): one related entry ID per line to stdout
# Output (--ranked): id|confidence|depth|ranked_score per line
# Warnings go to stderr. Exit 0 always (no related entries is valid).
#
# Requires: knowledge.db (built by rebuild-index.sh), graph-db.sh library.
# Bash 3.2 compatible (no associative arrays, no mapfile).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/graph-db.sh
source "$SCRIPT_DIR/lib/graph-db.sh"

# --- Defaults ---
entry_id=""
max_depth=1
max_entries=5
ranked=false

# --- Argument parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --id)
      entry_id="$2"
      shift 2
      ;;
    --max-depth|--hops)
      max_depth="$2"
      shift 2
      ;;
    --max-entries)
      max_entries="$2"
      shift 2
      ;;
    --ranked)
      ranked=true
      shift
      ;;
    *)
      echo "traverse-graph.sh: unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

if [ -z "$entry_id" ]; then
  echo "traverse-graph.sh: --id is required" >&2
  echo "Usage: traverse-graph.sh --id MEM042 [--max-depth 1] [--hops 1] [--max-entries 5] [--ranked]" >&2
  exit 1
fi

# --- Resolve database path ---
db_path="$(get_db_path)"

if [ ! -f "$db_path" ]; then
  echo "WARNING: knowledge.db not found at $db_path — run rebuild-index.sh first" >&2
  exit 0
fi

# --- Escape single quotes in entry_id for SQL safety ---
safe_id="$(printf '%s' "$entry_id" | sed "s/'/''/g")"

# --- Build and execute recursive CTE query ---
# Queries both edge directions since relates_to is semantically bidirectional.
# Uses MIN(depth) to pick the shortest path when an entry is reachable via
# multiple routes. Ranks by effective_confidence * (1.0 / min_depth).

if [ "$ranked" = true ]; then
  select_cols="e.id || '|' || e.confidence || '|' || MIN(r.depth) || '|' || printf('%.6f', e.confidence * (1.0 / MIN(r.depth)))"
else
  select_cols="e.id"
fi

sql="
WITH RECURSIVE reachable(id, depth) AS (
  SELECT target_id, 1 FROM edges
    WHERE source_id = '${safe_id}' AND edge_type = 'relates_to'
  UNION
  SELECT source_id, 1 FROM edges
    WHERE target_id = '${safe_id}' AND edge_type = 'relates_to'
  UNION ALL
  SELECT e2.target_id, r.depth + 1
    FROM edges e2 JOIN reachable r ON e2.source_id = r.id
    WHERE r.depth < ${max_depth} AND e2.edge_type = 'relates_to'
      AND e2.target_id != '${safe_id}'
  UNION ALL
  SELECT e2.source_id, r.depth + 1
    FROM edges e2 JOIN reachable r ON e2.target_id = r.id
    WHERE r.depth < ${max_depth} AND e2.edge_type = 'relates_to'
      AND e2.source_id != '${safe_id}'
)
SELECT ${select_cols}
FROM entries e
JOIN reachable r ON e.id = r.id
WHERE e.id != '${safe_id}'
GROUP BY e.id
ORDER BY e.confidence * (1.0 / MIN(r.depth)) DESC
LIMIT ${max_entries};
"

results="$(db_query "$db_path" "$sql")" || true

if [ -n "$results" ]; then
  # Count results to check if we hit the limit
  result_count="$(printf '%s\n' "$results" | wc -l | tr -d ' ')"
  printf '%s\n' "$results"
  if [ "$result_count" -ge "$max_entries" ]; then
    echo "WARNING: max-entries limit ($max_entries) reached, results may be truncated" >&2
  fi
fi

exit 0
```

Make executable:

```bash
chmod +x scripts/knowledge/traverse-graph.sh
```

### Step 2 -- Create verification scripts

Create four verification scripts under `scripts/verify/`.

**m007-p02-traverse-recursive-cte.sh** — verifies traverse-graph.sh uses
a recursive CTE:

```bash
#!/usr/bin/env bash
# Verifies traverse-graph.sh uses a recursive CTE instead of Bash BFS.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'WITH RECURSIVE' "$f" || { echo "FAIL: $f does not contain recursive CTE"; exit 1; }
grep -q 'db_query' "$f" || { echo "FAIL: $f does not use db_query"; exit 1; }
# Verify old BFS artifacts are gone
if grep -q 'mktemp' "$f"; then
  echo "FAIL: $f still uses mktemp (BFS remnant)"; exit 1
fi
if grep -q 'current_frontier' "$f"; then
  echo "FAIL: $f still uses frontier variables (BFS remnant)"; exit 1
fi
echo "PASS: traverse-graph.sh uses recursive CTE, no BFS remnants"
```

**m007-p02-traverse-bidirectional.sh** — verifies bidirectional edge
traversal:

```bash
#!/usr/bin/env bash
# Verifies traverse-graph.sh queries both edge directions (source_id and target_id).
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
# The CTE base case must query both directions
grep -q 'source_id.*AND edge_type' "$f" || { echo "FAIL: $f missing source_id direction in CTE"; exit 1; }
grep -q 'target_id.*AND edge_type' "$f" || { echo "FAIL: $f missing target_id direction in CTE"; exit 1; }
# Verify both directions appear in the recursive step as well
source_count="$(grep -c 'source_id' "$f")"
target_count="$(grep -c 'target_id' "$f")"
test "$source_count" -ge 2 || { echo "FAIL: $f has fewer than 2 source_id references (need base + recursive)"; exit 1; }
test "$target_count" -ge 2 || { echo "FAIL: $f has fewer than 2 target_id references (need base + recursive)"; exit 1; }
echo "PASS: traverse-graph.sh queries both edge directions for bidirectional traversal"
```

**m007-p02-traverse-hops-flag.sh** — verifies --hops flag support:

```bash
#!/usr/bin/env bash
# Verifies traverse-graph.sh supports --hops flag as alias for --max-depth.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-hops' "$f" || { echo "FAIL: $f does not support --hops flag"; exit 1; }
# Verify --hops and --max-depth share the same handler
grep -q '\-\-max-depth|\-\-hops' "$f" || { echo "FAIL: $f does not alias --hops to --max-depth"; exit 1; }
echo "PASS: traverse-graph.sh supports --hops flag"
```

**m007-p02-traverse-ranked-output.sh** — verifies --ranked mode:

```bash
#!/usr/bin/env bash
# Verifies traverse-graph.sh supports --ranked flag for scored output.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-ranked' "$f" || { echo "FAIL: $f does not support --ranked flag"; exit 1; }
grep -q 'ranked_score\|ranked=true' "$f" || { echo "FAIL: $f missing ranked mode logic"; exit 1; }
# Verify the ranking formula uses confidence and depth
grep -q 'confidence.*1\.0.*depth\|confidence.*depth' "$f" || { echo "FAIL: $f missing path-distance ranking formula"; exit 1; }
echo "PASS: traverse-graph.sh supports --ranked output with path-distance scoring"
```

Make all executable:

```bash
chmod +x scripts/verify/m007-p02-traverse-recursive-cte.sh
chmod +x scripts/verify/m007-p02-traverse-bidirectional.sh
chmod +x scripts/verify/m007-p02-traverse-hops-flag.sh
chmod +x scripts/verify/m007-p02-traverse-ranked-output.sh
```

### Step 3 -- Smoke test traverse-graph.sh against a fixture database

Create a temporary knowledge.db with fixture data, run traverse-graph.sh
against it, and verify output:

```bash
fixture_dir="$(mktemp -d)"
mkdir -p "$fixture_dir/knowledge/patterns"
touch "$fixture_dir/extension.yml"

# Create a fixture database directly
db_file="$fixture_dir/knowledge.db"
source scripts/knowledge/lib/graph-db.sh
export PROJECT_ROOT="$fixture_dir"
db_init "$db_file"

# Insert fixture entries
db_insert_entry "$db_file" "MEM001" "patterns" "0.85" "2026-01-01" "2026-01-01" "3" "" "" "" "" "" "Entry one" ""
db_insert_entry "$db_file" "MEM002" "patterns" "0.90" "2026-01-02" "2026-01-02" "1" "" "" "" "" "" "Entry two" ""
db_insert_entry "$db_file" "MEM003" "conventions" "0.70" "2026-01-03" "2026-01-03" "0" "" "" "" "" "" "Entry three" ""

# Insert fixture edges: MEM001 <-> MEM002 <-> MEM003
db_insert_edge "$db_file" "MEM001" "MEM002" "relates_to"
db_insert_edge "$db_file" "MEM002" "MEM003" "relates_to"

# Test 1: 1-hop from MEM001 — should return MEM002 only
result="$(bash scripts/knowledge/traverse-graph.sh --id MEM001 --max-depth 1)"
echo "$result" | grep -q "MEM002" || { echo "FAIL: 1-hop missing MEM002"; exit 1; }

# Test 2: 2-hop from MEM001 — should return MEM002 and MEM003
result="$(bash scripts/knowledge/traverse-graph.sh --id MEM001 --hops 2)"
echo "$result" | grep -q "MEM002" || { echo "FAIL: 2-hop missing MEM002"; exit 1; }
echo "$result" | grep -q "MEM003" || { echo "FAIL: 2-hop missing MEM003"; exit 1; }

# Test 3: --ranked output includes scores
result="$(bash scripts/knowledge/traverse-graph.sh --id MEM001 --hops 2 --ranked)"
echo "$result" | grep -q '|' || { echo "FAIL: ranked output missing pipe delimiters"; exit 1; }

echo "Smoke tests passed"

# Clean up
rm -rf "$fixture_dir"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "traverse-graph.sh uses a recursive CTE", "queries both edge
  directions", "supports --hops flag", "--ranked mode outputs with scores".
- **Artifacts**: rewritten `scripts/knowledge/traverse-graph.sh`, four
  `scripts/verify/m007-p02-traverse-*.sh` scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m007-p02-traverse-recursive-cte.sh
bash scripts/verify/m007-p02-traverse-bidirectional.sh
bash scripts/verify/m007-p02-traverse-hops-flag.sh
bash scripts/verify/m007-p02-traverse-ranked-output.sh
```

All four should print PASS. The smoke test in Step 3 validates runtime
behavior against fixture data.

### Files Touched By This Task

- `scripts/knowledge/traverse-graph.sh` (rewrite)
- `scripts/verify/m007-p02-traverse-recursive-cte.sh` (create)
- `scripts/verify/m007-p02-traverse-bidirectional.sh` (create)
- `scripts/verify/m007-p02-traverse-hops-flag.sh` (create)
- `scripts/verify/m007-p02-traverse-ranked-output.sh` (create)

## Inputs

### From Previous Tasks

None -- T01 is an entry point (independent of T02).

### From Disk (Pre-existing)

- `scripts/knowledge/lib/graph-db.sh` (from P01) -- provides `get_db_path()`,
  `db_query()`, `db_init()`, `db_insert_entry()`, `db_insert_edge()`. The
  rewritten traverse-graph.sh sources this library instead of index-utils.sh.
  Key usage: `db_query "$db_path" "$sql"` executes SQL and returns results
  to stdout.

- `scripts/knowledge/traverse-graph.sh` -- the file to rewrite. Current
  interface: `--id <ID> [--max-depth N] [--max-entries N]`. Output: one
  entry ID per line. The rewrite preserves this interface and adds `--hops`
  and `--ranked`.

- `knowledge.db` -- the SQLite database populated by rebuild-index.sh (from
  P01). Contains `entries` table (14 columns), `edges` table (source_id,
  target_id, edge_type), `scope_tags` table (entry_id, tag).

- `sqlite3` CLI -- available at `/usr/bin/sqlite3` on macOS.

## Expected Output

After completing this task:

1. `scripts/knowledge/traverse-graph.sh` exists and is executable.
2. The script sources `graph-db.sh` (not `index-utils.sh` directly).
3. The script contains a `WITH RECURSIVE` CTE query.
4. The script does NOT contain BFS artifacts: no `mktemp`, no `frontier`,
   no `visited_file`.
5. `--id MEM001 --max-depth 1` returns directly related entries.
6. `--id MEM001 --hops 2` returns entries up to 2 hops away.
7. `--id MEM001 --hops 2 --ranked` returns pipe-delimited output with
   confidence, depth, and ranked_score.
8. Bidirectional traversal works: if MEM001->MEM002 is the only stored
   edge direction, querying from MEM002 still finds MEM001.
9. Four verification scripts exist, are executable, and print PASS.
10. `git status` shows 1 modified file + 4 new files.
