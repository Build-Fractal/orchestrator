---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M006"
name: "Create references/recipes.md — context recipe reference"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- No prior tasks required — T01 is independent.

## Description

Create a new reference document at `references/recipes.md` that documents
the context recipe system comprehensively enough that a developer can
author a custom recipe, override it at milestone/phase/task level,
configure compression, and understand manifest output without reading
the source code.

The document must follow existing `references/` conventions (DC-1):
progressive disclosure statement, `## Overview` immediately after title,
`##`/`###` structure, ASCII diagrams where helpful, no inline HTML. It
must declare an audience label (DC-2) of `extenders, users`. All
cross-links must use relative paths (DC-3).

## Steps

### Step 1 — Read source files to map recipe system behavior

Read the following files to understand the recipe system:

- `templates/context-recipe.yaml` — the default recipe template. Note:
  - Line 6: Override resolution order: task > phase > milestone > default (FR-211)
  - Lines 12-18: Section field schema: source, priority, order, filter, cache_hint
  - Lines 20-68: Section declarations (7 sections: state, knowledge, decisions, upstream, scope, task_plan, constraints)
  - Lines 70-94: Compression configuration (3 step types: drop_optional, summarize, drop_lowest_confidence)
  - Line 94: protected_sections — comma-separated list of sections excluded from compression
  - Lines 96-104: Manifest configuration (enabled, include_token_count, include_section_list, include_compression_applied)

- `scripts/lib/recipe-parser.sh` — recipe YAML parser. Note:
  - `read_recipe_field <file> <dotted.path>` (lines 29-54): read any scalar field by dotted path (1-3 levels)
  - `parse_recipe_sections <file>` (lines 168-251): list all sections, output format: `<name>|<source>|<priority>|<order>|<filter>|<cache_hint>`, sorted by order ascending
  - `parse_recipe_compression <file>` (lines 258-345): list compression steps, output format: `<step_key>|<type>|<target_sections>|<max_words>|<min_confidence>|<description>`
  - `resolve_recipe <orch_root> <milestone> <phase> <task> [filename]` (lines 442-481): FR-211 resolution chain: task dir > phase dir > milestone dir > templates/ default
  - `parse_recipe_fallback <file> <tier>` (lines 431-436): read fallback chain for a model tier

- `scripts/dispatch/build-context.sh` — context assembly using recipes. Note:
  - Line 6-7: recipe resolution via FR-211 (task > phase > milestone > default)
  - Lines 77-92: `--recipe` override flag
  - Recipe-driven branch dispatches each section to `section-handlers.sh`

- `scripts/dispatch/lib/section-handlers.sh` — per-source-type handlers. Note:
  - `handle_computed` — assembles computed state (milestone status, phase status, task list)
  - `handle_phase_summaries` — collects upstream phase summaries
  - `handle_phase_plan` — injects the current phase plan
  - `handle_task_plan` — injects the current task plan
  - `handle_template` — processes template sections (constraints, instructions)
  - `handle_knowledge` — resolves and filters knowledge entries
  - `handle_decisions` — resolves decision entries
  - `handle_file` — reads a file by relative path
  - `dispatch_section_handler` — routes source type to the correct handler

### Step 2 — Write `references/recipes.md`

Create the file with the following structure:

```markdown
# Context Recipes Reference

> Progressive disclosure reference for speckit-orchestrator context recipes.
> Self-contained — read this document to author, override, and configure
> context recipes without reading parser source code.

> Audience: extenders, users

## Overview

[2-3 paragraph summary: what recipes are, why they exist, how they
control the dispatch payload assembly pipeline]

---

## Section Schema

[Document the 5 section fields: source, priority, order, filter, cache_hint]

### source

[6 source types: computed, index (KNOWLEDGE.md), file, phase_summaries,
phase_plan, task_plan, template. What each resolves to.]

### priority

[3 values: required, compressible, optional. How compression uses them.]

### order

[Integer sort key. Lower = earlier in payload. Explain static-first
rationale.]

### filter

[4 values: none, scope, staleness, confidence. What each does.]

### cache_hint

[3 values: static, semi-static, dynamic. How prompt caching uses them.]

---

## Default Sections

[Walk through each of the 7 default sections from context-recipe.yaml
with an explanation of why each exists]

---

## Compression

[Graduated compression overview]

### Step Types

[drop_optional, summarize, drop_lowest_confidence — with field schemas]

### Protected Sections

[protected_sections field — comma-separated list, excluded from all steps]

### Configuration Example

[Complete example showing a custom compression block]

---

## Manifest

[enabled, include_token_count, include_section_list,
include_compression_applied]

---

## Recipe Resolution Order

[FR-211: task > phase > milestone > default]
[ASCII diagram of the resolution chain]
[Override example: placing context-recipe.yaml at phase level]

---

## Authoring a Custom Recipe

[Step-by-step walkthrough: create a recipe, add/remove sections,
set compression, place at the right level]

### Example: Adding a Custom Section

[Show adding a new section with source: file]

### Example: Phase-Level Override

[Show overriding default recipe at phase level to drop a section]

---

## Parser API

[Brief summary of recipe-parser.sh functions for extenders:
read_recipe_field, parse_recipe_sections, parse_recipe_compression,
resolve_recipe]

---

## Cross-References

[Links to routing.md, file-formats.md, architecture.md, engine.md]
```

### Step 3 — Verify-as-you-write (DC-4)

For each claim in the document:
- If it documents a section field schema, confirm by reading `templates/context-recipe.yaml`.
- If it documents parser behavior, confirm by reading `scripts/lib/recipe-parser.sh`.
- If it documents resolution order, confirm by reading `resolve_recipe()` in `recipe-parser.sh` lines 442-481.
- If it documents source types, confirm by reading `dispatch_section_handler()` in `section-handlers.sh`.
- If it documents compression step types, confirm by reading `parse_recipe_compression()` in `recipe-parser.sh` lines 258-345.
- Fix any code discrepancy with a commit referencing `references/recipes.md` (DC-5).

### Step 4 — Add cross-links

Insert relative-path links to:
- `routing.md` — for context_budget and model tier context
- `file-formats.md` — for the context-recipe.yaml format specification
- `architecture.md` — for where recipes fit in the engine pipeline
- `engine.md` — for how build-context.sh uses recipes during dispatch

## Must-Haves

- [ ] `references/recipes.md` exists and is >= 150 lines
- [ ] Opens with progressive disclosure statement and audience label
- [ ] Documents all 5 section fields: source, priority, order, filter, cache_hint
- [ ] Documents all 6 source types: computed, index/file, phase_summaries, phase_plan, task_plan, template
- [ ] Documents 3 compression step types: drop_optional, summarize, drop_lowest_confidence
- [ ] Documents protected_sections configuration
- [ ] Documents manifest configuration (enabled, include_token_count, include_section_list, include_compression_applied)
- [ ] Documents FR-211 resolution order: task > phase > milestone > default
- [ ] Includes at least one complete custom recipe example
- [ ] Cross-links to routing.md, file-formats.md, architecture.md, engine.md using relative paths

## Verification

After writing the file, confirm:

```
bash scripts/verify/m006-p03-recipes-header.sh
bash scripts/verify/m006-p03-recipes-sections.sh
bash scripts/verify/m006-p03-recipes-compression.sh
bash scripts/verify/m006-p03-recipes-resolution.sh
```

All must pass. If verification scripts from T03 are not yet available,
manual checks confirm the core must-haves:

```
test -f references/recipes.md
test "$(wc -l < references/recipes.md | tr -d ' ')" -ge 150
grep -q "## Overview" references/recipes.md
grep -qi "Audience:" references/recipes.md
grep -q "source" references/recipes.md
grep -q "priority" references/recipes.md
grep -q "compression" references/recipes.md
grep -q "resolution" references/recipes.md
grep -q "routing.md" references/recipes.md
grep -q "file-formats.md" references/recipes.md
```

## Inputs

### From Previous Tasks

None — T01 is independent.

### From Disk (Pre-existing)

- `templates/context-recipe.yaml` — default recipe template (primary source of truth)
- `scripts/lib/recipe-parser.sh` — recipe YAML parser (6 functions)
- `scripts/dispatch/build-context.sh` — context assembly coordinator
- `scripts/dispatch/lib/section-handlers.sh` — per-source-type section handlers
- `references/architecture.md` — cross-link target (already exists)
- `references/engine.md` — cross-link target (already exists)
- `references/file-formats.md` — cross-link target (already exists)
- `references/routing.md` — cross-link target (may not exist yet if T02 hasn't run)

## Constraints

- **DC-1**: Progressive disclosure format, `## Overview`, `##`/`###`, ASCII diagrams, no HTML.
- **DC-2**: Audience label: `extenders, users`.
- **DC-3**: All cross-links use relative paths from `references/` directory.
- **DC-4**: Verify-as-you-write — every documented behavior confirmed by reading the source.
- **DC-5**: Any bug fix commit references `references/recipes.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `references/recipes.md` exists with 150+ lines.
2. The document covers section schema, source types, compression,
   manifest, resolution order, and a custom recipe walkthrough.
3. Cross-links to routing.md, file-formats.md, architecture.md, and engine.md are present.
4. If any code bugs were found, each fix is committed referencing this doc.
