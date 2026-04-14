---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M006"
name: "Create docs/recipe-authoring.md — custom recipes, overrides, compression"
depends_on: ["T01"]
---

## Prerequisites

- `docs/` directory exists (created by T01).
- P03 reference doc exists: `references/recipes.md`.
- P03 reference doc exists: `references/routing.md`.

## Description

Create a user guide at `docs/recipe-authoring.md` that teaches a user how to
create and customize context recipes. Unlike `references/recipes.md` which is a
complete reference, this guide is task-oriented — it walks through common
scenarios with annotated examples. The audience is "users" (DC-2).

The guide follows progressive disclosure (DC-1): start with what recipes
are and why you'd customize one, then build up through increasingly
advanced scenarios. All cross-links use relative paths (DC-3).

The document covers:

1. **Overview** — what context recipes are, when to create a custom one,
   the default recipe and what it includes (2-3 paragraphs).

2. **How Recipes Work** — brief explanation of recipe resolution order
   (task > phase > milestone > default), how sections are assembled,
   and where recipe files live. Cross-links to `references/recipes.md`
   for full schema.

3. **Creating Your First Custom Recipe** — step-by-step walkthrough:
   - Copy the default recipe (`templates/context-recipe.yaml`)
   - Place it at the milestone level
   - Modify a section (e.g., change priority, add a filter)
   - Run a dispatch and observe the difference

4. **Overriding Per-Phase** — how to place a recipe at the phase level
   to override the milestone recipe for specific phases. Explains when
   this is useful (e.g., planning phases need different context than
   implementation phases).

5. **Adding Custom Sections** — how to add a new section to a recipe:
   - Section field reference (source, priority, order, filter, cache_hint)
   - Source types with examples (computed, file, template, phase_summaries,
     phase_plan, index)
   - Common patterns (adding project-specific context, including external docs)

6. **Configuring Compression** — how compression works, the three step
   types (drop_optional, summarize, drop_lowest_confidence), protected
   sections, and how to tune compression for your project.

7. **Troubleshooting** — common recipe issues and how to fix them:
   - Recipe not being picked up (wrong file location, wrong filename)
   - Sections appearing in wrong order
   - Compression removing important context
   - Token budget exceeded

## Steps

### Step 1 — Read source materials for accuracy

- `references/recipes.md` — full recipe schema reference (531 lines)
- `references/routing.md` — context_budget integration (260 lines)
- `references/file-formats.md` — context-recipe.yaml schema section
- `templates/context-recipe.yaml` — default recipe template
- `scripts/dispatch/build-context.sh` — how context is assembled from recipes
- `scripts/dispatch/compress-payload.sh` — how compression is applied
- `scripts/lib/recipe-parser.sh` — how recipes are parsed and resolved

### Step 2 — Write docs/recipe-authoring.md

Create the file following the structure in the Description section.
Ensure every YAML snippet in the guide uses correct syntax that would
be accepted by `recipe-parser.sh`. Include annotated examples showing
the "before" and "after" for each customization.

### Step 3 — Verify-as-you-write (DC-4)

For every YAML snippet:
- Confirm the field names match those documented in `references/recipes.md`.
- Confirm source type names match the 6 documented types.

For every file path mentioned:
- Confirm it exists on disk.

For every claim about behavior:
- Confirm by reading the relevant script.

## Must-Haves

- [ ] `docs/recipe-authoring.md` exists and is 150+ lines
- [ ] File opens with progressive disclosure statement and audience label "users"
- [ ] Contains `## Overview` section
- [ ] Documents recipe resolution order (task > phase > milestone > default)
- [ ] Includes a step-by-step "first custom recipe" walkthrough
- [ ] Documents per-phase override mechanism
- [ ] Documents adding custom sections with source type examples
- [ ] Documents compression configuration (3 step types, protected_sections)
- [ ] Includes a troubleshooting section
- [ ] Cross-links to `references/recipes.md` and `references/routing.md`
- [ ] All cross-links use relative paths and resolve to existing files

## Verification

After writing the file, run:

```
bash scripts/verify/m006-p04-recipe-header.sh
bash scripts/verify/m006-p04-recipe-content.sh
```

All must exit 0. If any verification script does not yet exist (because T05
has not run), verify manually by grepping the file for required patterns.

## Inputs

### From Previous Tasks

- T01: `docs/` directory exists.

### From Disk (Pre-existing)

- `references/recipes.md` — full recipe schema reference (531 lines)
- `references/routing.md` — context_budget, model routing (260 lines)
- `references/file-formats.md` — context-recipe.yaml schema (1105 lines)
- `templates/context-recipe.yaml` — default recipe template
- `scripts/dispatch/build-context.sh` — context assembly from recipe sections
- `scripts/dispatch/compress-payload.sh` — graduated compression steps
- `scripts/lib/recipe-parser.sh` — YAML recipe parsing and resolution

## Constraints

- **DC-1**: Progressive disclosure format — `## Overview` immediately after title,
  `##`/`###` structure, ASCII diagrams OK, no inline HTML.
- **DC-2**: Audience label: `users`.
- **DC-3**: All cross-links use relative paths from `docs/` directory.
- **DC-4**: Verify-as-you-write — every YAML field name, source type, and
  behavior claim confirmed against actual code.
- **DC-5**: Any bug fix commit messages reference `docs/recipe-authoring.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `docs/recipe-authoring.md` exists with 150+ lines.
2. A user can follow the guide to create, customize, and troubleshoot recipes.
3. All YAML snippets use correct field names matching `references/recipes.md`.
4. All cross-links resolve to existing files.
5. If any code bugs were found and fixed, each fix is committed with a message
   referencing `(found via docs/recipe-authoring.md)`.
