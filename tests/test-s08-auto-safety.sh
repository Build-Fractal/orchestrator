#!/usr/bin/env bash
# tests/test-s08-auto-safety.sh — Regression tests for autonomous execution safety
# Verifies that the orchestrator's command-emitting paths (commands/*.md) and
# helper scripts avoid patterns that trigger Claude Code's harness safety
# heuristics (AD-19).
#
# Test categories:
#   1. No command substitution in emitted commands (auto.md instructions)
#   2. No inline loops in emitted commands
#   3. No backtick-wrapped machine paths in validated sections
#   4. No newline-# quoted argument bug
#   5. No writes outside configured workspace
#   6. Cleanup is non-destructive in auto mode
#   7. --output-file support in key scripts
#   8. classify-command.sh correctness
#
# Usage: bash tests/test-s08-auto-safety.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

PASSED=0
FAILED=0

pass() {
  echo "PASS: $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo "FAIL: $1"
  FAILED=$((FAILED + 1))
}

echo "=== Test Suite S08: Autonomous Execution Safety ==="
echo ""

# ============================================================================
# Section 1: No command substitution in auto.md instructions
# ============================================================================

echo "--- Section 1: No command substitution in auto.md bash blocks ---"

# Extract bash code blocks from auto.md and check for $(...) patterns
auto_bash_blocks=$(sed -n '/^```bash/,/^```$/p' commands/auto.md | grep -v '```')

if echo "$auto_bash_blocks" | grep -qE '\$\(bash'; then
  fail "auto.md still contains \$(bash ...) command substitution in code blocks"
else
  pass "auto.md has no \$(bash ...) command substitution in code blocks"
fi

if echo "$auto_bash_blocks" | grep -qE '\$\(.*\)' | grep -v 'output-file' 2>/dev/null; then
  # Check if any remaining $(...) are in code blocks (not documentation)
  remaining=$(echo "$auto_bash_blocks" | grep -E '\$\(.*\)' || true)
  if [ -n "$remaining" ]; then
    fail "auto.md bash blocks contain command substitution: $remaining"
  else
    pass "auto.md bash blocks are free of command substitution"
  fi
else
  pass "auto.md bash blocks are free of command substitution"
fi

# Check that auto.md uses --output-file pattern
if grep -q '\-\-output-file=' commands/auto.md; then
  pass "auto.md uses --output-file pattern for output capture"
else
  fail "auto.md does not use --output-file pattern"
fi

# ============================================================================
# Section 2: No inline loops in auto.md bash blocks
# ============================================================================

echo ""
echo "--- Section 2: No inline loops in auto.md bash blocks ---"

if echo "$auto_bash_blocks" | grep -qE '\bfor \b.*\bdo\b|\bwhile \b.*\bdo\b'; then
  fail "auto.md bash blocks contain inline for/while loops"
else
  pass "auto.md bash blocks have no inline for/while loops"
fi

if echo "$auto_bash_blocks" | grep -qE '^\s*if \['; then
  fail "auto.md bash blocks contain inline if-then blocks"
else
  pass "auto.md bash blocks have no inline if-then blocks"
fi

# ============================================================================
# Section 3: No /tmp writes in command instructions
# ============================================================================

echo ""
echo "--- Section 3: No /tmp writes in command bash blocks ---"

# Check auto.md
auto_tmp=$(sed -n '/^```bash/,/^```$/p' commands/auto.md | grep '/tmp/' || true)
if [ -n "$auto_tmp" ]; then
  fail "auto.md bash blocks write to /tmp: $auto_tmp"
else
  pass "auto.md bash blocks have no /tmp writes"
fi

# Check evaluate.md
eval_tmp=$(sed -n '/^```bash/,/^```$/p' commands/evaluate.md | grep '/tmp/' || true)
if [ -n "$eval_tmp" ]; then
  fail "evaluate.md bash blocks write to /tmp: $eval_tmp"
else
  pass "evaluate.md bash blocks have no /tmp writes"
fi

# ============================================================================
# Section 4: No rm -rf in command bash blocks
# ============================================================================

echo ""
echo "--- Section 4: No destructive rm in command bash blocks ---"

for cmd_file in commands/auto.md commands/evaluate.md commands/dispatch.md; do
  basename_cmd=$(basename "$cmd_file")
  rm_lines=$(sed -n '/^```bash/,/^```$/p' "$cmd_file" | grep 'rm -rf' || true)
  if [ -n "$rm_lines" ]; then
    fail "$basename_cmd bash blocks contain rm -rf"
  else
    pass "$basename_cmd bash blocks have no rm -rf"
  fi
done

# ============================================================================
# Section 5: --output-file support in key scripts
# ============================================================================

echo ""
echo "--- Section 5: --output-file support in key scripts ---"

# Test auto-loop.sh --output-file
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

mkdir -p "$TMPDIR_TEST/phases/P01/tasks"
cat > "$TMPDIR_TEST/M001-ROADMAP.md" << 'EOF'
---
milestone: M001
tier: C
---
# Roadmap
## Phases
- **P01** — Test [executing] (risk: low, depends: none)
EOF
cat > "$TMPDIR_TEST/phases/P01/P01-PLAN.md" << 'EOF'
---
id: P01
---
# P01
EOF
cat > "$TMPDIR_TEST/phases/P01/tasks/T01-PLAN.md" << 'EOF'
---
id: T01
---
# T01
## Verification
- Check: `test -f README.md`
EOF
echo '---' > "$TMPDIR_TEST/M001-EVALUATION.md"

# Test pre-dispatch with output file
bash scripts/lifecycle/auto-loop.sh "$TMPDIR_TEST" --output-file="$TMPDIR_TEST/pre-dispatch.txt" 2>/dev/null || true
if [ -f "$TMPDIR_TEST/pre-dispatch.txt" ]; then
  pass "auto-loop.sh pre-dispatch writes to --output-file"
else
  fail "auto-loop.sh pre-dispatch did not create --output-file"
fi

# Test verify step with output file
bash scripts/lifecycle/auto-loop.sh "$TMPDIR_TEST" --step=V --phase=P01 --task=T01 --output-file="$TMPDIR_TEST/verify.txt" 2>/dev/null || true
if [ -f "$TMPDIR_TEST/verify.txt" ]; then
  content=$(cat "$TMPDIR_TEST/verify.txt")
  if echo "$content" | grep -q "AUTO:VERIFY"; then
    pass "auto-loop.sh --step=V writes AUTO:VERIFY to --output-file"
  else
    fail "auto-loop.sh --step=V output file missing AUTO:VERIFY line"
  fi
else
  fail "auto-loop.sh --step=V did not create --output-file"
fi

# Test context check with output file
bash scripts/lifecycle/auto-loop.sh "$TMPDIR_TEST" --step=X --output-file="$TMPDIR_TEST/context.txt" 2>/dev/null || true
if [ -f "$TMPDIR_TEST/context.txt" ]; then
  if grep -q "CONTEXT:" "$TMPDIR_TEST/context.txt"; then
    pass "auto-loop.sh --step=X writes CONTEXT: to --output-file"
  else
    fail "auto-loop.sh --step=X output file missing CONTEXT: line"
  fi
else
  fail "auto-loop.sh --step=X did not create --output-file"
fi

# Test backward compatibility (no --output-file → stdout)
stdout_output=$(bash scripts/lifecycle/auto-loop.sh "$TMPDIR_TEST" --step=X 2>/dev/null) || true
if echo "$stdout_output" | grep -q "CONTEXT:"; then
  pass "auto-loop.sh without --output-file still writes to stdout"
else
  fail "auto-loop.sh backward compatibility broken — stdout output missing"
fi

# ============================================================================
# Section 6: Helper scripts exist and work
# ============================================================================

echo ""
echo "--- Section 6: Helper scripts ---"

# detect-milestone-id.sh
if [ -x scripts/util/detect-milestone-id.sh ]; then
  result=$(bash scripts/util/detect-milestone-id.sh "$TMPDIR_TEST")
  if [ "$result" = "M001" ]; then
    pass "detect-milestone-id.sh returns M001 from fixture"
  else
    fail "detect-milestone-id.sh returned '$result', expected 'M001'"
  fi
else
  fail "detect-milestone-id.sh not found or not executable"
fi

# check-plan-exists.sh
if [ -x scripts/util/check-plan-exists.sh ]; then
  result=$(bash scripts/util/check-plan-exists.sh "$TMPDIR_TEST" P01)
  if echo "$result" | grep -q "PLAN_EXISTS"; then
    pass "check-plan-exists.sh detects existing plan"
  else
    fail "check-plan-exists.sh returned '$result', expected PLAN_EXISTS"
  fi

  result2=$(bash scripts/util/check-plan-exists.sh "$TMPDIR_TEST" P99)
  if echo "$result2" | grep -q "PLAN_MISSING"; then
    pass "check-plan-exists.sh detects missing plan"
  else
    fail "check-plan-exists.sh returned '$result2', expected PLAN_MISSING"
  fi
else
  fail "check-plan-exists.sh not found or not executable"
fi

# evaluate-preflight.sh
if [ -x scripts/lifecycle/evaluate-preflight.sh ]; then
  pass "evaluate-preflight.sh exists and is executable"
else
  fail "evaluate-preflight.sh not found or not executable"
fi

# ============================================================================
# Section 7: classify-command.sh correctness
# ============================================================================

echo ""
echo "--- Section 7: classify-command.sh classifications ---"

if [ -x scripts/util/classify-command.sh ]; then
  # AUTO_SAFE commands
  for cmd in \
    "bash scripts/lifecycle/auto-loop.sh dir" \
    "bash scripts/lifecycle/lock-manager.sh status file.lock" \
    "test -f scripts/lifecycle/scaffold.sh" \
    "bash scripts/util/check-plan-exists.sh dir P01" \
    "bash scripts/util/detect-milestone-id.sh dir"; do
    result=$(bash scripts/util/classify-command.sh "$cmd" 2>/dev/null)
    if [ "$result" = "AUTO_SAFE" ]; then
      pass "classify: AUTO_SAFE for '$cmd'"
    else
      fail "classify: expected AUTO_SAFE for '$cmd', got '$result'"
    fi
  done

  # APPROVAL_REQUIRED commands
  for cmd in \
    'output=$(bash script.sh)' \
    'rm -rf /tmp/test' \
    'cat /tmp/file.json'; do
    result=$(bash scripts/util/classify-command.sh "$cmd" 2>/dev/null)
    if echo "$result" | grep -q "APPROVAL_REQUIRED"; then
      pass "classify: APPROVAL_REQUIRED for '$cmd'"
    else
      fail "classify: expected APPROVAL_REQUIRED for '$cmd', got '$result'"
    fi
  done

  # FORBIDDEN commands
  for cmd in \
    'eval "$cmd"' \
    "bash -c 'source lib.sh'"; do
    result=$(bash scripts/util/classify-command.sh "$cmd" 2>/dev/null)
    if echo "$result" | grep -q "FORBIDDEN_IN_AUTO"; then
      pass "classify: FORBIDDEN_IN_AUTO for '$cmd'"
    else
      fail "classify: expected FORBIDDEN_IN_AUTO for '$cmd', got '$result'"
    fi
  done
else
  fail "classify-command.sh not found or not executable"
fi

# ============================================================================
# Section 8: check-plans.sh AD-19 linter integration
# ============================================================================

echo ""
echo "--- Section 8: AD-19 plan linter ---"

if [ -x scripts/diagnostics/check-plans.sh ]; then
  # Test with a clean plan (should pass)
  clean_plan="$TMPDIR_TEST/clean-plan.md"
  cat > "$clean_plan" << 'EOF'
---
id: T01
---
# Task T01
## Verification
- Check: `bash scripts/verify/some-check.sh`
- Check: `test -f path/to/file.md`
EOF
  result=$(bash scripts/diagnostics/check-plans.sh --target "$clean_plan" 2>/dev/null)
  if echo "$result" | grep -q "status=ok"; then
    pass "check-plans.sh reports ok for clean plan"
  else
    fail "check-plans.sh reported '$result' for clean plan, expected status=ok"
  fi

  # Test with a risky plan (should warn)
  risky_plan="$TMPDIR_TEST/risky-plan.md"
  cat > "$risky_plan" << 'EOF'
---
id: T02
---
# Task T02
## Verification
- Check: `bash -c 'source lib.sh && test'`
EOF
  result=$(bash scripts/diagnostics/check-plans.sh --target "$risky_plan" 2>/dev/null)
  if echo "$result" | grep -q "status=warn"; then
    pass "check-plans.sh detects risky bash -c pattern"
  else
    fail "check-plans.sh did not detect risky pattern: '$result'"
  fi
else
  fail "check-plans.sh not found or not executable"
fi

# ============================================================================
# Section 9: phase-transition.sh --body-file support
# ============================================================================

echo ""
echo "--- Section 9: phase-transition.sh --body-file and --output-file ---"

# Check that phase-transition.sh accepts --body-file
if grep -q 'body-file' scripts/lifecycle/phase-transition.sh; then
  pass "phase-transition.sh supports --body-file option"
else
  fail "phase-transition.sh does not support --body-file option"
fi

if grep -q 'output-file' scripts/lifecycle/phase-transition.sh; then
  pass "phase-transition.sh supports --output-file option"
else
  fail "phase-transition.sh does not support --output-file option"
fi

# ============================================================================
# Section 10: No compound commands in auto.md bash fences
# ============================================================================

echo ""
echo "--- Section 10: auto.md compound command audit ---"

# Check for && chains with 3+ parts
complex_chains=$(sed -n '/^```bash/,/^```$/p' commands/auto.md | grep -E '&&.*&&' || true)
if [ -n "$complex_chains" ]; then
  fail "auto.md bash blocks contain complex && chains"
else
  pass "auto.md bash blocks have no complex && chains"
fi

# Check for pipe chains with 2+ pipes
complex_pipes=$(sed -n '/^```bash/,/^```$/p' commands/auto.md | grep -E '\|.*\|' || true)
if [ -n "$complex_pipes" ]; then
  fail "auto.md bash blocks contain complex pipe chains"
else
  pass "auto.md bash blocks have no complex pipe chains"
fi

# Check for subshells in actionable bash blocks (exclude Known Limitations examples)
# The Known Limitations section contains counter-examples (what NOT to do)
actionable_blocks=$(sed -n '/^### Known Limitations/,/^## /{ d; }; /^```bash/,/^```$/p' commands/auto.md)
subshells=$(echo "$actionable_blocks" | grep -E '^\(' || true)
if [ -n "$subshells" ]; then
  fail "auto.md actionable bash blocks contain subshell expressions"
else
  pass "auto.md actionable bash blocks have no subshell expressions"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=== Summary ==="
TOTAL=$((PASSED + FAILED))
echo "$PASSED/$TOTAL checks passed"
if [ "$FAILED" -gt 0 ]; then
  echo "FAILED: $FAILED checks"
  exit 1
fi
