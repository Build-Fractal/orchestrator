#!/usr/bin/env bash
# tests/test-s01-structure.sh — Validates all S01 structural invariants
# Outputs structured PASS/FAIL lines per check. Exits 0 if all pass, 1 if any fail.
# Dependencies: bash only (python3 optional for YAML validation)

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
# 2. extension.yml YAML validation (python3 optional)
# --------------------------------------------------------------------------
if [ ! -f "extension.yml" ]; then
  fail "extension.yml file missing"
else
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import yaml; yaml.safe_load(open('extension.yml'))" 2>/dev/null; then
      pass "extension.yml parses as valid YAML"
    else
      fail "extension.yml YAML parse error"
    fi
  else
    # Fallback: just check it's non-empty
    if [ -s "extension.yml" ]; then
      pass "extension.yml exists and is non-empty (python3 not available for YAML validation)"
    else
      fail "extension.yml is empty"
    fi
  fi
fi

# --------------------------------------------------------------------------
# 3. Command count = 10
# --------------------------------------------------------------------------
CMD_COUNT=$(grep -c '^\s*- name: speckit\.orchestrator\.' extension.yml 2>/dev/null || echo 0)
if [ "$CMD_COUNT" -eq 10 ]; then
  pass "extension.yml has 10 commands"
else
  fail "extension.yml command count is $CMD_COUNT, expected 10"
fi

# --------------------------------------------------------------------------
# 4. All 10 command descriptions use "Use when..." phrasing
# --------------------------------------------------------------------------
# Count description lines under provides.commands that start with "Use when"
USE_WHEN_COUNT=$(grep -c 'description: "Use when' extension.yml 2>/dev/null || echo 0)
if [ "$USE_WHEN_COUNT" -eq 10 ]; then
  pass "all 10 command descriptions use 'Use when...' phrasing"
else
  fail "only $USE_WHEN_COUNT of 10 command descriptions use 'Use when...' phrasing"
fi

# --------------------------------------------------------------------------
# 5. Hook count = 5 (before_tasks, after_tasks, before_implement, after_implement, before_commit)
# --------------------------------------------------------------------------
EXPECTED_HOOKS=("before_tasks" "after_tasks" "before_implement" "after_implement" "before_commit")
HOOK_FOUND=0
HOOK_MISSING=""
for hook in "${EXPECTED_HOOKS[@]}"; do
  if grep -q "^  ${hook}:" extension.yml 2>/dev/null; then
    HOOK_FOUND=$((HOOK_FOUND + 1))
  else
    HOOK_MISSING="${HOOK_MISSING} ${hook}"
  fi
done

if [ "$HOOK_FOUND" -eq 5 ]; then
  pass "extension.yml has 5 hooks"
else
  fail "extension.yml has $HOOK_FOUND hooks, expected 5 — missing:${HOOK_MISSING}"
fi

# --------------------------------------------------------------------------
# 6. config_schema.properties has 7 entries
# --------------------------------------------------------------------------
# Count property keys under config_schema.properties by looking for lines with
# exactly 4 spaces of indent followed by a key name and colon (YAML dict entries
# under properties).
# We extract the properties block and count entries.
SCHEMA_PROP_COUNT=$(awk '
  /^config_schema:/ { in_schema=1; next }
  in_schema && /^  properties:/ { in_props=1; next }
  in_props && /^    [a-z]/ { count++ }
  in_props && /^[^ ]/ { exit }
  in_props && /^  [a-z]/ { exit }
  END { print count+0 }
' extension.yml)

if [ "$SCHEMA_PROP_COUNT" -eq 7 ]; then
  pass "config_schema.properties has 7 entries"
else
  fail "config_schema.properties has $SCHEMA_PROP_COUNT entries, expected 7"
fi

# --------------------------------------------------------------------------
# 7. provides.scripts count = 23
# --------------------------------------------------------------------------
SCRIPT_COUNT=$(grep -c '^\s*- file: scripts/' extension.yml 2>/dev/null || echo 0)
if [ "$SCRIPT_COUNT" -eq 27 ]; then
  pass "provides.scripts has 27 entries"
else
  fail "provides.scripts has $SCRIPT_COUNT entries, expected 27"
fi

# --------------------------------------------------------------------------
# 8. requires.commands count = 6
# --------------------------------------------------------------------------
REQ_CMD_COUNT=$(grep -c '^\s*- speckit\.' extension.yml 2>/dev/null || echo 0)
if [ "$REQ_CMD_COUNT" -eq 6 ]; then
  pass "requires.commands has 6 entries"
else
  fail "requires.commands has $REQ_CMD_COUNT entries, expected 6"
fi

# --------------------------------------------------------------------------
# 9. Config template exists and has all 7 config keys
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
# 10. defaults section has 7 keys
# --------------------------------------------------------------------------
DEFAULTS_COUNT=$(awk '
  /^defaults:/ { in_defaults=1; next }
  in_defaults && /^  [a-z]/ { count++ }
  in_defaults && /^[^ ]/ { exit }
  END { print count+0 }
' extension.yml)

if [ "$DEFAULTS_COUNT" -eq 7 ]; then
  pass "defaults section has 7 keys"
else
  fail "defaults section has $DEFAULTS_COUNT keys, expected 7"
fi

# --------------------------------------------------------------------------
# 11. provides.config references the template
# --------------------------------------------------------------------------
if grep -q 'template: templates/orchestrator-config-default.yml' extension.yml 2>/dev/null; then
  pass "provides.config references templates/orchestrator-config-default.yml"
else
  fail "provides.config does not reference templates/orchestrator-config-default.yml"
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
