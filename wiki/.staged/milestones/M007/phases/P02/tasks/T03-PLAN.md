---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M007"
name: "Integration testing + end-to-end verification"
depends_on: ["T01", "T02"]
---

## Description

Validate the full multi-hop context retrieval pipeline by running both
rewritten scripts against a temporary fixture database and verifying correct
behavior. This task does NOT create permanent test files — it uses a temporary
directory with fixture entries and a pre-populated knowledge.db, runs both
`traverse-graph.sh` and `scope-filter.sh --graph`, inspects the results, and
cleans up.

The integration tests cover:

1. **Multi-hop traversal**: traverse-graph.sh returns correct entries at
   depth 1, 2, and 3.
2. **Bidirectional edges**: querying from an entry that is only a target
   (not a source) in the edges table still finds related entries.
3. **Ranked output**: `--ranked` mode produces pipe-delimited output with
   correct confidence, depth, and ranked_score values.
4. **Path-distance ranking**: entries closer to the seed entry rank higher.
5. **scope-filter --graph**: filters correctly by scope, confidence, and
   category via SQL.
6. **Output format**: scope-filter --graph output matches pipe-delimited
   KNOWLEDGE-INDEX.md format.
7. **Verification scripts**: all seven phase verification scripts print PASS.

### Fixture Data Design

The test uses a chain of 5 entries to test multi-hop traversal:

```
MEM001 --relates_to--> MEM002 --relates_to--> MEM003 --relates_to--> MEM004
                                                        |
                                                relates_to
                                                        |
                                                      MEM005
```

- MEM001: confidence 0.90, scope [project], category patterns
- MEM002: confidence 0.80, scope [milestone:M001], category patterns
- MEM003: confidence 0.70, scope [phase:M001/P02], category conventions
- MEM004: confidence 0.60, scope [milestone:M001], category patterns
- MEM005: confidence 0.95, scope [project], category decisions

This allows testing:
- 1-hop from MEM001: returns MEM002
- 2-hop from MEM001: returns MEM002, MEM003
- 3-hop from MEM001: returns MEM002, MEM003, MEM004, MEM005
- Bidirectional: querying from MEM002 with 1-hop returns MEM001 AND MEM003
- Ranking: MEM002 (0.80/1=0.80) ranks above MEM003 (0.70/2=0.35) from MEM001
- Scope filtering: --graph M001/P02 returns MEM001 (project), MEM002 (milestone),
  MEM003 (phase), MEM005 (project) — MEM004 matches milestone but not phase

## Steps

### Step 1 -- Run all seven phase verification scripts

Execute each verification script and confirm it prints PASS:

```bash
bash scripts/verify/m007-p02-traverse-recursive-cte.sh
bash scripts/verify/m007-p02-traverse-bidirectional.sh
bash scripts/verify/m007-p02-traverse-hops-flag.sh
bash scripts/verify/m007-p02-traverse-ranked-output.sh
bash scripts/verify/m007-p02-scope-filter-graph-mode.sh
bash scripts/verify/m007-p02-scope-filter-graph-filters.sh
bash scripts/verify/m007-p02-scripts-source-graph-db.sh
```

All seven must print PASS. If any fail, the corresponding code from T01 or
T02 has an issue that must be fixed before proceeding.

### Step 2 -- Create fixture directory and populate database

Create a temporary directory with the required structure and a knowledge.db
populated with fixture data.

```bash
fixture_dir="$(mktemp -d)"
mkdir -p "$fixture_dir/knowledge/patterns"
touch "$fixture_dir/extension.yml"

# Source graph-db.sh to use its functions
source scripts/knowledge/lib/graph-db.sh
export PROJECT_ROOT="$fixture_dir"

db_file="$fixture_dir/knowledge.db"
db_init "$db_file"

# Insert 5 fixture entries
db_insert_entry "$db_file" "MEM001" "patterns" "0.90" "2026-01-01" "2026-01-01" "5" "M001" "execution" "" "" "sha256:aaa" "Project-level pattern" "knowledge/patterns/MEM001.md"
db_insert_entry "$db_file" "MEM002" "patterns" "0.80" "2026-01-02" "2026-01-02" "3" "M001" "discovery" "" "" "sha256:bbb" "Milestone-scoped pattern" "knowledge/patterns/MEM002.md"
db_insert_entry "$db_file" "MEM003" "conventions" "0.70" "2026-01-03" "2026-01-03" "1" "M001/P02" "ratification" "" "" "sha256:ccc" "Phase-scoped convention" "knowledge/conventions/MEM003.md"
db_insert_entry "$db_file" "MEM004" "patterns" "0.60" "2026-01-04" "2026-01-04" "0" "M001" "execution" "" "" "sha256:ddd" "Another milestone pattern" "knowledge/patterns/MEM004.md"
db_insert_entry "$db_file" "MEM005" "decisions" "0.95" "2026-01-05" "2026-01-05" "2" "M001/P03" "discovery" "" "" "sha256:eee" "Project-level decision" "knowledge/decisions/MEM005.md"

# Insert edges: MEM001-MEM002-MEM003-MEM004, MEM003-MEM005
db_insert_edge "$db_file" "MEM001" "MEM002" "relates_to"
db_insert_edge "$db_file" "MEM002" "MEM003" "relates_to"
db_insert_edge "$db_file" "MEM003" "MEM004" "relates_to"
db_insert_edge "$db_file" "MEM003" "MEM005" "relates_to"

# Insert scope tags
db_insert_scope_tag "$db_file" "MEM001" "[project]"
db_insert_scope_tag "$db_file" "MEM002" "[milestone:M001]"
db_insert_scope_tag "$db_file" "MEM003" "[phase:M001/P02]"
db_insert_scope_tag "$db_file" "MEM004" "[milestone:M001]"
db_insert_scope_tag "$db_file" "MEM005" "[project]"
```

### Step 3 -- Test traverse-graph.sh multi-hop traversal

```bash
# Test 1-hop from MEM001: should return MEM002 only
result="$(bash scripts/knowledge/traverse-graph.sh --id MEM001 --max-depth 1)"
echo "$result" | grep -q "MEM002" || { echo "FAIL: 1-hop missing MEM002"; exit 1; }
line_count="$(echo "$result" | wc -l | tr -d ' ')"
test "$line_count" -eq 1 || { echo "FAIL: 1-hop returned $line_count entries, expected 1"; exit 1; }
echo "PASS: 1-hop traversal"

# Test 2-hop from MEM001: should return MEM002, MEM003
result="$(bash scripts/knowledge/traverse-graph.sh --id MEM001 --hops 2)"
echo "$result" | grep -q "MEM002" || { echo "FAIL: 2-hop missing MEM002"; exit 1; }
echo "$result" | grep -q "MEM003" || { echo "FAIL: 2-hop missing MEM003"; exit 1; }
echo "PASS: 2-hop traversal"

# Test 3-hop from MEM001: should return MEM002, MEM003, MEM004, MEM005
result="$(bash scripts/knowledge/traverse-graph.sh --id MEM001 --hops 3 --max-entries 10)"
echo "$result" | grep -q "MEM002" || { echo "FAIL: 3-hop missing MEM002"; exit 1; }
echo "$result" | grep -q "MEM003" || { echo "FAIL: 3-hop missing MEM003"; exit 1; }
echo "$result" | grep -q "MEM004" || { echo "FAIL: 3-hop missing MEM004"; exit 1; }
echo "$result" | grep -q "MEM005" || { echo "FAIL: 3-hop missing MEM005"; exit 1; }
echo "PASS: 3-hop traversal"
```

### Step 4 -- Test bidirectional edge traversal

```bash
# Query from MEM002 with 1-hop: should find MEM001 AND MEM003
# MEM001 is reachable because MEM001->MEM002 edge exists and we query both directions
result="$(bash scripts/knowledge/traverse-graph.sh --id MEM002 --max-depth 1)"
echo "$result" | grep -q "MEM001" || { echo "FAIL: bidirectional missing MEM001 from MEM002"; exit 1; }
echo "$result" | grep -q "MEM003" || { echo "FAIL: bidirectional missing MEM003 from MEM002"; exit 1; }
echo "PASS: bidirectional edge traversal"
```

### Step 5 -- Test ranked output

```bash
# Ranked output from MEM001, 2-hop
result="$(bash scripts/knowledge/traverse-graph.sh --id MEM001 --hops 2 --ranked)"
echo "$result" | grep -q '|' || { echo "FAIL: ranked output missing pipe delimiters"; exit 1; }

# MEM002 should rank higher than MEM003 (closer + high confidence)
# MEM002: 0.80 * (1/1) = 0.80
# MEM003: 0.70 * (1/2) = 0.35
first_line="$(echo "$result" | head -1)"
echo "$first_line" | grep -q "MEM002" || { echo "FAIL: MEM002 should be ranked first, got: $first_line"; exit 1; }
echo "PASS: ranked output with correct ordering"
```

### Step 6 -- Test scope-filter.sh --graph mode

```bash
# Test basic --graph mode (no filters): should return all 5 entries
result="$(bash scripts/dispatch/scope-filter.sh --graph dummy M001/P02)"
line_count="$(echo "$result" | grep -c 'MEM' || true)"
test "$line_count" -ge 4 || { echo "FAIL: --graph mode returned $line_count entries, expected at least 4"; exit 1; }
echo "PASS: --graph mode returns entries"

# Test --graph with category filter
result="$(bash scripts/dispatch/scope-filter.sh --graph dummy M001/P02 --category patterns)"
echo "$result" | grep -q "MEM001" || { echo "FAIL: --graph --category patterns missing MEM001"; exit 1; }
if echo "$result" | grep -q "MEM003"; then
  echo "FAIL: --graph --category patterns should not include MEM003 (conventions)"; exit 1
fi
echo "PASS: --graph mode category filter"

# Test --graph with confidence filter
result="$(bash scripts/dispatch/scope-filter.sh --graph dummy M001/P02 --min-confidence 0.75)"
echo "$result" | grep -q "MEM001" || { echo "FAIL: --graph --min-confidence 0.75 missing MEM001 (0.90)"; exit 1; }
echo "$result" | grep -q "MEM002" || { echo "FAIL: --graph --min-confidence 0.75 missing MEM002 (0.80)"; exit 1; }
if echo "$result" | grep -q "MEM003"; then
  echo "FAIL: --graph --min-confidence 0.75 should not include MEM003 (0.70)"; exit 1
fi
echo "PASS: --graph mode confidence filter"

# Test output format matches pipe-delimited KNOWLEDGE-INDEX.md format
result="$(bash scripts/dispatch/scope-filter.sh --graph dummy M001/P02)"
echo "$result" | head -1 | grep -qE '^MEM[0-9]+ \|' || { echo "FAIL: --graph output not in pipe-delimited format"; exit 1; }
echo "PASS: --graph mode output format"
```

### Step 7 -- Test existing flat-file modes are unchanged

```bash
# Verify non-graph mode still works (no regressions)
# Create a minimal KNOWLEDGE-INDEX.md in the fixture dir
cat > "$fixture_dir/KNOWLEDGE-INDEX.md" <<'EOF_INDEX'
# KNOWLEDGE-INDEX.md
MEM001 | [project] | patterns | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:5 | Project-level pattern
MEM002 | [milestone:M001] | patterns | 0.80 | 2026-01-02 | verified:2026-01-02 | hits:3 | Milestone-scoped pattern
EOF_INDEX

result="$(bash scripts/dispatch/scope-filter.sh "$fixture_dir/KNOWLEDGE-INDEX.md" M001/P02 --type knowledge)"
echo "$result" | grep -q "MEM001" || { echo "FAIL: flat-file mode regression — MEM001 missing"; exit 1; }
echo "PASS: existing flat-file mode unchanged"
```

### Step 8 -- Clean up

```bash
rm -rf "$fixture_dir"
```

## Must-Haves

From phase plan, this task validates ALL seven truths via the verification
scripts and provides end-to-end integration testing with fixture data. It
confirms that both rewritten scripts produce correct results against a
populated knowledge.db.

## Verification

All seven verification scripts must print PASS:

```bash
bash scripts/verify/m007-p02-traverse-recursive-cte.sh
bash scripts/verify/m007-p02-traverse-bidirectional.sh
bash scripts/verify/m007-p02-traverse-hops-flag.sh
bash scripts/verify/m007-p02-traverse-ranked-output.sh
bash scripts/verify/m007-p02-scope-filter-graph-mode.sh
bash scripts/verify/m007-p02-scope-filter-graph-filters.sh
bash scripts/verify/m007-p02-scripts-source-graph-db.sh
```

The integration tests in Steps 3-7 confirm runtime behavior beyond what
static file checks can verify.

### Files Touched By This Task

No permanent files are created or modified by this task. The fixture directory
is temporary and cleaned up. If any verification scripts need updates to pass
against the actual code (e.g., a grep pattern that does not match), those
scripts are modified in place.

Possible modifications (only if needed):
- `scripts/verify/m007-p02-*.sh` (fix grep patterns if they do not match
  actual code)

## Inputs

### From Previous Tasks

- `scripts/knowledge/traverse-graph.sh` (from T01) -- the rewritten script
  that uses recursive CTE queries. CLI interface: `--id <ID> [--max-depth N]
  [--hops N] [--max-entries N] [--ranked]`.

- `scripts/dispatch/scope-filter.sh` (from T02) -- the modified script with
  `--graph` mode. CLI interface adds: `--graph` flag, which queries
  knowledge.db directly via SQLite.

- `scripts/verify/m007-p02-*.sh` (from T01 and T02) -- seven verification
  scripts to run.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/graph-db.sh` (from P01) -- provides `get_db_path()`,
  `db_query()`, `db_init()`, `db_insert_entry()`, `db_insert_edge()`,
  `db_insert_scope_tag()`. Used to set up the fixture database.

- `scripts/knowledge/lib/index-utils.sh` -- provides `get_project_root()`.
  Uses `$PROJECT_ROOT` env var when set (used by fixtures to override root).

- `sqlite3` CLI -- used to query the database in verification steps.

## Expected Output

After completing this task:

1. All seven `scripts/verify/m007-p02-*.sh` scripts print PASS.
2. The integration tests confirm:
   - 1-hop from MEM001 returns MEM002 only.
   - 2-hop from MEM001 returns MEM002 and MEM003.
   - 3-hop from MEM001 returns MEM002, MEM003, MEM004, and MEM005.
   - Bidirectional traversal from MEM002 returns MEM001 and MEM003.
   - Ranked output has MEM002 ranked above MEM003 (higher score).
   - scope-filter --graph with category filter excludes non-matching entries.
   - scope-filter --graph with confidence filter excludes low-confidence entries.
   - scope-filter --graph output matches pipe-delimited format.
   - Existing flat-file modes are not broken.
3. No temporary files remain after cleanup.
4. If any verification scripts were modified, `git status` shows those
   changes. Otherwise, no files are touched.
