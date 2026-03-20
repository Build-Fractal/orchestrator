#!/usr/bin/env bash
# tests/test-s02-state-machine.sh — Validates all S02 state machine contracts
# Tests: 9 state derivations, config resolution (4 layers), roadmap parsing,
#         scaffold idempotency, and error paths.
# Outputs structured PASS/FAIL lines per check. Exits 0 if all pass, 1 if any fail.
# Dependencies: bash only (scripts under test use POSIX sh)

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

# Resolve project root (directory containing this test script's parent)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() {
  TOTAL=$((TOTAL + 1))
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS: $1"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: $1"
}

# --------------------------------------------------------------------------
# 1. State derivation tests (9 states)
# --------------------------------------------------------------------------
# Each fixture directory simulates a milestone directory tree at a specific state.
# derive-phase.sh reads the directory and outputs the current state.

DERIVE_SCRIPT="$PROJECT_ROOT/scripts/state/derive-phase.sh"
ROADMAP_SCRIPT="$PROJECT_ROOT/scripts/state/read-roadmap.sh"

# State names and their fixture directories (parallel arrays for bash 3 compat)
STATE_NAMES=(
  "pre-planning"
  "discussing"
  "planning"
  "replanning"
  "executing"
  "summarizing"
  "validating"
  "completing"
  "complete"
)

STATE_DIRS=(
  "$PROJECT_ROOT/tests/fixtures/state-pre-planning"
  "$PROJECT_ROOT/tests/fixtures/state-discussing"
  "$PROJECT_ROOT/tests/fixtures/state-planning"
  "$PROJECT_ROOT/tests/fixtures/state-replanning"
  "$PROJECT_ROOT/tests/fixtures/state-executing"
  "$PROJECT_ROOT/tests/fixtures/state-summarizing"
  "$PROJECT_ROOT/tests/fixtures/state-validating"
  "$PROJECT_ROOT/tests/fixtures/state-completing"
  "$PROJECT_ROOT/tests/fixtures/state-complete"
)

if [ ! -f "$DERIVE_SCRIPT" ]; then
  echo "SKIP: derive-phase.sh not yet implemented — skipping state derivation tests"
  for state in "${STATE_NAMES[@]}"; do
    fail "derive-phase.sh → $state (script not found)"
  done
else
  i=0
  for state in "${STATE_NAMES[@]}"; do
    fixture_dir="${STATE_DIRS[$i]}"
    i=$((i + 1))

    if [ ! -d "$fixture_dir" ]; then
      fail "derive-phase.sh → $state (fixture dir missing: $fixture_dir)"
      continue
    fi

    actual=$(bash "$DERIVE_SCRIPT" "$fixture_dir" 2>/dev/null) || true
    if [ "$actual" = "$state" ]; then
      pass "derive-phase.sh → $state"
    else
      fail "derive-phase.sh → $state (got: '$actual')"
    fi
  done
fi

# --------------------------------------------------------------------------
# 1b. Tier B state machine tests
# --------------------------------------------------------------------------

TIER_B_FIXTURE="$PROJECT_ROOT/tests/fixtures/state-tier-b"
TIER_B_ROADMAP="$TIER_B_FIXTURE/M001-ROADMAP.md"

# Tier B: read-roadmap.sh returns tier B
if [ -f "$ROADMAP_SCRIPT" ] && [ -f "$TIER_B_ROADMAP" ]; then
  tier_b_result=$(bash "$ROADMAP_SCRIPT" "$TIER_B_ROADMAP" tier 2>/dev/null) || true
  if [ "$tier_b_result" = "B" ]; then
    pass "read-roadmap.sh tier B fixture → B"
  else
    fail "read-roadmap.sh tier B fixture → B (got: '$tier_b_result')"
  fi
else
  fail "read-roadmap.sh tier B fixture → B (script or fixture missing)"
fi

# Tier B: derive-phase.sh returns executing (P02 has plan + incomplete task)
if [ -f "$DERIVE_SCRIPT" ] && [ -d "$TIER_B_FIXTURE" ]; then
  tier_b_state=$(bash "$DERIVE_SCRIPT" "$TIER_B_FIXTURE" 2>/dev/null) || true
  if [ "$tier_b_state" = "executing" ]; then
    pass "derive-phase.sh tier B fixture → executing"
  else
    fail "derive-phase.sh tier B fixture → executing (got: '$tier_b_state')"
  fi
else
  fail "derive-phase.sh tier B fixture → executing (script or fixture missing)"
fi

# Tier B: fixture has no discussing/validating/completing state files
tier_b_has_forbidden=false
for pattern in "M001-CONTEXT.md" "M001-VALIDATION.md" "M001-SUMMARY.md"; do
  if [ -f "$TIER_B_FIXTURE/$pattern" ]; then
    tier_b_has_forbidden=true
  fi
done
if [ "$tier_b_has_forbidden" = "false" ]; then
  pass "tier B fixture has no discussing/validating/completing state files"
else
  fail "tier B fixture has forbidden state files (discussing/validating/completing)"
fi

# --------------------------------------------------------------------------
# 1c. Tier A zero-artifacts tests (FR-001, FR-003)
# --------------------------------------------------------------------------

TIER_A_FIXTURE="$PROJECT_ROOT/tests/fixtures/state-tier-a"

# Tier A: derive-phase.sh on empty dir → pre-planning
if [ -f "$DERIVE_SCRIPT" ] && [ -d "$TIER_A_FIXTURE" ]; then
  tier_a_state=$(bash "$DERIVE_SCRIPT" "$TIER_A_FIXTURE" 2>/dev/null) || true
  if [ "$tier_a_state" = "pre-planning" ]; then
    pass "derive-phase.sh tier A fixture → pre-planning"
  else
    fail "derive-phase.sh tier A fixture → pre-planning (got: '$tier_a_state')"
  fi
else
  fail "derive-phase.sh tier A fixture → pre-planning (script or fixture missing)"
fi

# Tier A: no milestones/ directory exists in the fixture
if [ ! -d "$TIER_A_FIXTURE/milestones" ]; then
  pass "tier A fixture has no milestones/ directory"
else
  fail "tier A fixture has milestones/ directory (should have none)"
fi

# --------------------------------------------------------------------------
# 2. State derivation error path tests
# --------------------------------------------------------------------------

if [ ! -f "$DERIVE_SCRIPT" ]; then
  echo "SKIP: derive-phase.sh not yet implemented — skipping error path tests"
  fail "derive-phase.sh no-args → non-zero exit + stderr (script not found)"
  fail "derive-phase.sh nonexistent dir → pre-planning (script not found)"
else
  # No arguments → non-zero exit + stderr message
  stderr_output=$(bash "$DERIVE_SCRIPT" 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ -n "$stderr_output" ]; then
    pass "derive-phase.sh no-args → non-zero exit + stderr"
  else
    fail "derive-phase.sh no-args → non-zero exit + stderr (exit=$exit_code, stderr='$stderr_output')"
  fi

  # Nonexistent directory → pre-planning (not an error)
  actual=$(bash "$DERIVE_SCRIPT" "/tmp/nonexistent-milestone-dir-$$" 2>/dev/null) || true
  if [ "$actual" = "pre-planning" ]; then
    pass "derive-phase.sh nonexistent dir → pre-planning"
  else
    fail "derive-phase.sh nonexistent dir → pre-planning (got: '$actual')"
  fi
fi

# --------------------------------------------------------------------------
# 3. Config resolution tests (4 layers)
# --------------------------------------------------------------------------

CONFIG_SCRIPT="$PROJECT_ROOT/scripts/state/read-config.sh"
CONFIG_FIXTURES="$PROJECT_ROOT/tests/fixtures/config"

if [ ! -f "$CONFIG_SCRIPT" ]; then
  echo "SKIP: read-config.sh not yet implemented — skipping config tests"
  fail "read-config.sh default_tier → null (script not found)"
  fail "read-config.sh context_verbosity with project override → full (script not found)"
  fail "read-config.sh context_verbosity with local override → minimal (script not found)"
  fail "read-config.sh default_tier with env override → B (script not found)"
  fail "read-config.sh git_isolation with project override → true (script not found)"
  fail "read-config.sh unknown key → non-zero exit + stderr (script not found)"
else
  # Test 1: Extension default only (no overrides)
  actual=$(bash "$CONFIG_SCRIPT" "default_tier" \
    --defaults "$CONFIG_FIXTURES/extension-defaults.yml" \
    2>/dev/null) || true
  if [ "$actual" = "null" ]; then
    pass "read-config.sh default_tier → null (extension default)"
  else
    fail "read-config.sh default_tier → null (got: '$actual')"
  fi

  # Test 2: Project config overrides extension default
  actual=$(bash "$CONFIG_SCRIPT" "context_verbosity" \
    --defaults "$CONFIG_FIXTURES/extension-defaults.yml" \
    --project "$CONFIG_FIXTURES/project-config.yml" \
    2>/dev/null) || true
  if [ "$actual" = "full" ]; then
    pass "read-config.sh context_verbosity with project override → full"
  else
    fail "read-config.sh context_verbosity with project override → full (got: '$actual')"
  fi

  # Test 3: Local config overrides project config
  actual=$(bash "$CONFIG_SCRIPT" "context_verbosity" \
    --defaults "$CONFIG_FIXTURES/extension-defaults.yml" \
    --project "$CONFIG_FIXTURES/project-config.yml" \
    --local "$CONFIG_FIXTURES/local-config.yml" \
    2>/dev/null) || true
  if [ "$actual" = "minimal" ]; then
    pass "read-config.sh context_verbosity with local override → minimal"
  else
    fail "read-config.sh context_verbosity with local override → minimal (got: '$actual')"
  fi

  # Test 4: Env var overrides everything
  actual=$(SPECKIT_ORCHESTRATOR_DEFAULT_TIER=B bash "$CONFIG_SCRIPT" "default_tier" \
    --defaults "$CONFIG_FIXTURES/extension-defaults.yml" \
    --project "$CONFIG_FIXTURES/project-config.yml" \
    --local "$CONFIG_FIXTURES/local-config.yml" \
    2>/dev/null) || true
  if [ "$actual" = "B" ]; then
    pass "read-config.sh default_tier with env override → B"
  else
    fail "read-config.sh default_tier with env override → B (got: '$actual')"
  fi

  # Test 5: Project config overrides default for git_isolation
  actual=$(bash "$CONFIG_SCRIPT" "git_isolation" \
    --defaults "$CONFIG_FIXTURES/extension-defaults.yml" \
    --project "$CONFIG_FIXTURES/project-config.yml" \
    2>/dev/null) || true
  if [ "$actual" = "true" ]; then
    pass "read-config.sh git_isolation with project override → true"
  else
    fail "read-config.sh git_isolation with project override → true (got: '$actual')"
  fi

  # Error: Unknown key → non-zero exit + stderr
  stderr_output=$(bash "$CONFIG_SCRIPT" "nonexistent_key" \
    --defaults "$CONFIG_FIXTURES/extension-defaults.yml" \
    2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ -n "$stderr_output" ]; then
    pass "read-config.sh unknown key → non-zero exit + stderr"
  else
    fail "read-config.sh unknown key → non-zero exit + stderr (exit=$exit_code, stderr='$stderr_output')"
  fi
fi

# --------------------------------------------------------------------------
# 4. Roadmap parsing tests
# --------------------------------------------------------------------------

ROADMAP_SCRIPT="$PROJECT_ROOT/scripts/state/read-roadmap.sh"
ROADMAP_FIXTURE="$PROJECT_ROOT/tests/fixtures/roadmap-sample.md"

if [ ! -f "$ROADMAP_SCRIPT" ]; then
  echo "SKIP: read-roadmap.sh not yet implemented — skipping roadmap tests"
  fail "read-roadmap.sh phase IDs (script not found)"
  fail "read-roadmap.sh phase completion (script not found)"
  fail "read-roadmap.sh frontmatter tier (script not found)"
  fail "read-roadmap.sh phase count (script not found)"
else
  # Test: phase IDs are extracted
  phase_ids=$(bash "$ROADMAP_SCRIPT" "$ROADMAP_FIXTURE" phases 2>/dev/null) || true
  if echo "$phase_ids" | grep -q "P01" && echo "$phase_ids" | grep -q "P02" && echo "$phase_ids" | grep -q "P03"; then
    pass "read-roadmap.sh extracts phase IDs (P01, P02, P03)"
  else
    fail "read-roadmap.sh extracts phase IDs (got: '$phase_ids')"
  fi

  # Test: phase completion status
  p01_status=$(bash "$ROADMAP_SCRIPT" "$ROADMAP_FIXTURE" status P01 2>/dev/null) || true
  p02_status=$(bash "$ROADMAP_SCRIPT" "$ROADMAP_FIXTURE" status P02 2>/dev/null) || true
  if [ "$p01_status" = "complete" ] && [ "$p02_status" = "incomplete" ]; then
    pass "read-roadmap.sh phase completion (P01=complete, P02=incomplete)"
  else
    fail "read-roadmap.sh phase completion (P01='$p01_status', P02='$p02_status')"
  fi

  # Test: frontmatter tier
  tier=$(bash "$ROADMAP_SCRIPT" "$ROADMAP_FIXTURE" tier 2>/dev/null) || true
  if [ "$tier" = "C" ]; then
    pass "read-roadmap.sh frontmatter tier → C"
  else
    fail "read-roadmap.sh frontmatter tier → C (got: '$tier')"
  fi

  # Test: phase count
  count=$(bash "$ROADMAP_SCRIPT" "$ROADMAP_FIXTURE" count 2>/dev/null) || true
  if [ "$count" = "3" ]; then
    pass "read-roadmap.sh phase count → 3"
  else
    fail "read-roadmap.sh phase count → 3 (got: '$count')"
  fi
fi

# --------------------------------------------------------------------------
# 5. Scaffold idempotency tests
# --------------------------------------------------------------------------

SCAFFOLD_SCRIPT="$PROJECT_ROOT/scripts/lifecycle/scaffold.sh"

if [ ! -f "$SCAFFOLD_SCRIPT" ]; then
  echo "SKIP: scaffold.sh not yet implemented — skipping scaffold tests"
  fail "scaffold.sh creates milestone directory tree (script not found)"
  fail "scaffold.sh idempotent re-run (script not found)"
else
  TMPDIR_SCAFFOLD=$(mktemp -d)
  trap "rm -rf '$TMPDIR_SCAFFOLD'" EXIT

  # First run: creates structure
  bash "$SCAFFOLD_SCRIPT" "$TMPDIR_SCAFFOLD" M001 2>/dev/null
  scaffold_exit=$?

  if [ "$scaffold_exit" -eq 0 ] && [ -d "$TMPDIR_SCAFFOLD/milestones/M001" ]; then
    pass "scaffold.sh creates milestone directory tree"
  else
    fail "scaffold.sh creates milestone directory tree (exit=$scaffold_exit)"
  fi

  # Capture state after first scaffold
  first_run=$(find "$TMPDIR_SCAFFOLD" -type f -exec md5 {} \; 2>/dev/null | sort || find "$TMPDIR_SCAFFOLD" -type f -exec md5sum {} \; 2>/dev/null | sort) || true

  # Second run: idempotent (no changes)
  bash "$SCAFFOLD_SCRIPT" "$TMPDIR_SCAFFOLD" M001 2>/dev/null
  second_run=$(find "$TMPDIR_SCAFFOLD" -type f -exec md5 {} \; 2>/dev/null | sort || find "$TMPDIR_SCAFFOLD" -type f -exec md5sum {} \; 2>/dev/null | sort) || true

  if [ "$first_run" = "$second_run" ]; then
    pass "scaffold.sh idempotent re-run (no changes)"
  else
    fail "scaffold.sh idempotent re-run (files changed between runs)"
  fi
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "$PASS_COUNT/$TOTAL checks passed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
