#!/usr/bin/env bash
# tests/test-s01-structure.sh — Validates S01 structural invariants
# Outputs structured PASS/FAIL lines per check. Exits 0 if all pass, 1 if any fail.
# Dependencies: bash only

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

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
# 1. Directory checks (10 directories)
# --------------------------------------------------------------------------
REQUIRED_DIRS=(
  "scripts/state"
  "scripts/dispatch"
  "scripts/verify"
  "scripts/knowledge"
  "scripts/lifecycle"
  "templates"
  "references"
  "docs"
  "tests"
  "tests/fixtures"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    pass "$dir/ directory exists"
  else
    fail "$dir/ directory missing"
  fi
done

# --------------------------------------------------------------------------
# 2. Config template exists and has all 7 config keys
# --------------------------------------------------------------------------
CONFIG_TEMPLATE="templates/orchestrator-config-default.yml"
if [ ! -f "$CONFIG_TEMPLATE" ]; then
  fail "config template $CONFIG_TEMPLATE missing"
else
  CONFIG_KEYS=("default_tier" "verification_commands" "context_verbosity" "git_isolation" "dispatch_budget" "duration_budget" "budget_enforcement")
  CONFIG_KEY_FOUND=0
  CONFIG_KEY_MISSING=""
  for key in "${CONFIG_KEYS[@]}"; do
    if grep -q "^${key}:" "$CONFIG_TEMPLATE" 2>/dev/null; then
      CONFIG_KEY_FOUND=$((CONFIG_KEY_FOUND + 1))
    else
      CONFIG_KEY_MISSING="${CONFIG_KEY_MISSING} ${key}"
    fi
  done

  if [ "$CONFIG_KEY_FOUND" -eq 7 ]; then
    pass "config template has all 7 config keys"
  else
    fail "config template has $CONFIG_KEY_FOUND of 7 keys — missing:${CONFIG_KEY_MISSING}"
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
