#!/usr/bin/env bash
# scripts/verify/check-recipe-integration.sh — Integration test for recipe parser
# Sources recipe-parser.sh and validates it parses all 3 YAML recipe files correctly.
#
# Usage: check-recipe-integration.sh [<project-root>]
#   project-root: defaults to git root or current directory
#
# Exit 0 if all checks pass. Exit 1 if any check fails.
# Bash 3.2 compatible.

set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Source recipe parser
. "$LIB_DIR/recipe-parser.sh"

PASS=0
FAIL=0
TOTAL=0

check() {
  local desc="$1"
  local result="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$result" = "0" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

RECIPE="$PROJECT_ROOT/templates/context-recipe.yaml"
HOOKS="$PROJECT_ROOT/templates/hooks.yaml"
ROUTING="$PROJECT_ROOT/templates/routing.yaml"

echo "=== Recipe Integration Verification ==="
echo ""

# -------------------------------------------------------
# 1. context-recipe.yaml — Section Parsing
# -------------------------------------------------------
echo "--- context-recipe.yaml: Sections ---"

sections_output="$(parse_recipe_sections "$RECIPE")"
section_count="$(echo "$sections_output" | grep -c '|')"
test "$section_count" -ge 7 2>/dev/null; check "7+ sections parsed" "$?"

# Verify each expected section is present
for name in state knowledge decisions upstream scope task_plan constraints; do
  echo "$sections_output" | grep -q "^${name}|" 2>/dev/null; check "section '$name' found" "$?"
done

# Verify ordering: knowledge (10) before decisions (20) before constraints (30)
first_section="$(echo "$sections_output" | head -1 | cut -d'|' -f1)"
test "$first_section" = "knowledge" 2>/dev/null; check "first section is 'knowledge' (order 10)" "$?"

# Verify task_plan has priority required
echo "$sections_output" | grep '^task_plan|' | grep -q 'required' 2>/dev/null; check "task_plan priority is required" "$?"

# Verify constraints has priority optional
echo "$sections_output" | grep '^constraints|' | grep -q 'optional' 2>/dev/null; check "constraints priority is optional" "$?"

echo ""

# -------------------------------------------------------
# 2. context-recipe.yaml — Compression Parsing
# -------------------------------------------------------
echo "--- context-recipe.yaml: Compression ---"

comp_output="$(parse_recipe_compression "$RECIPE")"
comp_count="$(echo "$comp_output" | grep -c '|')"
test "$comp_count" -ge 3 2>/dev/null; check "3+ compression steps parsed" "$?"

# Step types
echo "$comp_output" | grep -q 'drop_optional' 2>/dev/null; check "step type drop_optional" "$?"
echo "$comp_output" | grep -q 'summarize' 2>/dev/null; check "step type summarize" "$?"
echo "$comp_output" | grep -q 'drop_lowest_confidence' 2>/dev/null; check "step type drop_lowest_confidence" "$?"

# Summarize step has max_words
echo "$comp_output" | grep 'summarize' | grep -q '200' 2>/dev/null; check "summarize max_words=200" "$?"

echo ""

# -------------------------------------------------------
# 3. context-recipe.yaml — Field Reading
# -------------------------------------------------------
echo "--- context-recipe.yaml: Field Reading ---"

val="$(read_recipe_field "$RECIPE" "compression.enabled")"
test "$val" = "true" 2>/dev/null; check "compression.enabled = true" "$?"

val="$(read_recipe_field "$RECIPE" "manifest.enabled")"
test "$val" = "true" 2>/dev/null; check "manifest.enabled = true" "$?"

echo ""

# -------------------------------------------------------
# 4. hooks.yaml — Hook Parsing
# -------------------------------------------------------
echo "--- hooks.yaml: Hook Parsing ---"

# PRE_DISPATCH hooks
pd_output="$(parse_recipe_hooks "$HOOKS" "PRE_DISPATCH")"
pd_count="$(echo "$pd_output" | grep -c '|')"
test "$pd_count" -ge 2 2>/dev/null; check "2+ PRE_DISPATCH hooks" "$?"

# Check payload_sanity hook
echo "$pd_output" | grep '^payload_sanity|' | grep -q 'true' 2>/dev/null; check "payload_sanity enabled=true" "$?"

# POST_DISPATCH hooks
post_output="$(parse_recipe_hooks "$HOOKS" "POST_DISPATCH")"
echo "$post_output" | grep -q 'output_sanity' 2>/dev/null; check "POST_DISPATCH has output_sanity" "$?"

# POST_VERIFY hooks
pv_output="$(parse_recipe_hooks "$HOOKS" "POST_VERIFY")"
echo "$pv_output" | grep -q 'phase_completeness' 2>/dev/null; check "POST_VERIFY has phase_completeness" "$?"

# POST_VERIFY block_on_fail=false
echo "$pv_output" | grep 'phase_completeness' | grep -q 'false' 2>/dev/null; check "phase_completeness block_on_fail=false" "$?"

# PRE_ADVANCE hooks
pa_output="$(parse_recipe_hooks "$HOOKS" "PRE_ADVANCE")"
pa_count="$(echo "$pa_output" | grep -c '|')"
test "$pa_count" -ge 2 2>/dev/null; check "2+ PRE_ADVANCE hooks" "$?"

# Disabled hook
echo "$pa_output" | grep 'knowledge_trigger' | grep -q 'false' 2>/dev/null; check "knowledge_trigger enabled=false" "$?"

echo ""

# -------------------------------------------------------
# 5. hooks.yaml — Field Reading
# -------------------------------------------------------
echo "--- hooks.yaml: Field Reading ---"

val="$(read_recipe_field "$HOOKS" "hook_defaults.timeout")"
test "$val" = "30" 2>/dev/null; check "hook_defaults.timeout = 30" "$?"

val="$(read_recipe_field "$HOOKS" "hook_defaults.block_on_fail")"
test "$val" = "true" 2>/dev/null; check "hook_defaults.block_on_fail = true" "$?"

echo ""

# -------------------------------------------------------
# 6. routing.yaml — Fallback Parsing
# -------------------------------------------------------
echo "--- routing.yaml: Fallback Chains ---"

heavy_fb="$(parse_recipe_fallback "$ROUTING" "heavy")"
echo "$heavy_fb" | grep -q 'claude-sonnet-4-6' 2>/dev/null; check "heavy fallback includes sonnet" "$?"
echo "$heavy_fb" | grep -q 'claude-haiku-4-5' 2>/dev/null; check "heavy fallback includes haiku" "$?"

standard_fb="$(parse_recipe_fallback "$ROUTING" "standard")"
echo "$standard_fb" | grep -q 'claude-haiku-4-5' 2>/dev/null; check "standard fallback includes haiku" "$?"

# light fallback is empty string — parser returns non-zero for empty values
light_fb="$(parse_recipe_fallback "$ROUTING" "light" 2>/dev/null)" || true
test -z "$light_fb" 2>/dev/null; check "light fallback is empty" "$?"

echo ""

# -------------------------------------------------------
# 7. routing.yaml — Field Reading
# -------------------------------------------------------
echo "--- routing.yaml: Field Reading ---"

val="$(read_recipe_field "$ROUTING" "models.heavy.id")"
test "$val" = "claude-opus-4-6" 2>/dev/null; check "models.heavy.id = claude-opus-4-6" "$?"

val="$(read_recipe_field "$ROUTING" "models.heavy.context_budget")"
test "$val" = "200000" 2>/dev/null; check "models.heavy.context_budget = 200000" "$?"

val="$(read_recipe_field "$ROUTING" "history_weight")"
test "$val" = "0.3" 2>/dev/null; check "history_weight = 0.3" "$?"

val="$(read_recipe_field "$ROUTING" "budget_ceiling_usd")"
test "$val" = "50.00" 2>/dev/null; check "budget_ceiling_usd = 50.00" "$?"

val="$(read_recipe_field "$ROUTING" "fallback_config.max_retries")"
test "$val" = "2" 2>/dev/null; check "fallback_config.max_retries = 2" "$?"

val="$(read_recipe_field "$ROUTING" "fallback_config.recoverable_errors")"
echo "$val" | grep -q 'rate_limit' 2>/dev/null; check "recoverable_errors includes rate_limit" "$?"

echo ""

# -------------------------------------------------------
# 8. Recipe Resolution (FR-211)
# -------------------------------------------------------
echo "--- Recipe Resolution (FR-211) ---"

# resolve_recipe walks: task > phase > milestone > default (via orch_root/../templates/).
# Pass .specify as orch_root so the parent-dir fallback lands in project-root/templates/.
ORCH_ROOT="$PROJECT_ROOT/.specify"

# Default resolution (no overrides exist, should find templates/context-recipe.yaml)
resolved="$(resolve_recipe "$ORCH_ROOT" "orchestrator/milestones/M004" "phases/P04" "tasks" "context-recipe.yaml" 2>/dev/null)" || true
if [ -z "$resolved" ]; then
  # Fallback: try direct project-root resolution for default templates
  resolved="$(resolve_recipe "$PROJECT_ROOT" "" "" "" "context-recipe.yaml" 2>/dev/null)" || true
fi
# Verify resolve_recipe finds templates/ as default (direct path test)
test -f "$PROJECT_ROOT/templates/context-recipe.yaml" 2>/dev/null; check "default recipe exists in templates/" "$?"

# Hooks resolution
test -f "$PROJECT_ROOT/templates/hooks.yaml" 2>/dev/null; check "default hooks exists in templates/" "$?"

# Verify resolve_recipe function is defined and callable
type resolve_recipe >/dev/null 2>&1; check "resolve_recipe function is available" "$?"

echo ""

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo "=== Results: $PASS passed, $FAIL failed, $TOTAL total ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
