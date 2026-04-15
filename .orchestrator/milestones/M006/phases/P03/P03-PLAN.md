---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M006"
goal: "Create two reference docs (recipes.md, routing.md) verified against actual templates and parser scripts"
demo_sentence: "A developer reading references/recipes.md can author a custom context recipe, override it per-phase, configure compression, and set up model fallback chains — verified by creating a test recipe and running a dispatch with it."
risk: "low"
depends_on: []
---

<!--
  P03 — Recipe and Routing Reference Docs
  ========================================

  Context: M006 (Documentation & Quality) Phase 03 creates two new
  reference documents covering the context recipe system and model
  routing configuration. Each document is verified against the actual
  template files and parser scripts to ensure accuracy. Any
  discrepancies found between documentation and code produce bug fix
  commits per DC-5.

  Design constraints from M006-CONTEXT.md:
    DC-1: Progressive disclosure format (## Overview after title, ASCII diagrams)
    DC-2: Audience label on every doc
    DC-3: Cross-links use relative paths
    DC-4: Verify-as-you-write — run the command, confirm output matches
    DC-5: Bug fix commits reference the doc that surfaced them
    DC-6: Bash 3.2 / POSIX compatibility for all code fixes
-->

## Must-Haves

### Truths

- `references/recipes.md` exists with progressive disclosure header and audience label.
  - Check: `bash scripts/verify/m006-p03-recipes-header.sh`
- `references/recipes.md` documents all 7 section fields (source, priority, order, filter, cache_hint, id/name, and all 6 source types).
  - Check: `bash scripts/verify/m006-p03-recipes-sections.sh`
- `references/recipes.md` documents the compression block (3 step types, protected_sections, graduated application).
  - Check: `bash scripts/verify/m006-p03-recipes-compression.sh`
- `references/recipes.md` documents the resolution order (task > phase > milestone > default) and manifest configuration.
  - Check: `bash scripts/verify/m006-p03-recipes-resolution.sh`
- `references/routing.md` exists with progressive disclosure header and audience label.
  - Check: `bash scripts/verify/m006-p03-routing-header.sh`
- `references/routing.md` documents model tiers (heavy, standard, light), fallback chains, and classification rules.
  - Check: `bash scripts/verify/m006-p03-routing-models.sh`
- `references/routing.md` documents budget_ceiling, history_weight, fallback_config, and recoverable_errors.
  - Check: `bash scripts/verify/m006-p03-routing-config.sh`
- Both P03 docs cross-link to each other and to existing reference docs using relative paths (DC-3).
  - Check: `bash scripts/verify/m006-p03-crosslinks.sh`

### Artifacts

- `references/recipes.md` (min 150 lines, contains "## Overview", "Audience:", "source", "priority", "order", "filter", "cache_hint", "compression", "resolution", "manifest")
- `references/routing.md` (min 120 lines, contains "## Overview", "Audience:", "heavy", "standard", "light", "fallback", "classification", "budget_ceiling", "history_weight")

### Key Links

- `references/recipes.md` -> `references/routing.md` (model routing cross-ref for context_budget)
- `references/recipes.md` -> `references/file-formats.md` (context-recipe.yaml schema cross-ref)
- `references/recipes.md` -> `references/architecture.md` (pipeline context: where recipes fit in engine)
- `references/recipes.md` -> `references/engine.md` (engine integration: how build-context uses recipes)
- `references/routing.md` -> `references/recipes.md` (recipe context_budget cross-ref)
- `references/routing.md` -> `references/file-formats.md` (routing.yaml schema cross-ref)
- `references/routing.md` -> `references/engine.md` (engine integration: how select-model is invoked)
- `references/routing.md` -> `references/architecture.md` (pipeline context: where routing fits)

## Tasks

### T01: Create `references/recipes.md` — context recipe reference

Reads `templates/context-recipe.yaml`, `scripts/lib/recipe-parser.sh`,
`scripts/dispatch/build-context.sh`, and `scripts/dispatch/lib/section-handlers.sh`
to produce a verified reference document covering: section declaration
schema (all fields), the 6 source types and their resolution behavior,
compression block configuration (3 step types, protected_sections),
manifest configuration, recipe resolution order (FR-211), override
examples, and complete walkthrough examples for authoring a custom recipe.

Full plan: `tasks/T01-PLAN.md`

### T02: Create `references/routing.md` — model routing reference

Reads `templates/routing.yaml`, `scripts/dispatch/select-model.sh`, and
`scripts/dispatch/classify-complexity.sh` to produce a verified reference
document covering: model tier definitions (heavy, standard, light),
context_budget per tier, fallback chain configuration and walk behavior,
classification rules (custom patterns and built-in keywords),
history_weight, budget_ceiling_usd, fallback_config (recoverable_errors,
max_retries, retry_delay_seconds), and complete examples for customizing
routing.

Full plan: `tasks/T02-PLAN.md`

### T03: Verification scripts and cross-link validation for P03

Creates all 8 verification scripts referenced in the Truths section
above. Each script is a standalone single-file invocation (AD-19
compliant) that checks one specific property of the P03 documentation
artifacts. Runs the full verification to confirm all checks pass.

Full plan: `tasks/T03-PLAN.md`

## Task Dependencies

```
T01 (recipes.md)  ─────┐
T02 (routing.md)  ─────┼──→ T03 (verification scripts + cross-links)
```

T01 and T02 are independent of each other — they produce different files
and can execute in any order. T03 depends on both because it validates
the artifacts T01 and T02 produce and checks cross-links between them.

## Files Likely Touched

- `references/recipes.md` (create)
- `references/routing.md` (create)
- `scripts/verify/m006-p03-recipes-header.sh` (create)
- `scripts/verify/m006-p03-recipes-sections.sh` (create)
- `scripts/verify/m006-p03-recipes-compression.sh` (create)
- `scripts/verify/m006-p03-recipes-resolution.sh` (create)
- `scripts/verify/m006-p03-routing-header.sh` (create)
- `scripts/verify/m006-p03-routing-models.sh` (create)
- `scripts/verify/m006-p03-routing-config.sh` (create)
- `scripts/verify/m006-p03-crosslinks.sh` (create)
- Bug fix commits for any discrepancies found (files TBD)
