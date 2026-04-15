---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M007"
name: "Integration testing with fixture knowledge.db"
depends_on: ["T01"]
---

## Description

Validate check-graph-health.sh end-to-end by creating a temporary fixture
directory with a knowledge.db that exercises all five diagnostic checks. The
fixture data is designed to produce specific results: known statistics, at
least one orphan, multiple connected components, one broken supersession chain,
and one dangling edge. The runtime verification script validates that
check-graph-health.sh correctly detects each condition and that run-doctor.sh
integration works.

### Fixture Data Design

The test database contains:

**Connected component 1 (main cluster, 4 entries):**
- MEM001: confidence 0.90, relates_to MEM002
- MEM002: confidence 0.85, relates_to MEM001, relates_to MEM003
- MEM003: confidence 0.80, supersedes MEM004
- MEM004: confidence 0.70, superseded_by MEM003

**Connected component 2 (pair, 2 entries):**
- MEM005: confidence 0.75, relates_to MEM006
- MEM006: confidence 0.65, relates_to MEM005

**Orphaned entry (no edges, 1 entry):**
- MEM007: confidence 0.60, no edges at all

**Broken supersession chain trigger:**
- MEM003 has supersedes = "MEM004" (valid)
- MEM008: confidence 0.50, supersedes = "MEM999" (MEM999 does not exist -- broken chain)

**Dangling edge trigger:**
- Edge from "MEM099" to MEM001 with type "relates_to" (MEM099 does not exist)

**Summary of expected results:**
- Entries: 8 (MEM001-MEM008)
- Edges: 6 (MEM001-MEM002, MEM002-MEM003, MEM003-MEM004 supersedes, MEM005-MEM006, MEM008 supersedes MEM999 edge if inserted, MEM099-MEM001 dangling)
- Scope tags: at least 2
- Orphaned entries: 1 (MEM007)
- Connected components: 3+ (main cluster, pair, orphan MEM007, MEM008 island)
- Broken supersession chains: 1 (MEM008 supersedes MEM999)
- Dangling edges: 1 (MEM099 -> MEM001)
- Overall status: drift (integrity issues)

## Steps

### Step 1 -- Run the six static verification scripts from T01

Execute each verification script and confirm it prints PASS:

```bash
bash scripts/verify/m007-p04-check-graph-health-exists.sh
bash scripts/verify/m007-p04-graph-statistics.sh
bash scripts/verify/m007-p04-orphan-detection.sh
bash scripts/verify/m007-p04-integrity-checks.sh
bash scripts/verify/m007-p04-doctor-protocol.sh
bash scripts/verify/m007-p04-doctor-integration.sh
```

All six must print PASS. If any fail, the implementation from T01 has an issue
that must be fixed before proceeding.

### Step 2 -- Create the runtime verification script

Create `scripts/verify/m007-p04-e2e.sh` which sets up fixture data, runs
check-graph-health.sh, and validates output.

The script must:

1. Create a temp directory with `mktemp -d`.
2. Set `trap 'rm -rf "$fixture_dir"' EXIT` for cleanup.
3. Create `$fixture_dir/extension.yml` (required by get_project_root).
4. Source graph-db.sh to use `db_init`, `db_insert_entry`, `db_insert_edge`,
   `db_insert_scope_tag`.
5. Set `PROJECT_ROOT="$fixture_dir"` and create knowledge.db with fixture data.
6. Run `check-graph-health.sh --root "$fixture_dir"`.
7. Validate output:
   - Statistics line contains expected entry and edge counts.
   - Orphaned entries line mentions MEM007.
   - Broken supersession chains count is >= 1.
   - Dangling edges count is >= 1.
   - DOCTOR:GRAPH_HEALTH line has status=drift.
   - Overall line says ISSUES (not HEALTHY).
8. Test skip behavior: delete knowledge.db, re-run, verify status=skip.
9. Report pass/fail.

```bash
#!/usr/bin/env bash
# Verifies check-graph-health.sh end-to-end with fixture data.
# Creates temp knowledge.db, runs diagnostics, validates all five checks.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT_REAL="$(cd "$SCRIPT_DIR/../.." && pwd)"

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

touch "$fixture_dir/extension.yml"
mkdir -p "$fixture_dir/.specify/orchestrator"

# Source graph-db.sh for fixture setup
source "$PROJECT_ROOT_REAL/scripts/knowledge/lib/graph-db.sh"
export PROJECT_ROOT="$fixture_dir"

db_file="$fixture_dir/knowledge.db"
db_init "$db_file"

# --- Insert fixture entries ---
# Component 1: MEM001-MEM004 (connected cluster)
db_insert_entry "$db_file" "MEM001" "patterns" "0.90" "2026-01-01" "2026-01-01" "5" "" "" "" "" "" "First pattern" ""
db_insert_entry "$db_file" "MEM002" "patterns" "0.85" "2026-01-02" "2026-01-02" "3" "" "" "" "" "" "Second pattern" ""
db_insert_entry "$db_file" "MEM003" "patterns" "0.80" "2026-01-03" "2026-01-03" "2" "" "" "MEM004" "" "" "Third pattern (supersedes MEM004)" ""
db_insert_entry "$db_file" "MEM004" "patterns" "0.70" "2026-01-04" "2026-01-04" "1" "" "" "" "MEM003" "" "Fourth pattern (superseded)" ""

# Component 2: MEM005-MEM006 (isolated pair)
db_insert_entry "$db_file" "MEM005" "conventions" "0.75" "2026-02-01" "2026-02-01" "4" "" "" "" "" "" "Fifth convention" ""
db_insert_entry "$db_file" "MEM006" "conventions" "0.65" "2026-02-02" "2026-02-02" "2" "" "" "" "" "" "Sixth convention" ""

# Orphan: MEM007 (no edges)
db_insert_entry "$db_file" "MEM007" "decisions" "0.60" "2026-03-01" "2026-03-01" "0" "" "" "" "" "" "Orphaned decision" ""

# Broken chain trigger: MEM008 supersedes MEM999 (does not exist)
db_insert_entry "$db_file" "MEM008" "patterns" "0.50" "2026-03-02" "2026-03-02" "0" "" "" "MEM999" "" "" "Broken chain entry" ""

# --- Insert fixture edges ---
db_insert_edge "$db_file" "MEM001" "MEM002" "relates_to"
db_insert_edge "$db_file" "MEM002" "MEM003" "relates_to"
db_insert_edge "$db_file" "MEM003" "MEM004" "supersedes"
db_insert_edge "$db_file" "MEM005" "MEM006" "relates_to"

# Dangling edge: MEM099 does not exist as an entry
db_insert_edge "$db_file" "MEM099" "MEM001" "relates_to"

# --- Insert fixture scope tags ---
db_insert_scope_tag "$db_file" "MEM001" "project"
db_insert_scope_tag "$db_file" "MEM005" "milestone:M007"

# --- Run check-graph-health.sh ---
fail_count=0
fail() { echo "FAIL: $1"; fail_count=$((fail_count + 1)); }

output="$(bash "$PROJECT_ROOT_REAL/scripts/diagnostics/check-graph-health.sh" --root "$fixture_dir" 2>&1)" || true

# Test 1: Statistics line
echo "$output" | grep -q 'Statistics' || fail "T1: missing Statistics line"
echo "$output" | grep -q '8 entries' || fail "T1: expected 8 entries in statistics"

# Test 2: Orphaned entries
echo "$output" | grep -qi 'orphan' || fail "T2: missing orphan line"
echo "$output" | grep -q 'MEM007' || fail "T2: MEM007 should be flagged as orphan"

# Test 3: Connected components (expect multiple)
echo "$output" | grep -qi 'component' || fail "T3: missing component line"

# Test 4: Broken supersession chains
echo "$output" | grep -qi 'supersession\|broken' || fail "T4: missing broken chain line"

# Test 5: Dangling edges
echo "$output" | grep -qi 'dangling' || fail "T5: missing dangling edge line"
echo "$output" | grep -q 'MEM099' || fail "T5: MEM099 should be flagged as dangling"

# Test 6: DOCTOR:GRAPH_HEALTH line
echo "$output" | grep -q 'DOCTOR:GRAPH_HEALTH' || fail "T6: missing DOCTOR:GRAPH_HEALTH line"
echo "$output" | grep -q 'status=drift' || fail "T6: expected status=drift for integrity issues"

# Test 7: Overall status
echo "$output" | grep -q 'ISSUES' || fail "T7: expected ISSUES in overall status"

# Test 8: Skip behavior when DB missing
rm -f "$fixture_dir/knowledge.db"
skip_output="$(bash "$PROJECT_ROOT_REAL/scripts/diagnostics/check-graph-health.sh" --root "$fixture_dir" 2>&1)" || true
echo "$skip_output" | grep -q 'status=skip' || fail "T8: expected status=skip when knowledge.db missing"

if [ "$fail_count" -gt 0 ]; then
  echo "FAIL: $fail_count integration tests failed"
  exit 1
fi

echo "PASS: check-graph-health.sh correctly reports all graph health metrics"
```

Make executable:

```bash
chmod +x scripts/verify/m007-p04-e2e.sh
```

### Step 3 -- Run the runtime verification script

```bash
bash scripts/verify/m007-p04-e2e.sh
```

Must print PASS. If any test fails, diagnose and fix check-graph-health.sh.

### Step 4 -- Run all seven phase verification scripts

```bash
bash scripts/verify/m007-p04-check-graph-health-exists.sh
bash scripts/verify/m007-p04-graph-statistics.sh
bash scripts/verify/m007-p04-orphan-detection.sh
bash scripts/verify/m007-p04-integrity-checks.sh
bash scripts/verify/m007-p04-doctor-protocol.sh
bash scripts/verify/m007-p04-doctor-integration.sh
bash scripts/verify/m007-p04-e2e.sh
```

All seven must print PASS.

## Must-Haves

From phase plan, this task validates the truths end-to-end:

- **Truths**: All six truths from the phase plan validated against real fixture data.
- **Artifacts**: `scripts/verify/m007-p04-e2e.sh` runtime verification script.

## Verification

Run the runtime verification script:

```bash
bash scripts/verify/m007-p04-e2e.sh
```

Must print PASS. Also run all seven phase verification scripts to confirm
the complete phase.

### Files Touched By This Task

- `scripts/verify/m007-p04-e2e.sh` (create)

Possible modifications (only if needed):
- `scripts/diagnostics/check-graph-health.sh` (fix issues discovered during
  integration testing)
- `scripts/diagnostics/run-doctor.sh` (fix integration issues)

## Inputs

### From Previous Tasks

- `scripts/diagnostics/check-graph-health.sh` (from T01) -- the diagnostic
  script being tested. CLI: `--root <path>`. Output: human-readable block +
  DOCTOR:GRAPH_HEALTH machine-readable line.

- `scripts/diagnostics/run-doctor.sh` (modified in T01) -- includes graph
  health check in the diagnostic suite.

- `scripts/verify/m007-p04-*.sh` (from T01) -- six static verification scripts.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/graph-db.sh` (from P01) -- provides `db_init()`,
  `db_insert_entry()`, `db_insert_edge()`, `db_insert_scope_tag()` for
  creating fixture databases.

- `scripts/knowledge/lib/index-utils.sh` -- provides `get_project_root()`.
  Uses `$PROJECT_ROOT` env var when set.

- `sqlite3` CLI -- available at `/usr/bin/sqlite3` on macOS.

## Expected Output

After completing this task:

1. `scripts/verify/m007-p04-e2e.sh` exists and is executable.
2. The script creates a temp fixture with 8 entries, edges, and scope_tags.
3. Tests verify: statistics, orphan detection, component counting, broken
   chain detection, dangling edge detection, DOCTOR protocol, overall status.
4. Tests verify skip behavior when knowledge.db is missing.
5. All seven `scripts/verify/m007-p04-*.sh` scripts print PASS.
6. Cleanup removes all temporary fixtures.
7. `git status` shows 1 new file (the runtime verification script).
