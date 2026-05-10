---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M006"
name: "Create references/routing.md — model routing reference"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- No prior tasks required — T02 is independent.

## Description

Create a new reference document at `references/routing.md` that documents
the model routing and classification system comprehensively enough that a
developer can configure model tiers, set up fallback chains, customize
classification rules, and understand budget controls without reading
the source code.

The document must follow existing `references/` conventions (DC-1):
progressive disclosure statement, `## Overview` immediately after title,
`##`/`###` structure, ASCII diagrams where helpful, no inline HTML. It
must declare an audience label (DC-2) of `extenders, users`. All
cross-links must use relative paths (DC-3).

## Steps

### Step 1 — Read source files to map routing system behavior

Read the following files to understand the routing system:

- `templates/routing.yaml` — the default routing config. Note:
  - Lines 11-23: models block — 3 tiers (heavy, standard, light), each with id, context_budget, fallback chain
  - Lines 25-34: classification block — per-tier patterns (comma-separated keywords) and confidence thresholds
  - Lines 36-39: fallback_config — recoverable_errors, max_retries, retry_delay_seconds
  - Lines 41-42: Top-level scalars — history_weight (0.3), budget_ceiling_usd (50.00)

- `scripts/dispatch/select-model.sh` — model selection with fallback. Note:
  - Lines 14-16: Usage — 3 modes: default (print model+budget), --list-fallback, --next-fallback
  - Lines 25-26: Output contracts for each mode
  - Lines 134-148: Built-in defaults when no routing.yaml exists
  - Lines 151-164: Default mode — reads model ID and context_budget from routing.yaml
  - Lines 167-179: List-fallback mode — reads fallback chain
  - Lines 182-236: Next-fallback mode — walks the chain from current model ID
  - Error behavior: exit 1 if current model not in chain, exit 1 if chain exhausted

- `scripts/dispatch/classify-complexity.sh` — complexity classification. Note:
  - Lines 59-65: Priority 1 — explicit `complexity:` in YAML frontmatter
  - Lines 77-117: Priority 2 — custom patterns from routing.yaml classification block
  - Lines 120-143: Priority 3 — built-in keyword signal matching (7 heavy, 7 standard, 9 light keywords)
  - Lines 146-152: Tie-breaking — most signals wins; standard is the default
  - Classification input: full task plan content (lowercased for matching)

### Step 2 — Write `references/routing.md`

Create the file with the following structure:

```markdown
# Model Routing Reference

> Progressive disclosure reference for speckit-orchestrator model routing.
> Self-contained — read this document to configure model tiers, fallback
> chains, and classification rules without reading source code.

> Audience: extenders, users

## Overview

[2-3 paragraph summary: what routing does, how it interacts with recipe
context_budget, and why fallback chains exist]

---

## Model Tiers

[Document the 3 tiers: heavy, standard, light]

### heavy
[Default: claude-opus-4-6, context_budget: 200000, fallback chain]

### standard
[Default: claude-sonnet-4-6, context_budget: 150000, fallback chain]

### light
[Default: claude-haiku-4-5, context_budget: 80000, no fallback]

### Built-in Defaults
[What happens when no routing.yaml exists: select-model.sh uses
hardcoded defaults matching the template values]

---

## Fallback Chains

[How fallback works: primary fails with recoverable error → engine
retries with next model in chain]

### Configuration
[models.<tier>.fallback: comma-separated model IDs]

### Fallback Config
[recoverable_errors, max_retries, retry_delay_seconds]

### Chain Walk Behavior
[--next-fallback mode: finds current model in chain, returns next.
 Exit 1 if current not found or chain exhausted. ASCII diagram of walk.]

---

## Classification Rules

[How tasks get assigned to tiers]

### Priority Order
1. Explicit `complexity:` in task plan frontmatter (override)
2. Custom patterns from routing.yaml classification block
3. Built-in keyword signal matching
4. Default: "standard"

### Custom Patterns
[classification.<tier>.patterns: comma-separated keywords]
[classification.<tier>.confidence: threshold value]

### Built-in Keywords
[7 heavy signals, 7 standard signals, 9 light signals — full list]

### Tie-Breaking
[Most signals wins. Standard is the default when counts are equal.]

---

## Budget Controls

### context_budget
[Per-tier token budget passed to compression via recipe system]

### budget_ceiling_usd
[Dollar ceiling for total dispatch costs]

### history_weight
[Weight factor for historical classification data]

---

## Authoring a Custom Routing Config

[Walkthrough: create routing.yaml override, change tiers, add patterns]

### Example: Adding a Custom Model

[Show adding a new model to a tier]

### Example: Custom Classification Patterns

[Show overriding classification patterns for project-specific terms]

---

## select-model.sh CLI Reference

[Brief: 3 invocation modes, arguments, output contracts]

---

## classify-complexity.sh CLI Reference

[Brief: arguments, classification priority, output]

---

## Cross-References

[Links to recipes.md, file-formats.md, architecture.md, engine.md]
```

### Step 3 — Verify-as-you-write (DC-4)

For each claim in the document:
- If it documents model tier defaults, confirm by reading `templates/routing.yaml` lines 11-23.
- If it documents fallback behavior, confirm by reading `scripts/dispatch/select-model.sh` lines 182-236.
- If it documents classification rules, confirm by reading `scripts/dispatch/classify-complexity.sh` lines 59-152.
- If it states built-in keywords, confirm by reading `classify-complexity.sh` lines 120-143.
- If it documents budget fields, confirm by reading `templates/routing.yaml` lines 41-42.
- Fix any code discrepancy with a commit referencing `references/routing.md` (DC-5).

### Step 4 — Add cross-links

Insert relative-path links to:
- `recipes.md` — for context_budget usage and recipe compression integration
- `file-formats.md` — for the routing.yaml format specification
- `architecture.md` — for where routing fits in the engine pipeline
- `engine.md` — for how select-model is invoked during dispatch

## Must-Haves

- [ ] `references/routing.md` exists and is >= 120 lines
- [ ] Opens with progressive disclosure statement and audience label
- [ ] Documents all 3 model tiers: heavy, standard, light
- [ ] Documents context_budget per tier
- [ ] Documents fallback chain configuration and walk behavior
- [ ] Documents classification priority order (4 levels)
- [ ] Lists all built-in classification keywords (heavy, standard, light)
- [ ] Documents budget_ceiling_usd and history_weight
- [ ] Documents fallback_config: recoverable_errors, max_retries, retry_delay_seconds
- [ ] Cross-links to recipes.md, file-formats.md, architecture.md, engine.md using relative paths

## Verification

After writing the file, confirm:

```
bash scripts/verify/m006-p03-routing-header.sh
bash scripts/verify/m006-p03-routing-models.sh
bash scripts/verify/m006-p03-routing-config.sh
```

All must pass. If verification scripts from T03 are not yet available,
manual checks confirm the core must-haves:

```
test -f references/routing.md
test "$(wc -l < references/routing.md | tr -d ' ')" -ge 120
grep -q "## Overview" references/routing.md
grep -qi "Audience:" references/routing.md
grep -q "heavy" references/routing.md
grep -q "standard" references/routing.md
grep -q "light" references/routing.md
grep -q "fallback" references/routing.md
grep -q "classification" references/routing.md
grep -q "budget_ceiling" references/routing.md
grep -q "history_weight" references/routing.md
grep -q "recipes.md" references/routing.md
```

## Inputs

### From Previous Tasks

None — T02 is independent.

### From Disk (Pre-existing)

- `templates/routing.yaml` — default routing config (primary source of truth)
- `scripts/dispatch/select-model.sh` — model selection with fallback chains
- `scripts/dispatch/classify-complexity.sh` — complexity classification
- `scripts/lib/recipe-parser.sh` — YAML parser (used by select-model.sh for reading routing.yaml)
- `references/architecture.md` — cross-link target (already exists)
- `references/engine.md` — cross-link target (already exists)
- `references/file-formats.md` — cross-link target (already exists)
- `references/recipes.md` — cross-link target (may not exist yet if T01 hasn't run)

## Constraints

- **DC-1**: Progressive disclosure format, `## Overview`, `##`/`###`, ASCII diagrams, no HTML.
- **DC-2**: Audience label: `extenders, users`.
- **DC-3**: All cross-links use relative paths from `references/` directory.
- **DC-4**: Verify-as-you-write — every documented behavior confirmed by reading the source.
- **DC-5**: Any bug fix commit references `references/routing.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `references/routing.md` exists with 120+ lines.
2. The document covers model tiers, fallback chains, classification rules,
   budget controls, and a custom routing walkthrough.
3. Cross-links to recipes.md, file-formats.md, architecture.md, and engine.md are present.
4. If any code bugs were found, each fix is committed referencing this doc.
