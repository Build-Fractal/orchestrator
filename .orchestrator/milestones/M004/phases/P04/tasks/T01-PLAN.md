---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M004"
name: "Default Context Recipe YAML"
depends_on: []
---

## Description

Create `templates/context-recipe.yaml` — the default context recipe that declares what sections appear in dispatch payloads, their ordering, priority, source configuration, and filter rules. This file also contains the `compression:` block that declares graduated compression steps and the `manifest:` block for payload manifest configuration. The schema is constrained to 2 levels of nesting maximum so it is parseable by grep/sed/awk without jq.

This implements:
- US2 (YAML-Driven Context Assembly): AS1, AS3, AS4, AS5
- US3 (YAML-Driven Compression): AS1, AS2
- FR-210, FR-211, FR-212
- Principles X (Templating Over Inference), XI (Single Source of Truth), XIII (Agent Instruction Schema)

## Steps

### Step 1: Read existing context assembly logic

Read the current `scripts/dispatch/build-context.sh` to understand the existing section ordering and sources. The current hardcoded order is:

1. Project context (knowledge) — STATIC
2. Architectural decisions — STATIC
3. Project-wide knowledge — STATIC
4. Phase Goal & Must-Haves — SEMI-STATIC
5. Upstream Summaries — DYNAMIC
6. Task Plan — DYNAMIC

The recipe must declare these as named sections plus a new `constraints` section (7 total), with source types, priorities, and ordering that replaces the hardcoded logic.

### Step 2: Read existing compression logic

Read `scripts/dispatch/compress-payload.sh` to understand the current hardcoded strategy:

1. Drop sections marked "optional" in manifest
2. Summarize verbose upstream summaries (truncate to 200 words)
3. Drop lowest-confidence knowledge entries
4. NEVER truncate task plan section

The recipe's `compression:` block must declare these as configurable steps.

### Step 3: Create `templates/context-recipe.yaml`

Create the file `templates/context-recipe.yaml` with the exact content below. The schema uses exactly 2 levels of nesting (top-level block > section-level keys). No flow sequences — arrays use comma-separated inline format.

```yaml
# templates/context-recipe.yaml — Default context recipe
# Declares sections for dispatch payload assembly, compression strategy,
# and manifest configuration.
#
# Schema: max 2 levels of nesting. Parseable by grep/sed/awk (no jq required).
# Override: place a context-recipe.yaml in a milestone, phase, or task directory.
# Resolution order: task > phase > milestone > default (FR-211).
#
# Constitution: Principle X (Templating Over Inference), Principle XI (Single
# Source of Truth), Principle XIII (Agent Instruction Schema).

# --- Section Declarations ---
# Each section has: source, priority, order, filter, cache_hint
#   source:     path pattern relative to orchestrator root (supports {milestone}, {phase}, {task} placeholders)
#   priority:   required | compressible | optional
#   order:      integer sort key (lower = earlier in payload, static sections first)
#   filter:     none | scope | staleness | confidence
#   cache_hint: static | semi-static | dynamic (guides prompt caching boundaries)

sections:
  state:
    source: "milestones/{milestone}/phases/{phase}/tasks/{task}-PLAN.md"
    priority: required
    order: 60
    filter: none
    cache_hint: dynamic

  knowledge:
    source: "KNOWLEDGE.md"
    priority: compressible
    order: 10
    filter: scope
    cache_hint: static

  decisions:
    source: "milestones/{milestone}/DECISIONS.md"
    priority: compressible
    order: 20
    filter: staleness
    cache_hint: static

  upstream:
    source: "milestones/{milestone}/phases/{phase}/upstream/*.md"
    priority: compressible
    order: 50
    filter: none
    cache_hint: dynamic

  scope:
    source: "milestones/{milestone}/phases/{phase}/{phase}-PLAN.md"
    priority: required
    order: 40
    filter: none
    cache_hint: semi-static

  task_plan:
    source: "milestones/{milestone}/phases/{phase}/tasks/{task}-PLAN.md"
    priority: required
    order: 60
    filter: none
    cache_hint: dynamic

  constraints:
    source: "memory/constitution.md"
    priority: optional
    order: 30
    filter: none
    cache_hint: static

# --- Compression Configuration ---
# Graduated steps applied in order until payload fits within token budget.
# Token budget is derived from model selection (routing.yaml context_budget).
# Step types: drop_optional, summarize, drop_lowest_confidence
#   drop_optional:         remove sections with priority optional
#   summarize:             truncate matching sections to max_words
#   drop_lowest_confidence: remove knowledge entries below confidence threshold

compression:
  enabled: true
  steps:
    step_1:
      type: drop_optional
      description: "Remove sections marked priority optional"
    step_2:
      type: summarize
      target_sections: "upstream"
      max_words: 200
      description: "Truncate upstream summaries to 200 words each"
    step_3:
      type: drop_lowest_confidence
      target_sections: "knowledge"
      min_confidence: 0.5
      description: "Drop knowledge entries below 0.5 confidence"
  protected_sections: "task_plan,scope,state"

# --- Manifest Configuration ---
# Controls the manifest header prepended to assembled payloads.

manifest:
  enabled: true
  include_token_count: true
  include_section_list: true
  include_compression_applied: true
```

### Step 4: Verify the schema constraints

Run the following verification commands:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# 7 sections declared (2-space indent, alphanumeric name, colon)
count=$(grep -cE '^  [a-z_]+:$' templates/context-recipe.yaml)
test "$count" -ge 7 && echo "PASS: $count sections" || echo "FAIL: only $count sections"

# No 3rd-level nesting (6+ spaces at start of content line)
deep=$(grep -cE '^      [a-z]' templates/context-recipe.yaml)
test "$deep" -eq 0 && echo "PASS: max 2 levels nesting" || echo "FAIL: $deep lines with 3+ level nesting"

# Compression block exists
grep -q '^compression:' templates/context-recipe.yaml && echo "PASS: compression block" || echo "FAIL: no compression block"

# 3 compression steps
steps=$(grep -c 'type:' templates/context-recipe.yaml)
test "$steps" -ge 3 && echo "PASS: $steps compression step types" || echo "FAIL: only $steps step types"

# Priority values exist
for p in required compressible optional; do
  grep -q "priority: $p" templates/context-recipe.yaml && echo "PASS: priority $p" || echo "FAIL: missing priority $p"
done

# Protected sections include task_plan
grep -q 'protected_sections:.*task_plan' templates/context-recipe.yaml && echo "PASS: task_plan protected" || echo "FAIL: task_plan not protected"

# No YAML flow sequences (no [ or ] in values)
brackets=$(grep -cE '^\s+\w+:.*\[' templates/context-recipe.yaml)
test "$brackets" -eq 0 && echo "PASS: no flow sequences" || echo "FAIL: $brackets flow sequences found"
```

## Must-Haves

### Truths

- context-recipe.yaml declares exactly 7 sections (state, knowledge, decisions, upstream, scope, task_plan, constraints)
  - Check: `test "$(grep -cE '^  [a-z_]+:$' templates/context-recipe.yaml)" -ge 7`
- Each section has source, priority, order, filter, and cache_hint fields
  - Check: `grep -c 'source:' templates/context-recipe.yaml | xargs test 7 -le`
- Compression block has 3 graduated steps with type field
  - Check: `grep -q '^compression:' templates/context-recipe.yaml && test "$(grep -c '      type:' templates/context-recipe.yaml)" -ge 3`
- Protected sections include task_plan, scope, and state
  - Check: `grep 'protected_sections:' templates/context-recipe.yaml | grep -q 'task_plan'`
- No 3rd-level nesting (max 2 levels for grep/sed/awk parsing)
  - Check: `test "$(grep -cE '^      [a-z]' templates/context-recipe.yaml)" -eq 0`
- No YAML flow sequences (no bracket syntax)
  - Check: `test "$(grep -cE '^\s+\w+:.*\[' templates/context-recipe.yaml)" -eq 0`

### Artifacts

- `templates/context-recipe.yaml` (min 60 lines, contains "compression:")

### Key Links

- `templates/context-recipe.yaml` → `scripts/dispatch/build-context.sh` (future: recipe replaces hardcoded section ordering)
- `templates/context-recipe.yaml` → `scripts/dispatch/compress-payload.sh` (future: compression block replaces hardcoded strategy)
- `templates/context-recipe.yaml` → `.specify/memory/constitution.md` (implements Principles X, XI, XIII)

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T01 Verification ==="

# File exists and has minimum lines
test -f templates/context-recipe.yaml && echo "PASS: file exists" || echo "FAIL: file missing"
lines=$(wc -l < templates/context-recipe.yaml | tr -d ' ')
test "$lines" -ge 60 && echo "PASS: $lines lines (min 60)" || echo "FAIL: only $lines lines"

# 7 sections
count=$(grep -cE '^  [a-z_]+:$' templates/context-recipe.yaml)
test "$count" -ge 7 && echo "PASS: $count sections (min 7)" || echo "FAIL: only $count sections"

# Compression block
grep -q '^compression:' templates/context-recipe.yaml && echo "PASS: compression block" || echo "FAIL: no compression block"

# 3 step types
steps=$(grep -c '      type:' templates/context-recipe.yaml)
test "$steps" -ge 3 && echo "PASS: $steps compression steps (min 3)" || echo "FAIL: only $steps steps"

# No deep nesting
deep=$(grep -cE '^      [a-z]' templates/context-recipe.yaml)
test "$deep" -eq 0 && echo "PASS: max 2 levels nesting" || echo "FAIL: $deep deep nesting lines"

# Protected sections
grep 'protected_sections:' templates/context-recipe.yaml | grep -q 'task_plan' && echo "PASS: task_plan protected" || echo "FAIL: task_plan not protected"

# Priority types
for p in required compressible optional; do
  grep -q "priority: $p" templates/context-recipe.yaml && echo "PASS: priority $p" || echo "FAIL: missing priority $p"
done
```

## Inputs

### From Previous Tasks

None — T01 has no upstream task dependencies within P04.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — Current hardcoded section ordering (lines 17-26). The recipe must declare all existing sections plus the new `constraints` section.
- `scripts/dispatch/compress-payload.sh` — Current hardcoded compression strategy (lines 14-18). The compression block must declare these as configurable steps.
- `.specify/memory/constitution.md` — Principles X (Templating Over Inference), XI (Single Source of Truth), XIII (Agent Instruction Schema). Recipe design must comply.
- `specs/004-engine-architecture/spec.md` — US2 (AS1-AS5), US3 (AS1-AS3), FR-210, FR-211, FR-212. Full requirements for context recipe.
- `templates/routing.yaml` — Existing model tiers with `context_budget` fields. Compression token budget is derived from these values.

## Expected Output

The file `templates/context-recipe.yaml` containing:
- Header comment with schema description, override instructions, and constitution references
- `sections:` block with 7 named sections, each having source, priority, order, filter, and cache_hint
- `compression:` block with enabled flag, 3 graduated steps (drop_optional, summarize, drop_lowest_confidence), and protected_sections list
- `manifest:` block with enabled flag and include toggles
- Maximum 2 levels of nesting, no YAML flow sequences, parseable by grep/sed/awk
