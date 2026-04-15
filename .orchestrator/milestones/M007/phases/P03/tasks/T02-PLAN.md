---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M007"
name: "Integration testing with fixture supersession chain"
depends_on: ["T01"]
---

## Description

Validate the --provenance mode end-to-end by creating a temporary fixture
directory with a 3-entry supersession chain in knowledge.db, then testing
`traverse-graph.sh --provenance` from each position in the chain. This task
also creates a runtime verification script that exercises the full provenance
pipeline against fixture data.

### Fixture Data Design

The test uses a 3-entry supersession chain:

```
MEM010 (original)
  supersedes: ""
  superseded_by: "MEM020"

MEM020 (revision)
  supersedes: "MEM010"
  superseded_by: "MEM030"

MEM030 (current)
  supersedes: "MEM020"
  superseded_by: ""
```

Plus one isolated entry (MEM040) with no supersession chain to test the
`(sole entry)` case.

Entry details:
- MEM010: confidence 0.70, created 2026-01-01, description "Original naming convention"
- MEM020: confidence 0.85, created 2026-02-01, description "Updated naming convention"
- MEM030: confidence 0.95, created 2026-03-15, description "Current naming convention"
- MEM040: confidence 0.80, created 2026-02-15, description "Standalone pattern"

## Steps

### Step 1 -- Run the three static verification scripts from T01

Execute each verification script and confirm it prints PASS:

```bash
bash scripts/verify/m007-p03-provenance-flag.sh
bash scripts/verify/m007-p03-provenance-cte.sh
bash scripts/verify/m007-p03-provenance-output-format.sh
```

All three must print PASS. If any fail, the --provenance implementation
from T01 has an issue that must be fixed before proceeding.

### Step 2 -- Create the runtime verification script

Create `scripts/verify/m007-p03-provenance-chain-traversal.sh` which sets
up fixture data, runs --provenance tests, and cleans up:

```bash
#!/usr/bin/env bash
# Verifies --provenance correctly traverses a 3-entry supersession chain.
# Creates a temporary knowledge.db with fixture data, runs provenance queries,
# and validates output. Cleans up on exit.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Create fixture directory
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

mkdir -p "$fixture_dir/knowledge/patterns"
touch "$fixture_dir/extension.yml"

# Source graph-db.sh for fixture setup
source "$PROJECT_ROOT/scripts/knowledge/lib/graph-db.sh"
export PROJECT_ROOT="$fixture_dir"

db_file="$fixture_dir/knowledge.db"
db_init "$db_file"

# Insert 3-entry supersession chain + 1 isolated entry
db_insert_entry "$db_file" "MEM010" "conventions" "0.70" "2026-01-01" "2026-01-01" "5" "" "" "" "MEM020" "" "Original naming convention" ""
db_insert_entry "$db_file" "MEM020" "conventions" "0.85" "2026-02-01" "2026-02-01" "3" "" "" "MEM010" "MEM030" "" "Updated naming convention" ""
db_insert_entry "$db_file" "MEM030" "conventions" "0.95" "2026-03-15" "2026-03-15" "1" "" "" "MEM020" "" "" "Current naming convention" ""
db_insert_entry "$db_file" "MEM040" "patterns" "0.80" "2026-02-15" "2026-02-15" "2" "" "" "" "" "" "Standalone pattern" ""

# Insert supersedes edges
db_insert_edge "$db_file" "MEM020" "MEM010" "supersedes"
db_insert_edge "$db_file" "MEM030" "MEM020" "supersedes"

fail_count=0
fail() { echo "FAIL: $1"; fail_count=$((fail_count + 1)); }

# --- Test 1: Provenance from chain tip (MEM030) ---
result="$(bash "$PROJECT_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM030 --provenance 2>/dev/null)" || true
echo "$result" | grep -q 'PROVENANCE: MEM030' || fail "T1: missing PROVENANCE header for MEM030"
echo "$result" | grep -q 'chain length: 3' || fail "T1: chain length should be 3"
echo "$result" | grep -q 'MEM010.*origin' || fail "T1: MEM010 should be labeled origin"
echo "$result" | grep -q 'MEM020.*superseded' || fail "T1: MEM020 should be labeled superseded"
echo "$result" | grep -q 'MEM030.*current' || fail "T1: MEM030 should be labeled current"

# --- Test 2: Provenance from chain middle (MEM020) ---
result="$(bash "$PROJECT_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM020 --provenance 2>/dev/null)" || true
echo "$result" | grep -q 'PROVENANCE: MEM020' || fail "T2: missing PROVENANCE header for MEM020"
echo "$result" | grep -q 'chain length: 3' || fail "T2: chain length should be 3 from middle"
echo "$result" | grep -q 'MEM010.*origin' || fail "T2: MEM010 should be labeled origin from middle"
echo "$result" | grep -q 'MEM030.*current' || fail "T2: MEM030 should be labeled current from middle"

# --- Test 3: Provenance from chain origin (MEM010) ---
result="$(bash "$PROJECT_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM010 --provenance 2>/dev/null)" || true
echo "$result" | grep -q 'PROVENANCE: MEM010' || fail "T3: missing PROVENANCE header for MEM010"
echo "$result" | grep -q 'chain length: 3' || fail "T3: chain length should be 3 from origin"

# --- Test 4: Provenance for isolated entry (MEM040) ---
result="$(bash "$PROJECT_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM040 --provenance 2>/dev/null)" || true
echo "$result" | grep -q 'PROVENANCE: MEM040' || fail "T4: missing PROVENANCE header for MEM040"
echo "$result" | grep -q 'chain length: 1' || fail "T4: chain length should be 1 for isolated entry"
echo "$result" | grep -q 'sole entry' || fail "T4: isolated entry should be labeled sole entry"

# --- Test 5: Provenance for nonexistent entry ---
result_err="$(bash "$PROJECT_ROOT/scripts/knowledge/traverse-graph.sh" --id NONEXIST --provenance 2>&1)" || true
echo "$result_err" | grep -q 'not found' || fail "T5: nonexistent entry should show not found"

# --- Test 6: Output format includes metadata ---
result="$(bash "$PROJECT_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM030 --provenance 2>/dev/null)" || true
echo "$result" | grep -q '0.70' || fail "T6: output should include MEM010 confidence 0.70"
echo "$result" | grep -q '2026-01-01' || fail "T6: output should include MEM010 created_at"
echo "$result" | grep -q 'Original naming convention' || fail "T6: output should include MEM010 description"

# --- Test 7: Chain ordering (origin first, current last) ---
result="$(bash "$PROJECT_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM030 --provenance 2>/dev/null)" || true
first_entry="$(echo "$result" | grep '^\[[:space:]]*\[0\]' || echo "$result" | head -2 | tail -1)"
last_entry="$(echo "$result" | tail -1)"
echo "$first_entry" | grep -q 'MEM010' || fail "T7: first chain entry should be MEM010 (origin)"
echo "$last_entry" | grep -q 'MEM030' || fail "T7: last chain entry should be MEM030 (current)"

if [ "$fail_count" -gt 0 ]; then
  echo "FAIL: $fail_count provenance tests failed"
  exit 1
fi

echo "PASS: --provenance correctly traverses supersession chains from all positions"
```

Make executable:

```bash
chmod +x scripts/verify/m007-p03-provenance-chain-traversal.sh
```

### Step 3 -- Run the runtime verification script

```bash
bash scripts/verify/m007-p03-provenance-chain-traversal.sh
```

Must print PASS. If any test fails, diagnose and fix the --provenance
implementation in traverse-graph.sh.

### Step 4 -- Run all four phase verification scripts

```bash
bash scripts/verify/m007-p03-provenance-flag.sh
bash scripts/verify/m007-p03-provenance-cte.sh
bash scripts/verify/m007-p03-provenance-output-format.sh
bash scripts/verify/m007-p03-provenance-chain-traversal.sh
```

All four must print PASS.

## Must-Haves

From phase plan, this task validates the truth:

- **Truths**: "--provenance correctly traverses a 3-entry supersession
  chain from any position".
- **Artifacts**: `scripts/verify/m007-p03-provenance-chain-traversal.sh`
  runtime verification script.

## Verification

Run the runtime verification script:

```bash
bash scripts/verify/m007-p03-provenance-chain-traversal.sh
```

Must print PASS. Also run all four phase verification scripts to confirm
the complete phase:

```bash
bash scripts/verify/m007-p03-provenance-flag.sh
bash scripts/verify/m007-p03-provenance-cte.sh
bash scripts/verify/m007-p03-provenance-output-format.sh
bash scripts/verify/m007-p03-provenance-chain-traversal.sh
```

### Files Touched By This Task

- `scripts/verify/m007-p03-provenance-chain-traversal.sh` (create)

Possible modifications (only if needed):
- `scripts/knowledge/traverse-graph.sh` (fix issues discovered during
  integration testing)
- `scripts/verify/m007-p03-provenance-*.sh` (fix grep patterns if they
  do not match actual code)

## Inputs

### From Previous Tasks

- `scripts/knowledge/traverse-graph.sh` (from T01) -- the modified script
  with `--provenance` flag. CLI: `--id <ID> --provenance`. Output format:
  `PROVENANCE: <id> (chain length: N)` header followed by indented chain
  entries with metadata and labels.

- `scripts/verify/m007-p03-provenance-flag.sh` (from T01) -- static check.
- `scripts/verify/m007-p03-provenance-cte.sh` (from T01) -- static check.
- `scripts/verify/m007-p03-provenance-output-format.sh` (from T01) -- static check.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/graph-db.sh` (from P01) -- provides `get_db_path()`,
  `db_query()`, `db_init()`, `db_insert_entry()`, `db_insert_edge()`. Used
  to set up the fixture database with the supersession chain.

- `scripts/knowledge/lib/index-utils.sh` -- provides `get_project_root()`.
  Uses `$PROJECT_ROOT` env var when set (used by fixtures to override root).

- `sqlite3` CLI -- available at `/usr/bin/sqlite3` on macOS.

## Expected Output

After completing this task:

1. `scripts/verify/m007-p03-provenance-chain-traversal.sh` exists and is
   executable.
2. The script creates a temporary fixture with 3-entry chain + 1 isolated entry.
3. Tests pass for provenance from chain tip, middle, and origin.
4. Tests pass for isolated entry (sole entry label).
5. Tests pass for nonexistent entry (not found message).
6. Tests verify output includes metadata (confidence, created_at, description).
7. Tests verify chain ordering (origin first, current last).
8. All four `scripts/verify/m007-p03-*.sh` scripts print PASS.
9. Cleanup removes all temporary fixtures.
10. `git status` shows 1 new file (the runtime verification script).
