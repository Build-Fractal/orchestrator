---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M004"
name: "Routing YAML Fallback Extension"
depends_on: []
---

## Description

Extend the existing `templates/routing.yaml` to add `fallback` comma-separated lists per model tier and restructure the `classification` block into a per-rule format with match patterns and confidence thresholds. The existing content (models, classification, history_weight, budget_ceiling_usd) must be preserved — this is an additive, non-breaking change.

This implements:
- US10 (Model Routing with Fallback Chains): AS1, AS2, AS3, AS4
- FR-213
- Principle X (Templating Over Inference)

## Steps

### Step 1: Read the current routing.yaml

Read `templates/routing.yaml`. The current content is:

```yaml
# .specify/orchestrator/routing.yaml — Model routing configuration
# Controls which model handles each task complexity tier.
# Optional: if this file does not exist, all tasks use the same model.

models:
  heavy:
    id: "claude-opus-4-6"
    context_budget: 200000
  standard:
    id: "claude-sonnet-4-6"
    context_budget: 150000
  light:
    id: "claude-haiku-4-5"
    context_budget: 80000

classification:
  heavy: "new subsystem, >5 files, architectural decision, first phase"
  standard: "feature implementation, 2-5 files, follows established pattern"
  light: "config change, test addition, single-file edit, documentation"

history_weight: 0.3
budget_ceiling_usd: 50.00
```

### Step 2: Add fallback fields to each model tier

Add a `fallback` field to each model under `models:`. The fallback value is a comma-separated string (not a YAML flow sequence) listing model IDs to try in order when the primary fails with a recoverable error (rate_limit, timeout).

The fallback chain for each tier:
- heavy: falls back to standard, then light
- standard: falls back to light
- light: no fallback (end of chain)

### Step 3: Add structured classification rules

Replace the simple string-value classification with a structured block. Each rule has a `patterns` field (comma-separated match terms) and a `confidence` threshold.

### Step 4: Add fallback configuration

Add a `fallback_config:` block that declares which error types are recoverable (triggering fallback) and the maximum number of retries.

### Step 5: Write the updated `templates/routing.yaml`

Replace the content of `templates/routing.yaml` with:

```yaml
# templates/routing.yaml — Model routing configuration
# Controls which model handles each task complexity tier.
# Optional: if this file does not exist, all tasks use the same model.
#
# Schema: max 2 levels of nesting. Parseable by grep/sed/awk (no jq required).
# Fallback: when primary model fails with recoverable error, engine retries
# with next model in the fallback chain (US10).
#
# Constitution: Principle X (Templating Over Inference).

models:
  heavy:
    id: "claude-opus-4-6"
    context_budget: 200000
    fallback: "claude-sonnet-4-6,claude-haiku-4-5"
  standard:
    id: "claude-sonnet-4-6"
    context_budget: 150000
    fallback: "claude-haiku-4-5"
  light:
    id: "claude-haiku-4-5"
    context_budget: 80000
    fallback: ""

classification:
  heavy:
    patterns: "new subsystem,>5 files,architectural decision,first phase"
    confidence: 0.8
  standard:
    patterns: "feature implementation,2-5 files,follows established pattern"
    confidence: 0.6
  light:
    patterns: "config change,test addition,single-file edit,documentation"
    confidence: 0.4

fallback_config:
  recoverable_errors: "rate_limit,timeout,overloaded"
  max_retries: 2
  retry_delay_seconds: 5

history_weight: 0.3
budget_ceiling_usd: 50.00
```

### Step 6: Verify

Run the following verification commands:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Fallback fields exist for all 3 tiers
fallbacks=$(grep -c 'fallback:' templates/routing.yaml)
test "$fallbacks" -ge 3 && echo "PASS: $fallbacks fallback fields" || echo "FAIL: only $fallbacks fallback fields"

# Each tier has id and context_budget preserved
for tier in heavy standard light; do
  grep -A3 "  $tier:" templates/routing.yaml | grep -q 'id:' && echo "PASS: $tier has id" || echo "FAIL: $tier missing id"
  grep -A3 "  $tier:" templates/routing.yaml | grep -q 'context_budget:' && echo "PASS: $tier has context_budget" || echo "FAIL: $tier missing context_budget"
done

# Classification has patterns and confidence
grep -q 'patterns:' templates/routing.yaml && echo "PASS: patterns field" || echo "FAIL: no patterns"
grep -q 'confidence:' templates/routing.yaml && echo "PASS: confidence field" || echo "FAIL: no confidence"

# Fallback config block
grep -q '^fallback_config:' templates/routing.yaml && echo "PASS: fallback_config block" || echo "FAIL: no fallback_config"
grep -q 'recoverable_errors:' templates/routing.yaml && echo "PASS: recoverable_errors" || echo "FAIL: no recoverable_errors"

# Preserved fields
grep -q 'history_weight:' templates/routing.yaml && echo "PASS: history_weight preserved" || echo "FAIL: history_weight missing"
grep -q 'budget_ceiling_usd:' templates/routing.yaml && echo "PASS: budget_ceiling_usd preserved" || echo "FAIL: budget_ceiling_usd missing"

# No YAML flow sequences
brackets=$(grep -cE '^\s+\w+:.*\[' templates/routing.yaml)
test "$brackets" -eq 0 && echo "PASS: no flow sequences" || echo "FAIL: $brackets flow sequences"
```

## Must-Haves

### Truths

- routing.yaml has fallback field for each of the 3 model tiers
  - Check: `test "$(grep -c 'fallback:' templates/routing.yaml)" -ge 3`
- Heavy tier fallback chain includes standard and light models
  - Check: `grep -A4 '  heavy:' templates/routing.yaml | grep 'fallback:' | grep -q 'claude-sonnet-4-6'`
- Classification rules have patterns and confidence fields
  - Check: `grep -q 'patterns:' templates/routing.yaml && grep -q 'confidence:' templates/routing.yaml`
- Fallback config declares recoverable error types
  - Check: `grep -q 'recoverable_errors:' templates/routing.yaml`
- Existing fields preserved (history_weight, budget_ceiling_usd, model ids)
  - Check: `grep -q 'history_weight: 0.3' templates/routing.yaml && grep -q 'budget_ceiling_usd: 50.00' templates/routing.yaml`
- No YAML flow sequences (comma-separated strings instead)
  - Check: `test "$(grep -cE '^\s+\w+:.*\[' templates/routing.yaml)" -eq 0`

### Artifacts

- `templates/routing.yaml` (min 30 lines, contains "fallback:")

### Key Links

- `templates/routing.yaml` → `scripts/dispatch/select-model.sh` (future: model selection reads fallback chains)
- `templates/routing.yaml` → `scripts/dispatch/compress-payload.sh` (future: token budget derived from context_budget)
- `templates/routing.yaml` → `.specify/memory/constitution.md` (implements Principle X)

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T03 Verification ==="

# File exists and has minimum lines
test -f templates/routing.yaml && echo "PASS: file exists" || echo "FAIL: file missing"
lines=$(wc -l < templates/routing.yaml | tr -d ' ')
test "$lines" -ge 30 && echo "PASS: $lines lines (min 30)" || echo "FAIL: only $lines lines"

# 3+ fallback fields
fallbacks=$(grep -c 'fallback:' templates/routing.yaml)
test "$fallbacks" -ge 3 && echo "PASS: $fallbacks fallback fields (min 3)" || echo "FAIL: only $fallbacks"

# Heavy fallback chain
grep -A4 '  heavy:' templates/routing.yaml | grep 'fallback:' | grep -q 'claude-sonnet-4-6' && echo "PASS: heavy fallback" || echo "FAIL: heavy fallback"

# Classification structured
grep -q 'patterns:' templates/routing.yaml && echo "PASS: patterns" || echo "FAIL: no patterns"
grep -q 'confidence:' templates/routing.yaml && echo "PASS: confidence" || echo "FAIL: no confidence"

# Fallback config
grep -q 'recoverable_errors:' templates/routing.yaml && echo "PASS: recoverable_errors" || echo "FAIL: no recoverable_errors"
grep -q 'max_retries:' templates/routing.yaml && echo "PASS: max_retries" || echo "FAIL: no max_retries"

# Preserved values
grep -q 'history_weight: 0.3' templates/routing.yaml && echo "PASS: history_weight preserved" || echo "FAIL: history_weight changed"
grep -q 'budget_ceiling_usd: 50.00' templates/routing.yaml && echo "PASS: budget_ceiling_usd preserved" || echo "FAIL: budget_ceiling_usd changed"

# No flow sequences
brackets=$(grep -cE '^\s+\w+:.*\[' templates/routing.yaml)
test "$brackets" -eq 0 && echo "PASS: no flow sequences" || echo "FAIL: $brackets flow sequences"
```

## Inputs

### From Previous Tasks

None — T03 has no upstream task dependencies within P04.

### From Disk (Pre-existing)

- `templates/routing.yaml` — Current content with models (heavy/standard/light), classification (string values), history_weight, budget_ceiling_usd. This task modifies this file in place.
- `specs/004-engine-architecture/spec.md` — US10 (AS1-AS4), FR-213. Full requirements for fallback chains.
- `scripts/dispatch/select-model.sh` — Current model selection logic. Understanding how classification is used clarifies the structured rules format.
- `scripts/dispatch/classify-complexity.sh` — Current complexity classification. The structured classification rules must support the same tier assignment patterns.
- `.specify/memory/constitution.md` — Principle X (Templating Over Inference): routing policy declared in config, not inferred by scripts.

## Expected Output

The file `templates/routing.yaml` updated with:
- Each model tier has `fallback` field with comma-separated model ID chain
- Heavy: fallback to standard then light; standard: fallback to light; light: empty fallback
- Classification restructured with `patterns` (comma-separated) and `confidence` per tier
- New `fallback_config:` block with recoverable_errors, max_retries, retry_delay_seconds
- All existing fields preserved (history_weight: 0.3, budget_ceiling_usd: 50.00, model ids and context_budgets)
- No YAML flow sequences, max 2 levels nesting
