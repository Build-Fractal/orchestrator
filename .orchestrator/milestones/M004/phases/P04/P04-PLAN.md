---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M004"
goal: "Design and implement YAML recipe files that drive context assembly, compression, hooks, and model routing"
demo_sentence: "A default templates/context-recipe.yaml declares 7 sections (state, knowledge, decisions, upstream, scope, task_plan, constraints) with source type, priority, order, and filter config; templates/hooks.yaml declares 4 lifecycle hook points; routing.yaml is extended with fallback chains — all parseable by grep/sed/awk without jq."
risk: "high"
depends_on: [P01]
---

## Must-Haves

### Truths

- context-recipe.yaml declares exactly 7 sections with name, source, priority, and order fields
  - Check: `test "$(grep -c '^  [a-z_]*:$' templates/context-recipe.yaml)" -ge 7`
- context-recipe.yaml has a compression block with at least 3 graduated steps
  - Check: `grep -q 'compression:' templates/context-recipe.yaml`
- hooks.yaml declares exactly 4 lifecycle points (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE)
  - Check: `for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do grep -q "$p" templates/hooks.yaml || exit 1; done && echo PASS`
- hooks.yaml entries have name, script, enabled, and block_on_fail fields
  - Check: `grep -q 'block_on_fail:' templates/hooks.yaml`
- routing.yaml has fallback arrays for each tier (heavy, standard, light)
  - Check: `test "$(grep -c 'fallback:' templates/routing.yaml)" -ge 3`
- recipe-parser.sh has double-sourcing guard
  - Check: `head -5 scripts/lib/recipe-parser.sh | grep -q '_RECIPE_PARSER_SOURCED'`
- recipe-parser.sh exports parse_recipe_sections, parse_recipe_compression, and read_recipe_field functions
  - Check: `grep -q 'parse_recipe_sections' scripts/lib/recipe-parser.sh && grep -q 'parse_recipe_compression' scripts/lib/recipe-parser.sh && grep -q 'read_recipe_field' scripts/lib/recipe-parser.sh`
- All YAML files parseable by grep/sed/awk (no jq required, max 2 levels nesting)
  - Check: `grep -c '^      ' templates/context-recipe.yaml | xargs test 0 -eq`
- recipe-parser.sh is Bash 3.2 compatible (no associative arrays, no readarray, no mapfile)
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/lib/recipe-parser.sh`
- Sections marked priority required are identified as non-droppable by parse_recipe_sections
  - Check: `source scripts/lib/recipe-parser.sh && parse_recipe_sections templates/context-recipe.yaml | grep 'task_plan' | grep -q 'required'`

### Artifacts

- `templates/context-recipe.yaml` (min 60 lines, contains "compression:")
- `templates/hooks.yaml` (min 40 lines, contains "PRE_DISPATCH")
- `templates/routing.yaml` (min 30 lines, contains "fallback:")
- `scripts/lib/recipe-parser.sh` (min 120 lines, contains "_RECIPE_PARSER_SOURCED")

### Key Links

- `templates/context-recipe.yaml` → `scripts/lib/recipe-parser.sh` (parser reads recipe)
- `templates/context-recipe.yaml` → `scripts/dispatch/build-context.sh` (future: recipe drives assembly)
- `templates/context-recipe.yaml` → `scripts/dispatch/compress-payload.sh` (future: compression block drives strategy)
- `templates/hooks.yaml` → `scripts/lib/recipe-parser.sh` (parser reads hooks)
- `templates/routing.yaml` → `scripts/lib/recipe-parser.sh` (parser reads routing)
- `templates/context-recipe.yaml` → `.specify/memory/constitution.md` (implements Principles X, XI, XIII)
- `templates/hooks.yaml` → `.specify/memory/constitution.md` (implements Principle XII)

## Tasks

### T01: Default Context Recipe YAML

Design and create `templates/context-recipe.yaml` with 7 section declarations (state, knowledge, decisions, upstream, scope, task_plan, constraints), compression block with 3 graduated steps, and manifest configuration. Schema constrained to 2 levels max nesting, parseable by grep/sed/awk.

### T02: Hook Configuration YAML

Design and create `templates/hooks.yaml` declaring 4 lifecycle hook points (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE) with built-in guard hooks. Each hook entry has name, script, lifecycle_point, enabled, and block_on_fail fields. Schema constrained to 2 levels max nesting.

### T03: Routing YAML Fallback Extension

Extend `templates/routing.yaml` to add fallback arrays per tier and a structured classification rules block, while preserving the existing content. No breaking changes to the current schema.

### T04: Recipe Parser Library

Implement `scripts/lib/recipe-parser.sh` with functions `parse_recipe_sections`, `parse_recipe_compression`, `read_recipe_field`. All parsing uses grep/sed/awk only. Bash 3.2 compatible. Double-sourcing guard included.

### T05: Integration Verification

Write a verification script that sources recipe-parser.sh and validates it can parse all three YAML files (context-recipe.yaml, hooks.yaml, routing.yaml). Confirm grep/sed/awk-only parsing, Bash 3.2 compatibility, and round-trip correctness for every field.

## Task Dependencies

T01 → T04
T02 → T04
T03 → T04
T04 → T05

T01, T02, and T03 are independent YAML schema design tasks (can run in parallel).
T04 implements the parser that reads the YAML files from T01-T03.
T05 validates end-to-end integration.

## Files Likely Touched

- `templates/context-recipe.yaml` (create)
- `templates/hooks.yaml` (create)
- `templates/routing.yaml` (modify)
- `scripts/lib/recipe-parser.sh` (create)
- `scripts/verify/check-recipe-integration.sh` (create)
