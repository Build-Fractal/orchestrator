#!/usr/bin/env bash
# Verifies --provenance correctly traverses a 3-entry supersession chain.
# Creates a temporary knowledge.db with fixture data, runs provenance queries,
# and validates output. Cleans up on exit.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Create fixture directory
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

mkdir -p "$fixture_dir/knowledge/patterns"
mkdir -p "$fixture_dir/.orchestrator"

# Source graph-db.sh for fixture setup
source "$REPO_ROOT/scripts/knowledge/lib/graph-db.sh"
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
result="$(bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM030 --provenance 2>/dev/null)" || true
echo "$result" | grep -q 'PROVENANCE: MEM030' || fail "T1: missing PROVENANCE header for MEM030"
echo "$result" | grep -q 'chain length: 3' || fail "T1: chain length should be 3"
echo "$result" | grep -q 'MEM010.*origin' || fail "T1: MEM010 should be labeled origin"
echo "$result" | grep -q 'MEM020.*superseded' || fail "T1: MEM020 should be labeled superseded"
echo "$result" | grep -q 'MEM030.*current' || fail "T1: MEM030 should be labeled current"

# --- Test 2: Provenance from chain middle (MEM020) ---
result="$(bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM020 --provenance 2>/dev/null)" || true
echo "$result" | grep -q 'PROVENANCE: MEM020' || fail "T2: missing PROVENANCE header for MEM020"
echo "$result" | grep -q 'chain length: 3' || fail "T2: chain length should be 3 from middle"
echo "$result" | grep -q 'MEM010.*origin' || fail "T2: MEM010 should be labeled origin from middle"
echo "$result" | grep -q 'MEM030.*current' || fail "T2: MEM030 should be labeled current from middle"

# --- Test 3: Provenance from chain origin (MEM010) ---
result="$(bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM010 --provenance 2>/dev/null)" || true
echo "$result" | grep -q 'PROVENANCE: MEM010' || fail "T3: missing PROVENANCE header for MEM010"
echo "$result" | grep -q 'chain length: 3' || fail "T3: chain length should be 3 from origin"

# --- Test 4: Provenance for isolated entry (MEM040) ---
result="$(bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM040 --provenance 2>/dev/null)" || true
echo "$result" | grep -q 'PROVENANCE: MEM040' || fail "T4: missing PROVENANCE header for MEM040"
echo "$result" | grep -q 'chain length: 1' || fail "T4: chain length should be 1 for isolated entry"
echo "$result" | grep -q 'sole entry' || fail "T4: isolated entry should be labeled sole entry"

# --- Test 5: Provenance for nonexistent entry ---
result_err="$(bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id NONEXIST --provenance 2>&1)" || true
echo "$result_err" | grep -q 'not found' || fail "T5: nonexistent entry should show not found"

# --- Test 6: Output format includes metadata ---
result="$(bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM030 --provenance 2>/dev/null)" || true
echo "$result" | grep -q '0.70' || fail "T6: output should include MEM010 confidence 0.70"
echo "$result" | grep -q '2026-01-01' || fail "T6: output should include MEM010 created_at"
echo "$result" | grep -q 'Original naming convention' || fail "T6: output should include MEM010 description"

# --- Test 7: Chain ordering (origin first, current last) ---
result="$(bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM030 --provenance 2>/dev/null)" || true
first_data="$(echo "$result" | grep '^\s*\[0\]' || echo "$result" | sed -n '2p')"
last_data="$(echo "$result" | tail -1)"
echo "$first_data" | grep -q 'MEM010' || fail "T7: first chain entry should be MEM010 (origin)"
echo "$last_data" | grep -q 'MEM030' || fail "T7: last chain entry should be MEM030 (current)"

if [ "$fail_count" -gt 0 ]; then
  echo "FAIL: $fail_count provenance tests failed"
  exit 1
fi

echo "PASS: --provenance correctly traverses supersession chains from all positions"
