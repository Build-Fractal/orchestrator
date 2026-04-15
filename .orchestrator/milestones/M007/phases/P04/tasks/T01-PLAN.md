---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M007"
name: "Create check-graph-health.sh + update run-doctor.sh + create verification scripts"
depends_on: []
---

## Description

Create `scripts/diagnostics/check-graph-health.sh` -- a standalone diagnostic
script that queries knowledge.db and reports graph health across five dimensions.
Then update `scripts/diagnostics/run-doctor.sh` to include the new check in the
diagnostic suite. Finally, create six static verification scripts that validate
file content patterns.

### check-graph-health.sh Design

The script sources `scripts/knowledge/lib/graph-db.sh` for `get_db_path()` and
`db_query()`. It accepts `--root <project-root>` to override `PROJECT_ROOT`.
If knowledge.db does not exist, it emits `DOCTOR:GRAPH_HEALTH status=skip` and
exits 0.

Five diagnostic checks, all implemented as SQL queries:

**1. Graph Statistics**

```sql
SELECT COUNT(*) FROM entries;
SELECT COUNT(*) FROM edges;
SELECT COUNT(DISTINCT tag) FROM scope_tags;
```

Average degree = (2 * edge_count) / entry_count (each undirected edge contributes
degree to both endpoints; directed edges are counted once but both endpoints
gain degree). For a directed graph, avg degree = edge_count / entry_count for
out-degree, but we report total degree (in + out) as 2 * edges / nodes for
a more intuitive metric. If entry_count is 0, avg degree is 0.

**2. Orphaned Entries**

Entries with no edges (neither as source_id nor target_id in the edges table):

```sql
SELECT e.id FROM entries e
LEFT JOIN edges e1 ON e.id = e1.source_id
LEFT JOIN edges e2 ON e.id = e2.target_id
WHERE e1.source_id IS NULL AND e2.target_id IS NULL;
```

Orphaned entries are not necessarily a problem (e.g., a new entry that hasn't
been linked yet), so they produce a warning, not an error.

**3. Disconnected Components**

Uses a recursive CTE to find connected components. The approach:
- Assign each entry its own id as a starting component label.
- For each entry, use a recursive CTE to walk all reachable entries via edges
  (both directions since relates_to is semantically bidirectional).
- Group entries by the minimum reachable id (component label).
- Count the number of distinct components and the size of the largest.

Since SQLite doesn't support iterating over all nodes in a single recursive CTE
to compute all components efficiently, we use a simpler approach: count entries
that are NOT reachable from the entry with the smallest id. If any exist, there
are multiple components.

Practical approach for the diagnostic:

```sql
-- Pick the first entry (alphabetically)
-- Walk all reachable entries from it
-- Entries NOT in the reachable set form other components
WITH RECURSIVE
first_entry(id) AS (SELECT MIN(id) FROM entries),
reachable(id) AS (
  SELECT id FROM first_entry
  UNION
  SELECT e.target_id FROM edges e JOIN reachable r ON e.source_id = r.id
  UNION
  SELECT e.source_id FROM edges e JOIN reachable r ON e.target_id = r.id
)
SELECT COUNT(*) FROM entries WHERE id NOT IN (SELECT id FROM reachable);
```

If the count is 0, all entries are in one component (or the graph is empty).
If > 0, there are disconnected entries. To get the exact component count we
would need to iterate, but for diagnostics "1 component vs multiple" plus
the largest component size is sufficient. We report:
- Total components: if unreachable_count = 0, components = 1 (or 0 if no entries).
  If unreachable_count > 0, we report "2+" (at least 2 components).
- Largest component size: the reachable set size from the first entry.

For a more precise count, we iterate: pick the first unreachable entry, walk its
component, subtract, repeat. But this is complex in pure SQL. The simpler approach
is sufficient for diagnostics and will be accurate for most practical cases.

Revised approach -- iterate to count components:

We use a shell loop that repeatedly queries for an entry not yet assigned to a
component, walks that component via recursive CTE, and records the component size.
This is O(components * query_time) which is fine for <1000 entries.

```bash
remaining_entries="$(db_query "$db_path" "SELECT id FROM entries;")"
component_count=0
largest_component=0

while [ -n "$remaining_entries" ]; do
  seed="$(printf '%s\n' "$remaining_entries" | head -1)"
  safe_seed="$(printf '%s' "$seed" | sed "s/'/''/g")"

  component="$(db_query "$db_path" "
    WITH RECURSIVE reachable(id) AS (
      SELECT '${safe_seed}'
      UNION
      SELECT e.target_id FROM edges e JOIN reachable r ON e.source_id = r.id
      UNION
      SELECT e.source_id FROM edges e JOIN reachable r ON e.target_id = r.id
    )
    SELECT id FROM reachable;
  ")"

  comp_size="$(printf '%s\n' "$component" | wc -l | tr -d ' ')"
  component_count=$((component_count + 1))
  if [ "$comp_size" -gt "$largest_component" ]; then
    largest_component="$comp_size"
  fi

  # Remove this component's entries from remaining
  # Use grep -v with fixed strings
  new_remaining=""
  while IFS= read -r eid; do
    [ -z "$eid" ] && continue
    in_component=false
    while IFS= read -r cid; do
      [ -z "$cid" ] && continue
      if [ "$eid" = "$cid" ]; then
        in_component=true
        break
      fi
    done <<COMP_EOF
$component
COMP_EOF
    if [ "$in_component" = false ]; then
      new_remaining="${new_remaining}${eid}
"
    fi
  done <<REM_EOF
$remaining_entries
REM_EOF
  remaining_entries="$(printf '%s' "$new_remaining" | sed '/^$/d')"
done
```

This iterative approach is Bash 3.2 compatible and correctly counts all
disconnected components. For databases with <1000 entries, performance is fine.

**4. Broken Supersession Chains**

Entries where `supersedes` references a non-existent entry:

```sql
SELECT e.id, e.supersedes FROM entries e
WHERE e.supersedes != ''
AND NOT EXISTS (SELECT 1 FROM entries e2 WHERE e2.id = e.supersedes);
```

Also check the reverse: entries where `superseded_by` references a non-existent
entry:

```sql
SELECT e.id, e.superseded_by FROM entries e
WHERE e.superseded_by != ''
AND NOT EXISTS (SELECT 1 FROM entries e2 WHERE e2.id = e.superseded_by);
```

**5. Dangling Edges**

Edges where source_id or target_id don't exist in the entries table:

```sql
SELECT e.source_id, e.target_id, e.edge_type FROM edges e
WHERE NOT EXISTS (SELECT 1 FROM entries n WHERE n.id = e.source_id)
   OR NOT EXISTS (SELECT 1 FROM entries n WHERE n.id = e.target_id);
```

### Output Format

```
GRAPH_HEALTH: knowledge.db
  Statistics: 42 entries, 38 edges, 12 scope_tags, avg degree 1.81
  Orphaned entries: 3 (MEM005, MEM012, MEM033)
  Connected components: 5 (largest: 28 entries)
  Broken supersession chains: 0
  Dangling edges: 0
  Overall: HEALTHY
DOCTOR:GRAPH_HEALTH status=ok entries=42 edges=38 orphans=3 components=5 broken_chains=0 dangling=0
```

The human-readable block comes first, then the machine-readable DOCTOR: line.

Overall status logic:
- `ok` -- no broken chains, no dangling edges
- `warn` -- orphans exist OR multiple components (informational warnings)
- `drift` -- broken supersession chains OR dangling edges (integrity issues)
- `skip` -- knowledge.db not found

### run-doctor.sh Integration

Add a new `run_check` call after the existing checks but before the summary.
Guard on knowledge.db existence:

```bash
# Graph health checks (requires knowledge.db from M007)
if [ -f "$PROJECT_ROOT/knowledge.db" ]; then
  run_check "Graph Health" "$SCRIPT_DIR/check-graph-health.sh" "--root $PROJECT_ROOT" "0"
else
  echo "--- Graph Health ---"
  echo "SKIP: knowledge.db not found (run rebuild-index.sh to create)"
  echo ""
fi
```

### AD-19 Compliance

AD-19 requires check commands to be single-script-file shape. check-graph-health.sh
is a single script that sources graph-db.sh (a library) -- this follows the
established pattern of check-orphaned.sh sourcing index-utils.sh.

## Steps

### Step 1 -- Create check-graph-health.sh

Create `scripts/diagnostics/check-graph-health.sh` with:

1. Shebang, header comment, Bash 3.2 notice.
2. Source graph-db.sh (path: `$SCRIPT_DIR/../knowledge/lib/graph-db.sh`).
3. Argument parsing for `--root`.
4. Knowledge.db existence check (skip if missing).
5. Graph statistics query (entry_count, edge_count, scope_tag_count, avg_degree).
6. Orphaned entries query (LEFT JOIN approach).
7. Connected components detection (iterative shell loop with recursive CTE).
8. Broken supersession chains query (both directions).
9. Dangling edges query.
10. Human-readable output block.
11. DOCTOR:GRAPH_HEALTH machine-readable line.

The script must:
- Use `db_query()` for all SQL queries (never call sqlite3 directly).
- Use `get_db_path()` or construct the path from PROJECT_ROOT.
- Be executable (`chmod +x`).
- Exit 0 in all cases (diagnostics should not fail the runner).

### Step 2 -- Update run-doctor.sh

In `scripts/diagnostics/run-doctor.sh`, add the graph health check after the
"Documentation Completeness" check (line 111) and before the summary (line 113).

Add a conditional block that:
- Checks if `$PROJECT_ROOT/knowledge.db` exists.
- If yes, calls `run_check "Graph Health" "$SCRIPT_DIR/check-graph-health.sh" "--root $PROJECT_ROOT" "0"`.
- If no, prints a skip message (not counted toward pass/fail).

### Step 3 -- Create six static verification scripts

All scripts go under `scripts/verify/` and must be executable.

**m007-p04-check-graph-health-exists.sh** -- verifies check-graph-health.sh
exists and sources graph-db.sh:

```bash
#!/usr/bin/env bash
# Verifies check-graph-health.sh exists and sources graph-db.sh.
set -eu
f="scripts/diagnostics/check-graph-health.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }
grep -q 'graph-db\.sh' "$f" || { echo "FAIL: $f does not source graph-db.sh"; exit 1; }
grep -q 'db_query' "$f" || { echo "FAIL: $f does not use db_query"; exit 1; }
echo "PASS: check-graph-health.sh exists and sources graph-db.sh"
```

**m007-p04-graph-statistics.sh** -- verifies statistics queries:

```bash
#!/usr/bin/env bash
# Verifies check-graph-health.sh reports graph statistics.
set -eu
f="scripts/diagnostics/check-graph-health.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'entries' "$f" || { echo "FAIL: $f does not query entries"; exit 1; }
grep -q 'edges' "$f" || { echo "FAIL: $f does not query edges"; exit 1; }
grep -q 'scope_tags' "$f" || { echo "FAIL: $f does not query scope_tags"; exit 1; }
grep -q 'avg.*degree\|degree\|avg_degree' "$f" || { echo "FAIL: $f does not compute avg degree"; exit 1; }
grep -q 'Statistics' "$f" || { echo "FAIL: $f does not output statistics line"; exit 1; }
echo "PASS: check-graph-health.sh reports graph statistics"
```

**m007-p04-orphan-detection.sh** -- verifies orphan detection:

```bash
#!/usr/bin/env bash
# Verifies check-graph-health.sh detects orphaned entries.
set -eu
f="scripts/diagnostics/check-graph-health.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi 'orphan' "$f" || { echo "FAIL: $f does not detect orphaned entries"; exit 1; }
grep -q 'LEFT JOIN' "$f" || { echo "FAIL: $f does not use LEFT JOIN for orphan detection"; exit 1; }
echo "PASS: check-graph-health.sh detects orphaned entries"
```

**m007-p04-integrity-checks.sh** -- verifies supersession and dangling edge checks:

```bash
#!/usr/bin/env bash
# Verifies check-graph-health.sh checks supersession integrity and dangling edges.
set -eu
f="scripts/diagnostics/check-graph-health.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'supersedes' "$f" || { echo "FAIL: $f does not check supersession chains"; exit 1; }
grep -qi 'dangling' "$f" || { echo "FAIL: $f does not check for dangling edges"; exit 1; }
grep -q 'NOT EXISTS' "$f" || { echo "FAIL: $f does not use NOT EXISTS for integrity checks"; exit 1; }
echo "PASS: check-graph-health.sh checks supersession integrity and dangling edges"
```

**m007-p04-doctor-protocol.sh** -- verifies DOCTOR: output format:

```bash
#!/usr/bin/env bash
# Verifies check-graph-health.sh emits DOCTOR:GRAPH_HEALTH structured output.
set -eu
f="scripts/diagnostics/check-graph-health.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'DOCTOR:GRAPH_HEALTH' "$f" || { echo "FAIL: $f does not emit DOCTOR:GRAPH_HEALTH line"; exit 1; }
grep -q 'status=' "$f" || { echo "FAIL: $f does not emit status= in DOCTOR line"; exit 1; }
echo "PASS: check-graph-health.sh emits DOCTOR:GRAPH_HEALTH structured output"
```

**m007-p04-doctor-integration.sh** -- verifies run-doctor.sh includes graph check:

```bash
#!/usr/bin/env bash
# Verifies run-doctor.sh includes graph health check.
set -eu
f="scripts/diagnostics/run-doctor.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'check-graph-health\.sh' "$f" || { echo "FAIL: $f does not call check-graph-health.sh"; exit 1; }
grep -q 'Graph Health' "$f" || { echo "FAIL: $f does not have Graph Health section"; exit 1; }
echo "PASS: run-doctor.sh includes graph health check"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "check-graph-health.sh exists and sources graph-db.sh",
  "reports graph statistics", "detects orphaned entries", "detects broken
  supersession chains and dangling edges", "emits DOCTOR:GRAPH_HEALTH
  structured output", "run-doctor.sh includes graph health check".
- **Artifacts**: `scripts/diagnostics/check-graph-health.sh`,
  modified `scripts/diagnostics/run-doctor.sh`, six `scripts/verify/m007-p04-*.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m007-p04-check-graph-health-exists.sh
bash scripts/verify/m007-p04-graph-statistics.sh
bash scripts/verify/m007-p04-orphan-detection.sh
bash scripts/verify/m007-p04-integrity-checks.sh
bash scripts/verify/m007-p04-doctor-protocol.sh
bash scripts/verify/m007-p04-doctor-integration.sh
```

All six should print PASS.

### Files Touched By This Task

- `scripts/diagnostics/check-graph-health.sh` (create)
- `scripts/diagnostics/run-doctor.sh` (modify -- add graph health check)
- `scripts/verify/m007-p04-check-graph-health-exists.sh` (create)
- `scripts/verify/m007-p04-graph-statistics.sh` (create)
- `scripts/verify/m007-p04-orphan-detection.sh` (create)
- `scripts/verify/m007-p04-integrity-checks.sh` (create)
- `scripts/verify/m007-p04-doctor-protocol.sh` (create)
- `scripts/verify/m007-p04-doctor-integration.sh` (create)

## Inputs

### From Previous Tasks

None -- T01 is the entry point for P04.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/graph-db.sh` (from P01) -- provides `get_db_path()`,
  `db_query()`, `db_init()`. The diagnostic sources this library for all DB
  access. Double-sourcing guard prevents issues if also sourced elsewhere.

- `scripts/knowledge/lib/index-utils.sh` -- provides `get_project_root()`.
  Sourced transitively by graph-db.sh. Uses `$PROJECT_ROOT` env var when set.

- `scripts/diagnostics/run-doctor.sh` -- the existing diagnostic runner. Uses
  `run_check()` function to invoke check scripts, parse DOCTOR: output, and
  aggregate pass/fail counts. Supports `--root` and `--format` flags.

- `knowledge.db` -- SQLite database with three tables: `entries` (14 columns +
  vector stub), `edges` (source_id, target_id, edge_type), `scope_tags`
  (entry_id, tag). May not exist if rebuild-index.sh hasn't been run.

## Expected Output

After completing this task:

1. `scripts/diagnostics/check-graph-health.sh` exists and is executable.
2. The script sources graph-db.sh and uses db_query for all SQL.
3. The script emits a human-readable block with statistics, orphans, components,
   broken chains, and dangling edges.
4. The script emits a DOCTOR:GRAPH_HEALTH machine-readable line.
5. The script exits 0 in all cases (including skip when DB missing).
6. `scripts/diagnostics/run-doctor.sh` includes the graph health check
   conditionally (only when knowledge.db exists).
7. Six verification scripts exist, are executable, and print PASS.
8. `git status` shows 1 modified file + 7 new files.
