---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M004"
name: "Integration Verification"
depends_on: [T04]
---

## Description

Write and execute a verification script (`scripts/verify/check-recipe-integration.sh`) that sources `recipe-parser.sh` and validates it can correctly parse all three YAML files: `templates/context-recipe.yaml`, `templates/hooks.yaml`, and `templates/routing.yaml`. This confirms end-to-end correctness of the YAML schema design and parser implementation, Bash 3.2 compatibility, and grep/sed/awk-only parsing.

This validates:
- US2 AS1 (recipe sections parseable)
- US3 AS1 (compression config parseable)
- US5 AS1 (hook config parseable)
- US10 AS1 (fallback chains parseable)
- FR-211 (recipe resolution)
- NFR-200, NFR-202, NFR-203

## Steps

### Step 1: Create verification directory

```bash
mkdir -p scripts/verify
```

### Step 2: Create `scripts/verify/check-recipe-integration.sh`

Write the following content to `scripts/verify/check-recipe-integration.sh`:

```bash
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

# Verify a source path contains placeholders
echo "$sections_output" | grep '^upstream|' | grep -q '{milestone}' 2>/dev/null; check "upstream source has {milestone} placeholder" "$?"

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

light_fb="$(parse_recipe_fallback "$ROUTING" "light")"
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

# Default resolution (no overrides exist, should find templates/context-recipe.yaml)
resolved="$(resolve_recipe "$PROJECT_ROOT/.specify/orchestrator" "M004" "P04" "T01" "context-recipe.yaml")"
echo "$resolved" | grep -q 'templates/context-recipe.yaml' 2>/dev/null; check "default recipe resolves to templates/" "$?"

# Hooks resolution
resolved="$(resolve_recipe "$PROJECT_ROOT/.specify/orchestrator" "M004" "P04" "T01" "hooks.yaml")"
echo "$resolved" | grep -q 'templates/hooks.yaml' 2>/dev/null; check "default hooks resolves to templates/" "$?"

echo ""

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo "=== Results: $PASS passed, $FAIL failed, $TOTAL total ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 3: Make executable

```bash
chmod +x scripts/verify/check-recipe-integration.sh
```

### Step 4: Run the verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
bash scripts/verify/check-recipe-integration.sh
```

Expected output: all checks pass, `Results: N passed, 0 failed, N total`.

### Step 5: Run Bash 3.2 compatibility checks

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Verify no Bash 4+ features in any new file
for f in scripts/lib/recipe-parser.sh scripts/verify/check-recipe-integration.sh; do
  echo "--- $f ---"
  ! grep -qE 'declare -A|readarray|mapfile' "$f" && echo "PASS: no Bash 4+ features" || echo "FAIL: Bash 4+ feature found"
  ! grep -q 'jq ' "$f" && echo "PASS: no jq" || echo "FAIL: jq found"
done
```

### Step 6: Verify double-sourcing guard works

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Source twice — should not error
bash -c '. scripts/lib/recipe-parser.sh; . scripts/lib/recipe-parser.sh; echo "PASS: double-source safe"'
```

## Must-Haves

### Truths

- check-recipe-integration.sh passes all checks (0 failures)
  - Check: `bash scripts/verify/check-recipe-integration.sh && echo PASS || echo FAIL`
- parse_recipe_sections parses 7 sections from context-recipe.yaml
  - Check: `source scripts/lib/recipe-parser.sh && test "$(parse_recipe_sections templates/context-recipe.yaml | wc -l | tr -d ' ')" -ge 7`
- parse_recipe_compression parses 3 steps from context-recipe.yaml
  - Check: `source scripts/lib/recipe-parser.sh && test "$(parse_recipe_compression templates/context-recipe.yaml | wc -l | tr -d ' ')" -ge 3`
- parse_recipe_hooks lists hooks for all 4 lifecycle points
  - Check: `source scripts/lib/recipe-parser.sh && for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do parse_recipe_hooks templates/hooks.yaml "$p" | grep -q '|' || exit 1; done && echo PASS`
- parse_recipe_fallback reads heavy tier fallback chain containing sonnet
  - Check: `source scripts/lib/recipe-parser.sh && parse_recipe_fallback templates/routing.yaml heavy | grep -q 'claude-sonnet-4-6'`
- read_recipe_field reads 3-level nested value (models.heavy.id)
  - Check: `source scripts/lib/recipe-parser.sh && test "$(read_recipe_field templates/routing.yaml models.heavy.id)" = "claude-opus-4-6"`
- Double-sourcing is safe (no error on second source)
  - Check: `bash -c '. scripts/lib/recipe-parser.sh; . scripts/lib/recipe-parser.sh; echo PASS'`

### Artifacts

- `scripts/verify/check-recipe-integration.sh` (min 80 lines, contains "Integration Verification")

### Key Links

- `scripts/verify/check-recipe-integration.sh` → `scripts/lib/recipe-parser.sh` (sources and tests)
- `scripts/verify/check-recipe-integration.sh` → `templates/context-recipe.yaml` (parses and validates)
- `scripts/verify/check-recipe-integration.sh` → `templates/hooks.yaml` (parses and validates)
- `scripts/verify/check-recipe-integration.sh` → `templates/routing.yaml` (parses and validates)

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T05 Verification ==="

# File exists and has minimum lines
test -f scripts/verify/check-recipe-integration.sh && echo "PASS: file exists" || echo "FAIL: file missing"
lines=$(wc -l < scripts/verify/check-recipe-integration.sh | tr -d ' ')
test "$lines" -ge 80 && echo "PASS: $lines lines (min 80)" || echo "FAIL: only $lines lines"

# Executable
test -x scripts/verify/check-recipe-integration.sh && echo "PASS: executable" || echo "FAIL: not executable"

# Integration test passes
bash scripts/verify/check-recipe-integration.sh && echo "PASS: all integration checks" || echo "FAIL: integration checks failed"

# Double-source safety
bash -c '. scripts/lib/recipe-parser.sh; . scripts/lib/recipe-parser.sh; echo "PASS: double-source"' || echo "FAIL: double-source"

# Bash 3.2 compat on verification script
! grep -qE 'declare -A|readarray|mapfile' scripts/verify/check-recipe-integration.sh && echo "PASS: Bash 3.2 compat" || echo "FAIL: Bash 4+ in verification"
```

## Inputs

### From Previous Tasks

- `scripts/lib/recipe-parser.sh` (from T04)
  - Key API: `read_recipe_field <file> <dotted.path>`, `parse_recipe_sections <file>`, `parse_recipe_compression <file>`, `parse_recipe_hooks <file> <lifecycle_point>`, `parse_recipe_fallback <file> <tier>`, `resolve_recipe <orch_root> <milestone> <phase> <task> <filename>`
  - Key types: Output is pipe-delimited strings (one line per item). Fallback is comma-separated string.
  - Behavioral contract: Functions return 0 on success, 1 on not-found/error. parse_recipe_sections output is sorted by order. All functions use grep/sed/awk only.

- `templates/context-recipe.yaml` (from T01)
  - Key API: 7 sections with source/priority/order/filter/cache_hint. compression block with 3 steps. manifest block.
  - Behavioral contract: Parseable by recipe-parser.sh. Max 2 levels nesting.

- `templates/hooks.yaml` (from T02)
  - Key API: 4 lifecycle points with hook entries (name/script/enabled/block_on_fail/description). hook_defaults block.
  - Behavioral contract: Parseable by recipe-parser.sh. Max 2 levels nesting.

- `templates/routing.yaml` (from T03)
  - Key API: 3 model tiers with id/context_budget/fallback. classification with patterns/confidence. fallback_config with recoverable_errors/max_retries.
  - Behavioral contract: Parseable by recipe-parser.sh. Fallback is comma-separated string.

### From Disk (Pre-existing)

- `scripts/verify/` — Existing verification scripts directory. The new check-recipe-integration.sh follows the same pattern.
- `specs/004-engine-architecture/spec.md` — NFR-200, NFR-202, NFR-203, FR-211. Compliance requirements for the verification checks.

## Expected Output

The file `scripts/verify/check-recipe-integration.sh` containing:
- Comprehensive integration tests covering all 3 YAML files and all parser functions
- Section parsing validation (7 sections, correct ordering, priority values)
- Compression parsing validation (3 steps, correct types and parameters)
- Hook parsing validation (4 lifecycle points, enabled/disabled states, block_on_fail)
- Routing/fallback validation (3 tiers, fallback chains, field reading)
- Recipe resolution validation (FR-211 specificity)
- Pass/fail summary with exit code
- All tests passing with 0 failures
