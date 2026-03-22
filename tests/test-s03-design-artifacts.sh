#!/usr/bin/env bash
# tests/test-s03-design-artifacts.sh — Validates all S03 design artifacts
# Tests: 12 template files exist, 4 reference files exist, frontmatter presence,
#         no hardcoded IDs, reference doc scope coverage, summary frontmatter fields.
# Outputs structured PASS/FAIL lines per check. Exits 0 if all pass, 1 if any fail.
# Dependencies: bash only (no declare -A, bash 3.2 compatible per K001)

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
# 1. Template file existence (13 files)
# --------------------------------------------------------------------------

TEMPLATE_FILES=(
  "templates/roadmap.md"
  "templates/phase-plan.md"
  "templates/task-plan.md"
  "templates/task-summary.md"
  "templates/phase-summary.md"
  "templates/milestone-summary.md"
  "templates/dispatch-prompt.md"
  "templates/verification-report.md"
  "templates/spec-compliance-review.md"
  "templates/recovery-briefing.md"
  "templates/continue-file.md"
  "templates/context-draft.md"
  "templates/claude-code-appendix.md"
)

for tpl in "${TEMPLATE_FILES[@]}"; do
  if [ -f "$PROJECT_ROOT/$tpl" ]; then
    pass "$tpl exists"
  else
    fail "$tpl exists (file not found)"
  fi
done

# --------------------------------------------------------------------------
# 1b. claude-settings.json exists and is valid JSON
# --------------------------------------------------------------------------
SETTINGS_JSON="$PROJECT_ROOT/templates/claude-settings.json"
if [ -f "$SETTINGS_JSON" ]; then
  pass "templates/claude-settings.json exists"
  # Validate it's parseable JSON (basic check: starts with { and ends with })
  first_char=$(head -c 1 "$SETTINGS_JSON")
  if [ "$first_char" = "{" ]; then
    pass "templates/claude-settings.json is valid JSON (starts with {)"
  else
    fail "templates/claude-settings.json is valid JSON (first char: '$first_char')"
  fi
else
  fail "templates/claude-settings.json exists"
  fail "templates/claude-settings.json is valid JSON (file not found)"
fi

# --------------------------------------------------------------------------
# 2. Reference file existence (4 files)
# --------------------------------------------------------------------------

REFERENCE_FILES=(
  "references/state-machine.md"
  "references/verification-ladder.md"
  "references/tier-definitions.md"
  "references/file-formats.md"
)

for ref in "${REFERENCE_FILES[@]}"; do
  if [ -f "$PROJECT_ROOT/$ref" ]; then
    pass "$ref exists"
  else
    fail "$ref exists (file not found)"
  fi
done

# --------------------------------------------------------------------------
# 3. All 13 templates have schema_version in frontmatter (first 10 lines)
# --------------------------------------------------------------------------

for tpl in "${TEMPLATE_FILES[@]}"; do
  if head -10 "$PROJECT_ROOT/$tpl" | grep -q 'schema_version'; then
    pass "$tpl has schema_version in frontmatter"
  else
    fail "$tpl missing schema_version in frontmatter"
  fi
done

# --------------------------------------------------------------------------
# 4. No hardcoded IDs in templates
# --------------------------------------------------------------------------

hardcoded_matches=$(grep -rn 'M[0-9]\{3\}\|P[0-9]\{2\}\|T[0-9]\{2\}' "$PROJECT_ROOT"/templates/*.md 2>/dev/null || true)
if [ -z "$hardcoded_matches" ]; then
  pass "No hardcoded IDs (M###, P##, T##) in templates"
else
  fail "Hardcoded IDs found in templates: $hardcoded_matches"
fi

# --------------------------------------------------------------------------
# 5. state-machine.md mentions all 10 states
# --------------------------------------------------------------------------

STATE_NAMES=(
  "pre-planning"
  "discussing"
  "planning"
  "replanning"
  "executing"
  "verifying"
  "summarizing"
  "validating"
  "completing"
  "complete"
)

for state in "${STATE_NAMES[@]}"; do
  if grep -q "$state" "$PROJECT_ROOT/references/state-machine.md"; then
    pass "references/state-machine.md mentions state: $state"
  else
    fail "references/state-machine.md missing state: $state"
  fi
done

# --------------------------------------------------------------------------
# 6. verification-ladder.md mentions all 4 tiers
# --------------------------------------------------------------------------

VERIFICATION_TIERS=(
  "Tier 1"
  "Tier 2"
  "Tier 3"
  "Tier 4"
)

for tier in "${VERIFICATION_TIERS[@]}"; do
  if grep -q "$tier" "$PROJECT_ROOT/references/verification-ladder.md"; then
    pass "references/verification-ladder.md mentions $tier"
  else
    fail "references/verification-ladder.md missing $tier"
  fi
done

# --------------------------------------------------------------------------
# 7. tier-definitions.md mentions all 3 tiers
# --------------------------------------------------------------------------

DEFINITION_TIERS=(
  "Tier A"
  "Tier B"
  "Tier C"
)

for tier in "${DEFINITION_TIERS[@]}"; do
  if grep -q "$tier" "$PROJECT_ROOT/references/tier-definitions.md"; then
    pass "references/tier-definitions.md mentions $tier"
  else
    fail "references/tier-definitions.md missing $tier"
  fi
done

# --------------------------------------------------------------------------
# 8. Summary templates contain key frontmatter fields
# --------------------------------------------------------------------------

SUMMARY_TEMPLATES=(
  "templates/task-summary.md"
  "templates/phase-summary.md"
  "templates/milestone-summary.md"
)

SUMMARY_FIELDS=(
  "provides"
  "requires"
  "affects"
  "key_files"
  "verification_result"
)

for stpl in "${SUMMARY_TEMPLATES[@]}"; do
  for field in "${SUMMARY_FIELDS[@]}"; do
    if grep -q "$field" "$PROJECT_ROOT/$stpl"; then
      pass "$stpl contains frontmatter field: $field"
    else
      fail "$stpl missing frontmatter field: $field"
    fi
  done
done

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "$PASS_COUNT/$TOTAL checks passed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
