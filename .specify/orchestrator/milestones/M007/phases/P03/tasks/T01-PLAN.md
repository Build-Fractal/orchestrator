---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M007"
name: "Add --provenance flag and CTE to traverse-graph.sh + create verification scripts"
depends_on: []
---

## Description

Add a `--provenance` flag to `scripts/knowledge/traverse-graph.sh` that
triggers a supersession chain query instead of the normal relates_to graph
traversal. When `--provenance` is used, the script follows the `supersedes`
and `superseded_by` columns in the `entries` table to reconstruct the full
evolution chain for a knowledge entry.

### Supersession Chain Model

Knowledge entries evolve through supersession:

```
MEM010 (original)
  superseded_by: MEM020
MEM020 (revision)
  supersedes: MEM010
  superseded_by: MEM030
MEM030 (current)
  supersedes: MEM020
```

Given any entry in the chain, `--provenance` reconstructs the full chain
from origin to current.

### Recursive CTE Design

Two CTEs walk the chain in both directions from the starting entry:

**Backward walk** (find the origin): follows the `supersedes` column from
the starting entry. Each entry's `supersedes` field names its predecessor.

```sql
WITH RECURSIVE backward(id, depth) AS (
  SELECT id, 0 FROM entries WHERE id = :start_id
  UNION ALL
  SELECT e.supersedes, b.depth - 1
  FROM entries e JOIN backward b ON e.id = b.id
  WHERE e.supersedes != ''
)
```

**Forward walk** (find the tip): follows the `superseded_by` column from
the starting entry. Each entry's `superseded_by` field names its successor.

```sql
WITH RECURSIVE forward(id, depth) AS (
  SELECT id, 0 FROM entries WHERE id = :start_id
  UNION ALL
  SELECT e.superseded_by, f.depth + 1
  FROM entries e JOIN forward f ON e.id = f.id
  WHERE e.superseded_by != ''
)
```

Both are combined in a single query with two CTEs. Backward entries get
negative depth values (origin is the most negative), the starting entry
is depth 0, and forward entries get positive depth values. The final
SELECT orders by depth ascending to produce the chain from origin to tip.

The combined query:

```sql
WITH RECURSIVE
backward(id, depth) AS (
  SELECT id, 0 FROM entries WHERE id = :start_id
  UNION ALL
  SELECT e.supersedes, b.depth - 1
  FROM entries e JOIN backward b ON e.id = b.id
  WHERE e.supersedes != ''
),
forward(id, depth) AS (
  SELECT superseded_by, 1 FROM entries
  WHERE id = :start_id AND superseded_by != ''
  UNION ALL
  SELECT e.superseded_by, f.depth + 1
  FROM entries e JOIN forward f ON e.id = f.id
  WHERE e.superseded_by != ''
)
SELECT e.id, e.confidence, e.created_at, e.description, c.depth
FROM (
  SELECT id, depth FROM backward
  UNION ALL
  SELECT id, depth FROM forward
) c
JOIN entries e ON e.id = c.id
ORDER BY c.depth ASC;
```

Key design choices:
- Backward walk starts at depth 0 and decrements. Forward walk starts at
  depth 1 and increments. This avoids double-counting the start entry.
- `UNION ALL` between backward and forward is correct because the start
  entry only appears in backward (at depth 0).
- Depth ordering: most negative = origin, 0 = start entry, most positive = tip.
- The query walks entries, not edges. The `supersedes` column on each entry
  directly names the predecessor. No JOIN on the `edges` table is needed.

### CLI Interface

New flag:
- `--provenance` — triggers supersession chain query instead of relates_to traversal

When `--provenance` is used:
- `--max-depth`, `--hops`, `--max-entries`, and `--ranked` are ignored (provenance
  always walks the full chain).
- `--id` is still required (the entry to query provenance for).

### Output Format

The output is structured text designed for human readability:

```
PROVENANCE: MEM030 (chain length: 3)
  [0] MEM010 | 0.70 | 2026-01-01 | Original convention (origin)
  [1] MEM020 | 0.85 | 2026-02-01 | Updated convention (superseded)
  [2] MEM030 | 0.95 | 2026-03-15 | Current convention (current)
```

- Header line: `PROVENANCE: <queried_id> (chain length: <N>)`
- Chain entries: `  [<index>] <id> | <confidence> | <created_at> | <description> (<label>)`
- Labels:
  - `(origin)` — first entry in chain (has no supersedes)
  - `(superseded)` — middle entries (has both supersedes and superseded_by)
  - `(current)` — last entry in chain (has no superseded_by)
- If the chain has only one entry (no supersession), the label is `(sole entry)`.
- Index is 0-based from the origin.

### Error Handling

- If `--id` is missing, existing error handling applies (exit 1 with usage).
- If knowledge.db does not exist, existing warning applies (exit 0).
- If the entry does not exist in the database, print
  `PROVENANCE: <id> — entry not found` to stderr and exit 0.
- If the entry exists but has no supersession chain (supersedes and
  superseded_by are both empty), output a single-entry chain with
  `(sole entry)` label.

## Steps

### Step 1 -- Add --provenance flag parsing

In the argument parsing section of `scripts/knowledge/traverse-graph.sh`,
add a `provenance` variable and case handler:

Add to defaults section:
```bash
provenance=false
```

Add to case statement:
```bash
    --provenance)
      provenance=true
      shift
      ;;
```

### Step 2 -- Add provenance query function

After the argument parsing and before the existing relates_to CTE query,
add a function and early-return block for provenance mode:

```bash
# --- Provenance mode: supersession chain query ---
if [ "$provenance" = true ]; then
  # Check if entry exists
  exists="$(db_query "$db_path" "SELECT COUNT(*) FROM entries WHERE id = '${safe_id}';")" || true
  if [ "$exists" = "0" ] || [ -z "$exists" ]; then
    echo "PROVENANCE: ${entry_id} — entry not found" >&2
    exit 0
  fi

  # Walk backward (predecessors) and forward (successors) via supersedes/superseded_by
  prov_sql="
WITH RECURSIVE
backward(id, depth) AS (
  SELECT id, 0 FROM entries WHERE id = '${safe_id}'
  UNION ALL
  SELECT e.supersedes, b.depth - 1
  FROM entries e JOIN backward b ON e.id = b.id
  WHERE e.supersedes != ''
),
forward(id, depth) AS (
  SELECT superseded_by, 1 FROM entries
  WHERE id = '${safe_id}' AND superseded_by != ''
  UNION ALL
  SELECT e.superseded_by, f.depth + 1
  FROM entries e JOIN forward f ON e.id = f.id
  WHERE e.superseded_by != ''
)
SELECT e.id, e.confidence, e.created_at, e.description, c.depth,
       e.supersedes, e.superseded_by
FROM (
  SELECT id, depth FROM backward
  UNION ALL
  SELECT id, depth FROM forward
) c
JOIN entries e ON e.id = c.id
ORDER BY c.depth ASC;
"

  prov_results="$(db_query "$db_path" "$prov_sql")" || true

  if [ -z "$prov_results" ]; then
    echo "PROVENANCE: ${entry_id} — entry not found" >&2
    exit 0
  fi

  # Count chain length
  chain_length="$(printf '%s\n' "$prov_results" | wc -l | tr -d ' ')"
  echo "PROVENANCE: ${entry_id} (chain length: ${chain_length})"

  # Normalize depth values to 0-based index
  # The origin has the most negative depth — we renumber from 0
  idx=0
  printf '%s\n' "$prov_results" | while IFS='|' read -r eid conf created desc depth sups supby; do
    # Trim whitespace
    eid="$(printf '%s' "$eid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    conf="$(printf '%s' "$conf" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    created="$(printf '%s' "$created" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    desc="$(printf '%s' "$desc" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    sups="$(printf '%s' "$sups" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    supby="$(printf '%s' "$supby" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    # Determine label
    if [ "$chain_length" -eq 1 ]; then
      label="sole entry"
    elif [ -z "$sups" ] && [ -n "$supby" ]; then
      label="origin"
    elif [ -n "$sups" ] && [ -z "$supby" ]; then
      label="current"
    else
      label="superseded"
    fi

    echo "  [${idx}] ${eid} | ${conf} | ${created} | ${desc} (${label})"
    idx=$((idx + 1))
  done

  exit 0
fi
```

**Note on Bash 3.2 compatibility**: The `while` loop runs in a subshell
due to the pipe, so the `idx` counter will not persist across iterations.
The implementation must use a counter approach that works in a subshell.
Two options:

Option A: Use a temp file or `nl` to number lines externally:
```bash
printf '%s\n' "$prov_results" | nl -ba -v0 -nln | while IFS=$'\t' read -r idx line; do
```

Option B: Use process substitution (not available in Bash 3.2 in all cases).

Option C: Avoid pipe — read from a here-string or redirect:
```bash
idx=0
while IFS='|' read -r eid conf created desc depth sups supby; do
  ...
  idx=$((idx + 1))
done <<EOF
$prov_results
EOF
```

Option C (heredoc redirect) is Bash 3.2 compatible and avoids the subshell.
Use this approach.

### Step 3 -- Update usage comment

Update the header comment of traverse-graph.sh to document the
`--provenance` flag:

```bash
# Usage: traverse-graph.sh --id MEM042 [--max-depth 1] [--hops 1] [--max-entries 5] [--ranked] [--provenance]
```

### Step 4 -- Create verification scripts

Create three static verification scripts under `scripts/verify/`.

**m007-p03-provenance-flag.sh** -- verifies traverse-graph.sh supports
the --provenance flag:

```bash
#!/usr/bin/env bash
# Verifies traverse-graph.sh supports --provenance flag.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-provenance' "$f" || { echo "FAIL: $f does not support --provenance flag"; exit 1; }
grep -q 'provenance=true' "$f" || { echo "FAIL: $f missing provenance mode variable"; exit 1; }
echo "PASS: traverse-graph.sh supports --provenance flag"
```

**m007-p03-provenance-cte.sh** -- verifies the provenance query uses a
recursive CTE on supersedes columns:

```bash
#!/usr/bin/env bash
# Verifies --provenance mode uses a recursive CTE on supersedes/superseded_by.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'WITH RECURSIVE' "$f" || { echo "FAIL: $f does not contain recursive CTE"; exit 1; }
grep -q 'supersedes' "$f" || { echo "FAIL: $f does not reference supersedes column"; exit 1; }
grep -q 'superseded_by' "$f" || { echo "FAIL: $f does not reference superseded_by column"; exit 1; }
grep -q 'backward' "$f" || { echo "FAIL: $f missing backward CTE for predecessor walk"; exit 1; }
grep -q 'forward' "$f" || { echo "FAIL: $f missing forward CTE for successor walk"; exit 1; }
echo "PASS: --provenance mode uses recursive CTE on supersedes/superseded_by"
```

**m007-p03-provenance-output-format.sh** -- verifies provenance output
format strings exist:

```bash
#!/usr/bin/env bash
# Verifies --provenance output format matches specification.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'PROVENANCE:' "$f" || { echo "FAIL: $f missing PROVENANCE: header output"; exit 1; }
grep -q 'chain length' "$f" || { echo "FAIL: $f missing chain length in header"; exit 1; }
grep -q 'origin' "$f" || { echo "FAIL: $f missing origin label"; exit 1; }
grep -q 'current' "$f" || { echo "FAIL: $f missing current label"; exit 1; }
grep -q 'superseded' "$f" || { echo "FAIL: $f missing superseded label"; exit 1; }
grep -q 'sole entry' "$f" || { echo "FAIL: $f missing sole entry label"; exit 1; }
echo "PASS: --provenance output format matches specification"
```

Make all executable:

```bash
chmod +x scripts/verify/m007-p03-provenance-flag.sh
chmod +x scripts/verify/m007-p03-provenance-cte.sh
chmod +x scripts/verify/m007-p03-provenance-output-format.sh
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "supports --provenance flag", "uses a recursive CTE on
  supersedes/superseded_by columns", "output shows the full chain with
  entry metadata at each node".
- **Artifacts**: modified `scripts/knowledge/traverse-graph.sh`, three
  `scripts/verify/m007-p03-provenance-*.sh` scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m007-p03-provenance-flag.sh
bash scripts/verify/m007-p03-provenance-cte.sh
bash scripts/verify/m007-p03-provenance-output-format.sh
```

All three should print PASS.

### Files Touched By This Task

- `scripts/knowledge/traverse-graph.sh` (modify -- add --provenance flag,
  provenance CTE query, structured output formatting)
- `scripts/verify/m007-p03-provenance-flag.sh` (create)
- `scripts/verify/m007-p03-provenance-cte.sh` (create)
- `scripts/verify/m007-p03-provenance-output-format.sh` (create)

## Inputs

### From Previous Tasks

None -- T01 is the entry point for P03.

### From Disk (Pre-existing)

- `scripts/knowledge/traverse-graph.sh` (from P02) -- the rewritten script
  that uses recursive CTE queries for relates_to traversal. Sources
  `graph-db.sh` for `get_db_path()` and `db_query()`. Argument parsing
  already handles `--id`, `--max-depth`/`--hops`, `--max-entries`,
  `--ranked`. The `--provenance` flag is a new addition.

- `scripts/knowledge/lib/graph-db.sh` (from P01) -- provides `get_db_path()`,
  `db_query()`, `db_init()`, `db_insert_entry()`, `db_insert_edge()`.
  The provenance query uses only `db_query()` to execute the CTE.

- `knowledge.db` (from P01) -- SQLite database with `entries` table
  containing `supersedes` TEXT and `superseded_by` TEXT columns. These
  columns hold entry IDs (e.g., "MEM010") when a supersession relationship
  exists, or empty string when none exists.

## Expected Output

After completing this task:

1. `scripts/knowledge/traverse-graph.sh` exists and is executable.
2. The script supports `--provenance` flag in its argument parser.
3. When `--provenance` is used, a recursive CTE queries `supersedes`
   and `superseded_by` columns (not the `edges` table).
4. Output begins with `PROVENANCE: <id> (chain length: <N>)`.
5. Each chain entry is formatted as `  [<idx>] <id> | <conf> | <date> | <desc> (<label>)`.
6. Labels are: `origin` (first), `superseded` (middle), `current` (last),
   or `sole entry` (chain of 1).
7. If the entry does not exist, a message is printed to stderr and exit 0.
8. Three verification scripts exist, are executable, and print PASS.
9. `git status` shows 1 modified file + 3 new files.
