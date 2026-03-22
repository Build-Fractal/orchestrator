#!/usr/bin/env bash
# tests/test-s04-core-commands.sh — Validates all S04 core command contracts
# Tests: verification scripts (check-must-haves, check-boundary-map, check-scope,
#        run-commands), dispatch scripts, command markdown files, and integration.
# Outputs structured PASS/FAIL lines per check. Exits 0 if all pass, 1 if any fail.
# Dependencies: bash only (no declare -A, bash 3.2 compatible per K001)

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

# Resolve project root
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

# ==========================================================================
# Section 1: Verification Script Tests
# ==========================================================================
echo ""
echo "--- Verification Scripts ---"

CHECK_MH="$PROJECT_ROOT/scripts/verify/check-must-haves.sh"
CHECK_BM="$PROJECT_ROOT/scripts/verify/check-boundary-map.sh"
CHECK_SC="$PROJECT_ROOT/scripts/verify/check-scope.sh"
RUN_CMD="$PROJECT_ROOT/scripts/verify/run-commands.sh"

PASS_FIXTURE="$PROJECT_ROOT/tests/fixtures/verify-pass"
FAIL_FIXTURE="$PROJECT_ROOT/tests/fixtures/verify-fail"
SCOPE_FIXTURE="$PROJECT_ROOT/tests/fixtures/verify-scope"

# --------------------------------------------------------------------------
# 1.1 check-must-haves.sh — passing fixture
# --------------------------------------------------------------------------

if [ ! -f "$CHECK_MH" ]; then
  fail "check-must-haves.sh exists (script not found)"
else
  output=$(bash "$CHECK_MH" "$PASS_FIXTURE/phases/P01" 2>/dev/null) && exit_code=0 || exit_code=$?
  if [ "$exit_code" -eq 0 ]; then
    pass "check-must-haves.sh verify-pass fixture → all PASS (exit 0)"
  else
    fail "check-must-haves.sh verify-pass fixture → all PASS (exit $exit_code, output: $output)"
  fi

  # Verify no FAIL lines in output
  fail_lines=$(echo "$output" | grep -c "^FAIL:" || true)
  if [ "$fail_lines" -eq 0 ]; then
    pass "check-must-haves.sh verify-pass fixture → zero FAIL lines"
  else
    fail "check-must-haves.sh verify-pass fixture → zero FAIL lines (got $fail_lines)"
  fi
fi

# --------------------------------------------------------------------------
# 1.2 check-must-haves.sh — failing fixture
# --------------------------------------------------------------------------

if [ ! -f "$CHECK_MH" ]; then
  fail "check-must-haves.sh verify-fail fixture (script not found)"
else
  output=$(bash "$CHECK_MH" "$FAIL_FIXTURE/phases/P01" 2>/dev/null) && exit_code=0 || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    pass "check-must-haves.sh verify-fail fixture → non-zero exit ($exit_code)"
  else
    fail "check-must-haves.sh verify-fail fixture → non-zero exit (got exit 0)"
  fi

  # Must have at least one FAIL line
  fail_lines=$(echo "$output" | grep -c "^FAIL:" || true)
  if [ "$fail_lines" -gt 0 ]; then
    pass "check-must-haves.sh verify-fail fixture → at least one FAIL line ($fail_lines found)"
  else
    fail "check-must-haves.sh verify-fail fixture → at least one FAIL line (none found)"
  fi
fi

# --------------------------------------------------------------------------
# 1.3 check-must-haves.sh — failure diagnostics (specific artifact name in output)
# --------------------------------------------------------------------------

if [ ! -f "$CHECK_MH" ]; then
  fail "check-must-haves.sh failure diagnostics (script not found)"
else
  output=$(bash "$CHECK_MH" "$FAIL_FIXTURE/phases/P01" 2>/dev/null) || true
  # The failing fixture has a missing "scripts/missing-script.sh" — check it's named in output
  if echo "$output" | grep "FAIL" | grep -q "missing-script.sh"; then
    pass "check-must-haves.sh failure output names specific missing artifact (missing-script.sh)"
  else
    fail "check-must-haves.sh failure output names specific missing artifact (missing-script.sh not found in FAIL lines)"
  fi
fi

# --------------------------------------------------------------------------
# 1.4 check-must-haves.sh — missing arguments error path
# --------------------------------------------------------------------------

if [ ! -f "$CHECK_MH" ]; then
  fail "check-must-haves.sh missing args → non-zero exit + stderr (script not found)"
else
  stderr_output=$(bash "$CHECK_MH" 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ -n "$stderr_output" ]; then
    pass "check-must-haves.sh missing args → non-zero exit + stderr"
  else
    fail "check-must-haves.sh missing args → non-zero exit + stderr (exit=$exit_code, stderr='$stderr_output')"
  fi
fi

# --------------------------------------------------------------------------
# 1.5 check-boundary-map.sh — passing fixture
# --------------------------------------------------------------------------

if [ ! -f "$CHECK_BM" ]; then
  fail "check-boundary-map.sh verify-pass fixture (script not found)"
else
  output=$(bash "$CHECK_BM" "$PASS_FIXTURE/M001-ROADMAP.md" P01 2>/dev/null) && exit_code=0 || exit_code=$?
  if [ "$exit_code" -eq 0 ]; then
    pass "check-boundary-map.sh verify-pass fixture → all PASS (exit 0)"
  else
    fail "check-boundary-map.sh verify-pass fixture → all PASS (exit $exit_code, output: $output)"
  fi
fi

# --------------------------------------------------------------------------
# 1.6 check-boundary-map.sh — failing fixture
# --------------------------------------------------------------------------

if [ ! -f "$CHECK_BM" ]; then
  fail "check-boundary-map.sh verify-fail fixture (script not found)"
else
  output=$(bash "$CHECK_BM" "$FAIL_FIXTURE/M001-ROADMAP.md" P01 2>/dev/null) && exit_code=0 || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    pass "check-boundary-map.sh verify-fail fixture → non-zero exit (missing produce item)"
  else
    fail "check-boundary-map.sh verify-fail fixture → non-zero exit (got exit 0)"
  fi

  fail_lines=$(echo "$output" | grep -c "^FAIL:" || true)
  if [ "$fail_lines" -gt 0 ]; then
    pass "check-boundary-map.sh verify-fail fixture → at least one FAIL line"
  else
    fail "check-boundary-map.sh verify-fail fixture → at least one FAIL line (none found)"
  fi
fi

# --------------------------------------------------------------------------
# 1.7 check-boundary-map.sh — missing arguments error path
# --------------------------------------------------------------------------

if [ ! -f "$CHECK_BM" ]; then
  fail "check-boundary-map.sh missing args → non-zero exit + stderr (script not found)"
else
  stderr_output=$(bash "$CHECK_BM" 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ -n "$stderr_output" ]; then
    pass "check-boundary-map.sh missing args → non-zero exit + stderr"
  else
    fail "check-boundary-map.sh missing args → non-zero exit + stderr (exit=$exit_code)"
  fi
fi

# --------------------------------------------------------------------------
# 1.8 check-scope.sh — in-scope files → no warnings
# --------------------------------------------------------------------------

if [ ! -f "$CHECK_SC" ]; then
  fail "check-scope.sh in-scope files (script not found)"
else
  output=$(bash "$CHECK_SC" "$SCOPE_FIXTURE/phases/P01/P01-PLAN.md" --files "scripts/in-scope.sh,docs/in-scope.md" 2>/dev/null)
  warn_lines=$(echo "$output" | grep -c "^WARN:" || true)
  if [ "$warn_lines" -eq 0 ]; then
    pass "check-scope.sh in-scope files → no warnings"
  else
    fail "check-scope.sh in-scope files → no warnings (got $warn_lines warnings)"
  fi
fi

# --------------------------------------------------------------------------
# 1.9 check-scope.sh — out-of-scope files → warnings reported
# --------------------------------------------------------------------------

if [ ! -f "$CHECK_SC" ]; then
  fail "check-scope.sh out-of-scope files (script not found)"
else
  output=$(bash "$CHECK_SC" "$SCOPE_FIXTURE/phases/P01/P01-PLAN.md" --files "scripts/in-scope.sh,unauthorized.txt" 2>/dev/null)
  warn_lines=$(echo "$output" | grep -c "^WARN:" || true)
  if [ "$warn_lines" -gt 0 ]; then
    pass "check-scope.sh out-of-scope files → warnings reported ($warn_lines)"
  else
    fail "check-scope.sh out-of-scope files → warnings reported (no WARN lines)"
  fi

  # Verify the specific out-of-scope file is named
  if echo "$output" | grep "WARN" | grep -q "unauthorized.txt"; then
    pass "check-scope.sh out-of-scope output names specific file (unauthorized.txt)"
  else
    fail "check-scope.sh out-of-scope output names specific file (unauthorized.txt not in WARN)"
  fi
fi

# --------------------------------------------------------------------------
# 1.10 check-scope.sh — missing arguments error path
# --------------------------------------------------------------------------

if [ ! -f "$CHECK_SC" ]; then
  fail "check-scope.sh missing args → non-zero exit + stderr (script not found)"
else
  stderr_output=$(bash "$CHECK_SC" 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ -n "$stderr_output" ]; then
    pass "check-scope.sh missing args → non-zero exit + stderr"
  else
    fail "check-scope.sh missing args → non-zero exit + stderr (exit=$exit_code)"
  fi
fi

# --------------------------------------------------------------------------
# 1.11 run-commands.sh — passing commands
# --------------------------------------------------------------------------

if [ ! -f "$RUN_CMD" ]; then
  fail "run-commands.sh passing command (script not found)"
else
  output=$(bash "$RUN_CMD" "echo hello" 2>/dev/null) && exit_code=0 || exit_code=$?
  if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^PASS:"; then
    pass "run-commands.sh passing command → PASS (exit 0)"
  else
    fail "run-commands.sh passing command → PASS (exit=$exit_code, output: $output)"
  fi
fi

# --------------------------------------------------------------------------
# 1.12 run-commands.sh — failing command
# --------------------------------------------------------------------------

if [ ! -f "$RUN_CMD" ]; then
  fail "run-commands.sh failing command (script not found)"
else
  output=$(bash "$RUN_CMD" "false" 2>/dev/null) && exit_code=0 || exit_code=$?
  if [ "$exit_code" -ne 0 ] && echo "$output" | grep -q "^FAIL:"; then
    pass "run-commands.sh failing command → FAIL (exit $exit_code)"
  else
    fail "run-commands.sh failing command → FAIL (exit=$exit_code, output: $output)"
  fi
fi

# --------------------------------------------------------------------------
# 1.13 run-commands.sh — no commands → SKIP
# --------------------------------------------------------------------------

if [ ! -f "$RUN_CMD" ]; then
  fail "run-commands.sh no commands → SKIP (script not found)"
else
  output=$(bash "$RUN_CMD" 2>/dev/null) && exit_code=0 || exit_code=$?
  if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^SKIP:"; then
    pass "run-commands.sh no commands → SKIP (exit 0)"
  else
    fail "run-commands.sh no commands → SKIP (exit=$exit_code, output: $output)"
  fi
fi

# --------------------------------------------------------------------------
# 1.14 check-external-mods.sh — script exists and is executable
# --------------------------------------------------------------------------

CHECK_EM="$PROJECT_ROOT/scripts/verify/check-external-mods.sh"

if [ -f "$CHECK_EM" ] && [ -x "$CHECK_EM" ]; then
  pass "scripts/verify/check-external-mods.sh exists and is executable"
else
  fail "scripts/verify/check-external-mods.sh exists and is executable"
fi

# --------------------------------------------------------------------------
# 1.15 check-external-mods.sh — missing lock file → SKIP
# --------------------------------------------------------------------------

if [ -f "$CHECK_EM" ]; then
  output=$(bash "$CHECK_EM" "/tmp/nonexistent-lock-$$" 2>/dev/null) && exit_code=0 || exit_code=$?
  if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^SKIP:"; then
    pass "check-external-mods.sh missing lock → SKIP (exit 0)"
  else
    fail "check-external-mods.sh missing lock → SKIP (exit=$exit_code, output: $output)"
  fi
else
  fail "check-external-mods.sh missing lock test (script not found)"
fi

# --------------------------------------------------------------------------
# 1.16 check-external-mods.sh — lock without phase_start_tree → SKIP
# --------------------------------------------------------------------------

if [ -f "$CHECK_EM" ]; then
  TMPLOCK_EM=$(mktemp)
  echo '{"pid": 1, "startedAt": "2026-01-01T00:00:00Z"}' > "$TMPLOCK_EM"
  output=$(bash "$CHECK_EM" "$TMPLOCK_EM" 2>/dev/null) && exit_code=0 || exit_code=$?
  rm -f "$TMPLOCK_EM"
  if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^SKIP:"; then
    pass "check-external-mods.sh lock without tree → SKIP (exit 0)"
  else
    fail "check-external-mods.sh lock without tree → SKIP (exit=$exit_code, output: $output)"
  fi
else
  fail "check-external-mods.sh lock without tree test (script not found)"
fi

# --------------------------------------------------------------------------
# 1.17 check-external-mods.sh — no args → exit 1
# --------------------------------------------------------------------------

if [ -f "$CHECK_EM" ]; then
  stderr_output=$(bash "$CHECK_EM" 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ -n "$stderr_output" ]; then
    pass "check-external-mods.sh no args → exit 1 + stderr"
  else
    fail "check-external-mods.sh no args → exit 1 + stderr (exit=$exit_code)"
  fi
else
  fail "check-external-mods.sh no args test (script not found)"
fi

# --------------------------------------------------------------------------
# 1.18 check-external-mods.sh — structured output format (PASS/WARN/SKIP prefix)
# --------------------------------------------------------------------------

if [ -f "$CHECK_EM" ]; then
  # Use a lock file with an empty tree hash to trigger SKIP
  TMPLOCK_FMT=$(mktemp)
  echo '{"pid": 1, "phase_start_tree": ""}' > "$TMPLOCK_FMT"
  output=$(bash "$CHECK_EM" "$TMPLOCK_FMT" 2>/dev/null) && exit_code=0 || exit_code=$?
  rm -f "$TMPLOCK_FMT"
  if echo "$output" | grep -qE "^(PASS:|WARN:|SKIP:)"; then
    pass "check-external-mods.sh output uses structured prefix (PASS/WARN/SKIP)"
  else
    fail "check-external-mods.sh output uses structured prefix (output: $output)"
  fi
else
  fail "check-external-mods.sh structured output test (script not found)"
fi

# ==========================================================================
# Section 2: Dispatch Script Tests
# ==========================================================================
echo ""
echo "--- Dispatch Scripts ---"

SCOPE_FILTER="$PROJECT_ROOT/scripts/dispatch/scope-filter.sh"
DETECT_CAP="$PROJECT_ROOT/scripts/dispatch/detect-capabilities.sh"
BUILD_CTX="$PROJECT_ROOT/scripts/dispatch/build-context.sh"

DISPATCH_FIXTURE="$PROJECT_ROOT/tests/fixtures/dispatch-state"

# --------------------------------------------------------------------------
# 2.1 scope-filter.sh — knowledge filter includes [project] and [milestone:M001]
# --------------------------------------------------------------------------

if [ ! -f "$SCOPE_FILTER" ]; then
  fail "scope-filter.sh knowledge filter (script not found)"
else
  output=$(bash "$SCOPE_FILTER" "$DISPATCH_FIXTURE/KNOWLEDGE.md" M001/P02 --type knowledge 2>/dev/null)
  # Should include K001 ([project]) and K002 ([milestone:M001])
  has_project=$(echo "$output" | grep -c "K001" || true)
  has_milestone=$(echo "$output" | grep -c "K002" || true)
  has_p03=$(echo "$output" | grep -c "K003" || true)
  if [ "$has_project" -gt 0 ] && [ "$has_milestone" -gt 0 ] && [ "$has_p03" -eq 0 ]; then
    pass "scope-filter.sh knowledge → includes [project]+[milestone:M001], excludes [phase:M001/P03]"
  else
    fail "scope-filter.sh knowledge → includes [project]+[milestone:M001], excludes [phase:M001/P03] (project=$has_project, milestone=$has_milestone, p03=$has_p03)"
  fi
fi

# --------------------------------------------------------------------------
# 2.2 scope-filter.sh — decisions filter includes P01+P02+arch, excludes P03 non-arch
# --------------------------------------------------------------------------

if [ ! -f "$SCOPE_FILTER" ]; then
  fail "scope-filter.sh decisions filter (script not found)"
else
  output=$(bash "$SCOPE_FILTER" "$DISPATCH_FIXTURE/DECISIONS.md" M001/P02 --type decisions --depends P01 2>/dev/null)
  has_d001=$(echo "$output" | grep -c "D001" || true)
  has_d002=$(echo "$output" | grep -c "D002" || true)
  has_d003=$(echo "$output" | grep -c "D003" || true)
  has_d004=$(echo "$output" | grep -c "D004" || true)
  if [ "$has_d001" -gt 0 ] && [ "$has_d002" -gt 0 ] && [ "$has_d003" -gt 0 ] && [ "$has_d004" -eq 0 ]; then
    pass "scope-filter.sh decisions → includes P01+P02+arch, excludes P03 convention"
  else
    fail "scope-filter.sh decisions → includes P01+P02+arch, excludes P03 convention (d1=$has_d001, d2=$has_d002, d3=$has_d003, d4=$has_d004)"
  fi
fi

# --------------------------------------------------------------------------
# 2.3 scope-filter.sh — nonexistent file → exit 0, empty output
# --------------------------------------------------------------------------

if [ ! -f "$SCOPE_FILTER" ]; then
  fail "scope-filter.sh nonexistent file (script not found)"
else
  output=$(bash "$SCOPE_FILTER" "/tmp/nonexistent-file-$$.md" M001/P02 --type knowledge 2>/dev/null) && exit_code=0 || exit_code=$?
  if [ "$exit_code" -eq 0 ] && [ -z "$output" ]; then
    pass "scope-filter.sh nonexistent file → exit 0, empty output"
  else
    fail "scope-filter.sh nonexistent file → exit 0, empty output (exit=$exit_code, output='$output')"
  fi
fi

# --------------------------------------------------------------------------
# 2.4 scope-filter.sh — missing arguments → exit 1 + stderr
# --------------------------------------------------------------------------

if [ ! -f "$SCOPE_FILTER" ]; then
  fail "scope-filter.sh missing args (script not found)"
else
  stderr_output=$(bash "$SCOPE_FILTER" 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ -n "$stderr_output" ]; then
    pass "scope-filter.sh missing args → non-zero exit + stderr"
  else
    fail "scope-filter.sh missing args → non-zero exit + stderr (exit=$exit_code)"
  fi
fi

# --------------------------------------------------------------------------
# 2.5 detect-capabilities.sh — outputs key=value including shell_execution=true
# --------------------------------------------------------------------------

if [ ! -f "$DETECT_CAP" ]; then
  fail "detect-capabilities.sh key=value output (script not found)"
else
  output=$(bash "$DETECT_CAP" 2>/dev/null) && exit_code=0 || exit_code=$?
  has_shell=$(echo "$output" | grep -c "shell_execution=true" || true)
  has_runtime=$(echo "$output" | grep -c "runtime=" || true)
  if [ "$exit_code" -eq 0 ] && [ "$has_shell" -gt 0 ] && [ "$has_runtime" -gt 0 ]; then
    pass "detect-capabilities.sh → key=value output with shell_execution=true and runtime="
  else
    fail "detect-capabilities.sh → key=value output (exit=$exit_code, shell=$has_shell, runtime=$has_runtime)"
  fi
fi

# --------------------------------------------------------------------------
# 2.5b detect-capabilities.sh — Claude Code environment detection
# --------------------------------------------------------------------------

cc_output=$(CLAUDE_CODE=1 bash "$DETECT_CAP" 2>/dev/null)
if echo "$cc_output" | grep -q "agent_tool_available=true"; then
  pass "detect-capabilities.sh CLAUDE_CODE=1 → agent_tool_available=true"
else
  fail "detect-capabilities.sh CLAUDE_CODE=1 → agent_tool_available=true (got: '$cc_output')"
fi

no_cc_output=$(bash "$DETECT_CAP" 2>/dev/null)
if echo "$no_cc_output" | grep -q "agent_tool_available=false"; then
  pass "detect-capabilities.sh without CLAUDE_CODE → agent_tool_available=false"
else
  fail "detect-capabilities.sh without CLAUDE_CODE → agent_tool_available=false (got: '$no_cc_output')"
fi

json_output=$(CLAUDE_CODE=1 bash "$DETECT_CAP" --format json 2>/dev/null)
if echo "$json_output" | grep -q '"agent_tool_available"'; then
  pass "detect-capabilities.sh JSON output contains agent_tool_available key"
else
  fail "detect-capabilities.sh JSON output contains agent_tool_available key"
fi

# --------------------------------------------------------------------------
# 2.6 build-context.sh — assembles payload from fixture state
# --------------------------------------------------------------------------

if [ ! -f "$BUILD_CTX" ]; then
  fail "build-context.sh payload assembly (script not found)"
else
  output=$(bash "$BUILD_CTX" "$DISPATCH_FIXTURE" M001 P02 T01 2>/dev/null) && exit_code=0 || exit_code=$?
  # Check payload is non-empty and contains task plan content
  has_task=$(echo "$output" | grep -c "Implement dispatch scripts" || true)
  has_state=$(echo "$output" | grep -c "Current State" || true)
  has_tier=$(echo "$output" | grep -c "Tier" || true)
  if [ "$exit_code" -eq 0 ] && [ -n "$output" ] && [ "$has_task" -gt 0 ] && [ "$has_state" -gt 0 ]; then
    pass "build-context.sh fixture → non-empty payload with task plan content"
  else
    fail "build-context.sh fixture → non-empty payload (exit=$exit_code, task=$has_task, state=$has_state)"
  fi
fi

# --------------------------------------------------------------------------
# 2.7 build-context.sh — missing task plan → exit 1 + stderr
# --------------------------------------------------------------------------

if [ ! -f "$BUILD_CTX" ]; then
  fail "build-context.sh missing task plan (script not found)"
else
  stderr_output=$(bash "$BUILD_CTX" "$DISPATCH_FIXTURE" M001 P02 T99 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
  if [ "$exit_code" -ne 0 ] && echo "$stderr_output" | grep -q "task plan not found"; then
    pass "build-context.sh missing task plan → exit 1 + descriptive stderr"
  else
    fail "build-context.sh missing task plan → exit 1 + stderr (exit=$exit_code, stderr='$stderr_output')"
  fi
fi

# --------------------------------------------------------------------------
# 2.8 build-context.sh — reports context budget to stderr
# --------------------------------------------------------------------------

if [ ! -f "$BUILD_CTX" ]; then
  fail "build-context.sh context budget reporting (script not found)"
else
  stderr_output=$(bash "$BUILD_CTX" "$DISPATCH_FIXTURE" M001 P02 T01 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
  if echo "$stderr_output" | grep -q "Context payload:.*bytes"; then
    pass "build-context.sh → reports context budget to stderr"
  else
    fail "build-context.sh → reports context budget to stderr (stderr='$stderr_output')"
  fi
fi

# --------------------------------------------------------------------------
# 2.9 build-context.sh — missing arguments → exit 1 + stderr
# --------------------------------------------------------------------------

if [ ! -f "$BUILD_CTX" ]; then
  fail "build-context.sh missing args (script not found)"
else
  stderr_output=$(bash "$BUILD_CTX" 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ -n "$stderr_output" ]; then
    pass "build-context.sh missing args → non-zero exit + stderr"
  else
    fail "build-context.sh missing args → non-zero exit + stderr (exit=$exit_code)"
  fi
fi

# ==========================================================================
# Section 2b: Tier A Evaluate Command Content Tests (FR-001, FR-003)
# ==========================================================================
echo ""
echo "--- Tier A Evaluate Content ---"

EVALUATE_CMD="$PROJECT_ROOT/commands/evaluate.md"

# Assert: evaluate.md contains "Tier A" routing to standard spec-kit
if grep -q "Tier A" "$EVALUATE_CMD" && grep -q "standard spec-kit" "$EVALUATE_CMD"; then
  pass "evaluate.md contains Tier A routing to standard spec-kit"
else
  fail "evaluate.md contains Tier A routing to standard spec-kit"
fi

# Assert: evaluate.md contains "no orchestrator" or "zero additional" or "Do NOT create" language
if grep -qi "no orchestrator\|Do NOT create\|no additional files" "$EVALUATE_CMD"; then
  pass "evaluate.md contains no-orchestrator language for Tier A"
else
  fail "evaluate.md contains no-orchestrator language for Tier A"
fi

# ==========================================================================
# Section 2c: Boundary Map Contract Violation Tests (FR-008)
# ==========================================================================
echo ""
echo "--- Boundary Map Contract Violation ---"

BOUNDARY_FAIL_FIXTURE="$PROJECT_ROOT/tests/fixtures/verify-boundary-fail"

# Assert: check-boundary-map.sh on verify-boundary-fail fixture → FAIL for missing src/api.ts
if [ -f "$CHECK_BM" ]; then
  output=$(bash "$CHECK_BM" "$BOUNDARY_FAIL_FIXTURE/M001-ROADMAP.md" P01 --root "$BOUNDARY_FAIL_FIXTURE" 2>/dev/null) && exit_code=0 || exit_code=$?
  if [ "$exit_code" -eq 1 ]; then
    pass "check-boundary-map.sh verify-boundary-fail → exit 1 (missing produce item)"
  else
    fail "check-boundary-map.sh verify-boundary-fail → exit 1 (got exit $exit_code)"
  fi

  fail_lines=$(echo "$output" | grep -c "^FAIL:" || true)
  if [ "$fail_lines" -gt 0 ]; then
    pass "check-boundary-map.sh verify-boundary-fail → FAIL line for missing contract"
  else
    fail "check-boundary-map.sh verify-boundary-fail → FAIL line (none found)"
  fi

  # Verify the specific missing item is named
  if echo "$output" | grep "FAIL" | grep -q "src/api.ts"; then
    pass "check-boundary-map.sh verify-boundary-fail → names missing src/api.ts"
  else
    fail "check-boundary-map.sh verify-boundary-fail → names missing src/api.ts"
  fi
else
  fail "check-boundary-map.sh verify-boundary-fail tests (script not found)"
  fail "check-boundary-map.sh verify-boundary-fail tests (script not found)"
  fail "check-boundary-map.sh verify-boundary-fail tests (script not found)"
fi

# ==========================================================================
# Section 2d: External Modification Detection Test (FR-064)
# ==========================================================================
echo ""
echo "--- External Modification Detection ---"

if [ -f "$CHECK_EM" ]; then
  # Create a temporary git repo for this test
  TMPDIR_EXTMOD=$(mktemp -d)
  extmod_ok=true

  # Initialize repo with an initial commit
  (cd "$TMPDIR_EXTMOD" && git init -q && echo "initial" > file.txt && git add file.txt && git commit -q -m "init") 2>/dev/null

  # Record the initial tree hash (commit hash)
  INITIAL_HASH=$(cd "$TMPDIR_EXTMOD" && git rev-parse HEAD)

  # Modify a file and commit
  (cd "$TMPDIR_EXTMOD" && echo "modified" > file.txt && git add file.txt && git commit -q -m "external change") 2>/dev/null

  # Create lock file with phase_start_tree pointing to initial commit
  # Multi-line JSON format required for json_field parser
  TMPLOCK_EXTMOD="$TMPDIR_EXTMOD/test.lock"
  cat > "$TMPLOCK_EXTMOD" <<LOCKEOF
{
  "pid": 1,
  "phase_start_tree": "$INITIAL_HASH"
}
LOCKEOF

  # Run check-external-mods.sh from within the temp git repo
  output=$(cd "$TMPDIR_EXTMOD" && bash "$CHECK_EM" "$TMPLOCK_EXTMOD" 2>/dev/null) && exit_code=0 || exit_code=$?

  # Assert: output contains WARN
  if echo "$output" | grep -q "^WARN:"; then
    pass "check-external-mods.sh detects modification (WARN output)"
  else
    fail "check-external-mods.sh detects modification (output: $output)"
  fi

  # Assert: exit code is 2
  if [ "$exit_code" -eq 2 ]; then
    pass "check-external-mods.sh external mods → exit 2"
  else
    fail "check-external-mods.sh external mods → exit 2 (got exit $exit_code)"
  fi

  # Clean up
  rm -rf "$TMPDIR_EXTMOD"
else
  fail "check-external-mods.sh external mod detection (script not found)"
  fail "check-external-mods.sh external mod detection (script not found)"
fi

# ==========================================================================
# Section 2e: Build Context Payload Ratio Test (SC-002)
# ==========================================================================
echo ""
echo "--- Build Context Payload Ratio ---"

if [ -f "$BUILD_CTX" ]; then
  stderr_output=$(bash "$BUILD_CTX" "$DISPATCH_FIXTURE" M001 P02 T01 2>&1 1>/dev/null) && exit_code=$? || exit_code=$?

  # Assert: stderr contains a percentage
  if echo "$stderr_output" | grep -qE '[0-9]+%'; then
    pass "build-context.sh stderr reports percentage"
  else
    fail "build-context.sh stderr reports percentage (stderr: '$stderr_output')"
  fi

  # Assert: percentage is less than 100% (payload is subset of total)
  pct=$(echo "$stderr_output" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
  if [ -n "$pct" ] && [ "$pct" -lt 100 ]; then
    pass "build-context.sh payload ratio < 100% (${pct}%)"
  else
    fail "build-context.sh payload ratio < 100% (got: ${pct:-empty}%)"
  fi
else
  fail "build-context.sh payload ratio tests (script not found)"
  fail "build-context.sh payload ratio tests (script not found)"
fi

# ==========================================================================
# Section 3: Integration Tests — Command Files + Cross-References
# ==========================================================================
echo ""
echo "--- Integration Tests ---"

# The 6 core S04 commands
COMMANDS="evaluate roadmap plan-phase dispatch verify status"

# --------------------------------------------------------------------------
# 3.1 All 6 command files exist and are not placeholder
# --------------------------------------------------------------------------

for cmd in $COMMANDS; do
  cmd_file="$PROJECT_ROOT/commands/${cmd}.md"
  if [ ! -f "$cmd_file" ]; then
    fail "commands/${cmd}.md exists"
  elif grep -q "Placeholder" "$cmd_file"; then
    fail "commands/${cmd}.md has no Placeholder text"
  else
    pass "commands/${cmd}.md exists and has no Placeholder text"
  fi
done

# --------------------------------------------------------------------------
# 3.2 All 6 command files have YAML frontmatter
# --------------------------------------------------------------------------

for cmd in $COMMANDS; do
  cmd_file="$PROJECT_ROOT/commands/${cmd}.md"
  if [ ! -f "$cmd_file" ]; then
    fail "commands/${cmd}.md has YAML frontmatter (file not found)"
  else
    first_line=$(head -1 "$cmd_file")
    if [ "$first_line" = "---" ]; then
      pass "commands/${cmd}.md has YAML frontmatter"
    else
      fail "commands/${cmd}.md has YAML frontmatter (first line: '$first_line')"
    fi
  fi
done

# --------------------------------------------------------------------------
# 3.3 All 7 helper scripts exist and are executable
# --------------------------------------------------------------------------

VERIFY_SCRIPTS="check-must-haves.sh check-boundary-map.sh check-scope.sh run-commands.sh check-external-mods.sh"
DISPATCH_SCRIPTS="scope-filter.sh detect-capabilities.sh build-context.sh"

for script in $VERIFY_SCRIPTS; do
  script_path="$PROJECT_ROOT/scripts/verify/$script"
  if [ -f "$script_path" ] && [ -x "$script_path" ]; then
    pass "scripts/verify/$script exists and is executable"
  elif [ -f "$script_path" ]; then
    fail "scripts/verify/$script is executable (file exists but not executable)"
  else
    fail "scripts/verify/$script exists (not found)"
  fi
done

for script in $DISPATCH_SCRIPTS; do
  script_path="$PROJECT_ROOT/scripts/dispatch/$script"
  if [ -f "$script_path" ] && [ -x "$script_path" ]; then
    pass "scripts/dispatch/$script exists and is executable"
  elif [ -f "$script_path" ]; then
    fail "scripts/dispatch/$script is executable (file exists but not executable)"
  else
    fail "scripts/dispatch/$script exists (not found)"
  fi
done

# --------------------------------------------------------------------------
# 3.4 Cross-reference validation — commands reference their helper scripts/templates
# --------------------------------------------------------------------------

# verify.md references check-must-haves
if grep -q "check-must-haves" "$PROJECT_ROOT/commands/verify.md"; then
  pass "verify.md references check-must-haves"
else
  fail "verify.md references check-must-haves"
fi

# dispatch.md references build-context
if grep -q "build-context" "$PROJECT_ROOT/commands/dispatch.md"; then
  pass "dispatch.md references build-context"
else
  fail "dispatch.md references build-context"
fi

# dispatch.md references record-result.sh
if grep -q "record-result" "$PROJECT_ROOT/commands/dispatch.md"; then
  pass "dispatch.md references record-result"
else
  fail "dispatch.md references record-result"
fi

# evaluate.md references scaffold.sh
if grep -q "scaffold" "$PROJECT_ROOT/commands/evaluate.md"; then
  pass "evaluate.md references scaffold"
else
  fail "evaluate.md references scaffold"
fi

# roadmap.md references roadmap template
if grep -q "templates/roadmap" "$PROJECT_ROOT/commands/roadmap.md"; then
  pass "roadmap.md references templates/roadmap"
else
  fail "roadmap.md references templates/roadmap"
fi

# plan-phase.md references phase-plan template
if grep -q "templates/phase-plan" "$PROJECT_ROOT/commands/plan-phase.md"; then
  pass "plan-phase.md references templates/phase-plan"
else
  fail "plan-phase.md references templates/phase-plan"
fi

# status.md references derive-phase
if grep -q "derive-phase" "$PROJECT_ROOT/commands/status.md"; then
  pass "status.md references derive-phase"
else
  fail "status.md references derive-phase"
fi

# ==========================================================================
# Section 3b: Scope Filtering with Multiple Milestones (FR-062)
# ==========================================================================
echo ""
echo "--- Scope Filtering Multi-Milestone ---"

MULTI_SCOPE_FIXTURE="$PROJECT_ROOT/tests/fixtures/dispatch-multi-scope"

if [ -f "$SCOPE_FILTER" ]; then
  # Run scope-filter.sh with --milestone M001 scope (M001/P01 context)
  multi_output=$(bash "$SCOPE_FILTER" "$MULTI_SCOPE_FIXTURE/KNOWLEDGE.md" M001/P01 --type knowledge 2>/dev/null) || true

  # Assert: output includes all [project] entries (K001, K002, K003)
  project_hits=0
  for kid in K001 K002 K003; do
    if echo "$multi_output" | grep -q "$kid"; then
      project_hits=$((project_hits + 1))
    fi
  done
  if [ "$project_hits" -eq 3 ]; then
    pass "scope-filter.sh multi-milestone → includes all 3 [project] entries"
  else
    fail "scope-filter.sh multi-milestone → includes all 3 [project] entries (got $project_hits)"
  fi

  # Assert: output includes [milestone:M001] entries (K004, K005, K006)
  m001_hits=0
  for kid in K004 K005 K006; do
    if echo "$multi_output" | grep -q "$kid"; then
      m001_hits=$((m001_hits + 1))
    fi
  done
  if [ "$m001_hits" -eq 3 ]; then
    pass "scope-filter.sh multi-milestone → includes all 3 [milestone:M001] entries"
  else
    fail "scope-filter.sh multi-milestone → includes all 3 [milestone:M001] entries (got $m001_hits)"
  fi

  # Assert: output excludes [milestone:M002] entries (K007, K008, K009)
  m002_hits=0
  for kid in K007 K008 K009; do
    if echo "$multi_output" | grep -q "$kid"; then
      m002_hits=$((m002_hits + 1))
    fi
  done
  if [ "$m002_hits" -eq 0 ]; then
    pass "scope-filter.sh multi-milestone → excludes all 3 [milestone:M002] entries"
  else
    fail "scope-filter.sh multi-milestone → excludes [milestone:M002] entries (found $m002_hits)"
  fi

  # Assert: output excludes [phase:M001/P03] entries (K010, K011, K012) — P03 not current
  p03_hits=0
  for kid in K010 K011 K012; do
    if echo "$multi_output" | grep -q "$kid"; then
      p03_hits=$((p03_hits + 1))
    fi
  done
  if [ "$p03_hits" -eq 0 ]; then
    pass "scope-filter.sh multi-milestone → excludes all 3 [phase:M001/P03] entries (not current phase)"
  else
    fail "scope-filter.sh multi-milestone → excludes [phase:M001/P03] entries (found $p03_hits)"
  fi
else
  fail "scope-filter.sh multi-milestone tests — script not found"
  fail "scope-filter.sh multi-milestone tests — script not found"
  fail "scope-filter.sh multi-milestone tests — script not found"
  fail "scope-filter.sh multi-milestone tests — script not found"
fi

# ==========================================================================
# Summary
# ==========================================================================
echo ""
echo "$PASS_COUNT/$TOTAL checks passed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "$FAIL_COUNT checks FAILED"
  exit 1
fi

exit 0
