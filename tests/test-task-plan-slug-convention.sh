#!/usr/bin/env bash
# tests/test-task-plan-slug-convention.sh — Bug H regression tests
#
# Bug H: planner agents organically emit task plans as T##-<slug>-PLAN.md
# (readable, sibling-symmetric with PAYLOAD/SUMMARY) rather than the bare
# T##-PLAN.md form from the old docs. This test pins:
#   - check-plan-exists.sh's T*-PLAN.md glob counts both forms
#   - github-init.sh's task_id extraction canonicalizes to T## regardless
#     of slug, so orchestrator IDs stay stable
#
# Historical no-slug files are not renamed; both forms remain legal.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE="$PROJECT_ROOT/tests/fixtures/check-plan-exists-rename"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- Test 1: check-plan-exists.sh counts slug + no-slug mix ---
# Fixture has T01-nextjs-scaffold-PLAN.md, T02-supabase-schema-PLAN.md,
# and T03-PLAN.md (mixed).
result=$(bash "$PROJECT_ROOT/scripts/util/check-plan-exists.sh" "$FIXTURE" P00)
if [[ "$result" = "PLAN_EXISTS task_plans=3" ]]; then
  pass "check-plan-exists counts slug + no-slug mix (got '$result')"
else
  fail "check-plan-exists counts slug + no-slug mix (expected 'PLAN_EXISTS task_plans=3', got '$result')"
fi

# --- Test 2: github-init.sh task_id canonicalization (unit-level) ---
# Replicate the extraction logic from scripts/integrations/github-init.sh
# so this test doesn't have to stand up a full gh-stub harness.
extract_task_id() {
  local tbase="$1"
  local task_id="${tbase%%-PLAN.md}"
  task_id="${task_id%%-*}"
  case "$task_id" in
    T[0-9][0-9]) echo "$task_id" ;;
    *) echo "REJECT" ;;
  esac
}

id1=$(extract_task_id "T01-PLAN.md")
if [[ "$id1" = "T01" ]]; then
  pass "extract_task_id('T01-PLAN.md') = T01"
else
  fail "extract_task_id('T01-PLAN.md') = T01 (got '$id1')"
fi

id2=$(extract_task_id "T01-nextjs-scaffold-PLAN.md")
if [[ "$id2" = "T01" ]]; then
  pass "extract_task_id('T01-nextjs-scaffold-PLAN.md') = T01 (slug stripped)"
else
  fail "extract_task_id('T01-nextjs-scaffold-PLAN.md') = T01 (got '$id2')"
fi

id3=$(extract_task_id "T42-brand-tokens-lint-PLAN.md")
if [[ "$id3" = "T42" ]]; then
  pass "extract_task_id('T42-brand-tokens-lint-PLAN.md') = T42"
else
  fail "extract_task_id('T42-brand-tokens-lint-PLAN.md') = T42 (got '$id3')"
fi

id_bad=$(extract_task_id "TX-foo-PLAN.md")
if [[ "$id_bad" = "REJECT" ]]; then
  pass "extract_task_id rejects non-numeric T-ID"
else
  fail "extract_task_id rejects non-numeric T-ID (got '$id_bad')"
fi

# --- Test 3: planner docs canonicalized to slug form ---
if grep -q "T##-<slug>-PLAN.md" "$PROJECT_ROOT/commands/plan-phase.md"; then
  pass "commands/plan-phase.md documents slug-form task plan filename"
else
  fail "commands/plan-phase.md documents slug-form task plan filename"
fi

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
