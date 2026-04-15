# Recipe Authoring Guide

> Step-by-step guide for creating and customizing context recipes.
> Follow this guide to control what context your dispatched tasks receive.

> Audience: users

## Overview

A **context recipe** is a YAML file that controls what information goes into the dispatch payload -- the document that an agent receives when executing a task. Every time the orchestrator dispatches a task, it reads a recipe and assembles the payload accordingly: which sections to include, in what order, how to compress them if the payload is too large, and what metadata to show in the manifest header.

Out of the box, the orchestrator ships a default recipe at `templates/context-recipe.yaml` that includes all available sections with sensible priorities and compression steps. Most projects never need to touch it. You would customize a recipe when:

- A phase needs different context than the default (e.g., a documentation phase that does not need knowledge entries).
- A specific task needs extra context (e.g., a migration task that needs the full feature spec).
- You want to reduce payload size for simple tasks to save tokens.
- You want to protect additional sections from compression (e.g., ensuring decisions are never dropped).

Recipes are resolved hierarchically: the orchestrator checks for a `context-recipe.yaml` at the task, phase, milestone, and default levels, using the most specific one it finds. This means you can override the recipe for a single task without affecting anything else.

---

## Quick Start

The fastest way to create a custom recipe is to copy the default and modify it.

**1. Copy the default recipe to the level you want to override.**

For a phase-level override:

```bash
cp templates/context-recipe.yaml \
   .orchestrator/milestones/M001/phases/P02/context-recipe.yaml
```

For a milestone-level override:

```bash
cp templates/context-recipe.yaml \
   .orchestrator/milestones/M001/context-recipe.yaml
```

**2. Edit the copy.** Remove sections you do not need, change priorities, or adjust compression. See the sections below for details on each option.

**3. Test the recipe** before relying on it for real dispatches:

```bash
scripts/dispatch/build-context.sh \
  .orchestrator M001 P02 T01 \
  --recipe .orchestrator/milestones/M001/phases/P02/context-recipe.yaml
```

**4. Done.** The orchestrator automatically resolves the most specific recipe at dispatch time. Once your file is in place, future dispatches for that phase (or milestone, or task) will use it.

---

## Section Configuration

The `sections:` block in a recipe declares which sections appear in the dispatch payload. Each section has a name (the YAML key) and five fields: `source`, `priority`, `order`, `filter`, and `cache_hint`.

Here is one section from the default recipe:

```yaml
sections:
  knowledge:
    source: KNOWLEDGE.md
    priority: compressible
    order: 10
    filter: scope
    cache_hint: static
```

### Adding a Section

To add a section, insert a new entry under `sections:` with all five required fields. The section name (the YAML key) can be any lowercase string with underscores.

Example -- adding a custom section that includes a style guide stored at the milestone root:

```yaml
sections:
  # ... existing sections ...

  style_guide:
    source: STYLE-GUIDE.md
    priority: optional
    order: 35
    filter: none
    cache_hint: static
```

The `source` field determines where the content comes from. For custom sections, use a `file` source (a `.md` filename). The file must exist at the milestone directory root (`.orchestrator/milestones/{M}/`).

### Removing a Section

Delete the entire section entry from the `sections:` block. For example, to remove the `constraints` section, delete these lines:

```yaml
  constraints:
    source: template
    priority: optional
    order: 30
    filter: none
    cache_hint: static
```

If you remove a section that is referenced by a compression step (e.g., removing `knowledge` when a `drop_lowest_confidence` step targets it), the compression step will have no effect. You can remove the step too for clarity, but it is not required.

### Changing Priority

The `priority` field controls how the section behaves during compression:

| Priority | Behavior |
|----------|----------|
| `required` | Never dropped or modified during compression. Use for sections the agent absolutely needs. |
| `compressible` | May be summarized or have entries removed, but not dropped entirely. Use for useful-but-shrinkable context. |
| `optional` | First to be dropped when the payload exceeds the token budget. Use for nice-to-have context. |

To change a section's priority, edit the `priority` field:

```yaml
  decisions:
    source: DECISIONS.md
    priority: required      # was: compressible
    order: 20
    filter: staleness
    cache_hint: static
```

Sections listed in the `compression.protected_sections` field are also exempt from compression regardless of their `priority` value. If you upgrade a section to `required`, consider adding it to `protected_sections` as well.

### Changing Order

The `order` field controls the position of the section in the assembled payload. Lower values appear earlier. Changing order is purely cosmetic to the agent -- it does not affect compression or filtering -- but placing stable context early and dynamic context late improves prompt cache hit rates.

Guidelines:

- **1-20**: Static, cacheable content (knowledge, decisions). Place early for maximum cache reuse.
- **30-40**: Semi-static content (scope, constraints). Changes per phase but not per task.
- **50-70**: Dynamic content (upstream summaries, task plan, state). Changes every dispatch.

```yaml
  upstream:
    source: phase_summaries
    priority: compressible
    order: 45          # moved earlier, was 50
    filter: none
    cache_hint: dynamic
```

---

## Source Types

The `source` field tells the assembly engine how to resolve the section's content. Six source types are available.

### `computed`

Generates content programmatically at assembly time. Currently supports the **state** section, which emits the State Context block (milestone, phase, task, tier coordinates).

```yaml
  state:
    source: computed
    priority: required
    order: 60
    filter: none
    cache_hint: dynamic
```

### `KNOWLEDGE.md` (file -- knowledge)

Resolves to the knowledge entries file at the milestone root. The engine runs scope filtering (only entries relevant to the current phase and its dependencies), 1-hop graph traversal for related entries, and deduplication.

```yaml
  knowledge:
    source: KNOWLEDGE.md
    priority: compressible
    order: 10
    filter: scope
    cache_hint: static
```

### `DECISIONS.md` (file -- decisions)

Resolves to the architectural decisions register at the milestone root. The engine runs scope filtering against the current phase's dependency chain.

```yaml
  decisions:
    source: DECISIONS.md
    priority: compressible
    order: 20
    filter: staleness
    cache_hint: static
```

### `phase_summaries`

Concatenates summaries from upstream (dependency) phases. The engine reads the current phase's `depends` field from the roadmap and includes each dependency phase's summary file. If no upstream dependencies exist, emits "No upstream summaries available."

```yaml
  upstream:
    source: phase_summaries
    priority: compressible
    order: 50
    filter: none
    cache_hint: dynamic
```

### `phase_plan`

Extracts the Goal, Demo, and Must-Haves sections from the current phase's plan file. Provides the phase-level scope for the task.

```yaml
  scope:
    source: phase_plan
    priority: required
    order: 40
    filter: none
    cache_hint: semi-static
```

### `task_plan`

Includes the full contents of the current task's plan file. This is the primary instruction document for the agent -- it contains everything the agent needs to execute the task.

```yaml
  task_plan:
    source: task_plan
    priority: required
    order: 60
    filter: none
    cache_hint: dynamic
```

### `template`

Generates content from a predefined template with environment variable substitution. Currently supports the **constraints** section, which emits verification criteria, duration budget, dispatch budget, and budget enforcement mode.

```yaml
  constraints:
    source: template
    priority: optional
    order: 30
    filter: none
    cache_hint: static
```

### Custom file sources

Any other `.md` filename as a `source` value is read directly from the milestone directory root. This is how you include project-specific context files:

```yaml
  api_reference:
    source: API-REFERENCE.md
    priority: optional
    order: 25
    filter: none
    cache_hint: static
```

The file must exist at `.orchestrator/milestones/{M}/API-REFERENCE.md`.

---

## Per-Phase Overrides

Recipes follow a most-specific-wins resolution order. When the engine assembles a payload for a task, it searches for `context-recipe.yaml` at four locations:

1. **Task directory** -- `.orchestrator/milestones/{M}/phases/{P}/tasks/context-recipe.yaml`
2. **Phase directory** -- `.orchestrator/milestones/{M}/phases/{P}/context-recipe.yaml`
3. **Milestone directory** -- `.orchestrator/milestones/{M}/context-recipe.yaml`
4. **Default** -- `templates/context-recipe.yaml`

The first file found wins. The engine does not merge recipes -- the winning recipe is used in its entirety.

**When to use each level:**

- **Task-level**: One-off tasks with unusual context needs. Example: a migration task that needs no knowledge entries but needs the full feature spec as a custom file source.
- **Phase-level**: An entire phase has different context needs. Example: a documentation phase where upstream summaries matter more than knowledge entries.
- **Milestone-level**: The whole milestone has non-standard requirements. Example: a refactoring milestone that needs decisions but not constraints.

**CLI override**: The `--recipe` flag on `build-context.sh` bypasses resolution entirely. Useful for testing before placing a recipe file:

```bash
scripts/dispatch/build-context.sh \
  .orchestrator M001 P02 T01 \
  --recipe /path/to/experimental-recipe.yaml
```

---

## Compression Configuration

When an assembled payload exceeds the token budget (default: 30,000 tokens), the compression engine applies graduated steps in declaration order until the payload fits. The `compression:` block in the recipe controls this behavior.

### How graduated compression works

The engine processes compression steps sequentially. After each step, it re-estimates the token count. If the payload fits within the budget, remaining steps are skipped. If all steps execute and the payload still exceeds the budget, it is dispatched as-is with a warning.

```yaml
compression:
  enabled: true
  steps:
    step_1:
      type: drop_optional
      description: Remove sections marked priority optional
    step_2:
      type: summarize
      target_sections: upstream
      max_words: 200
      description: Truncate upstream summaries to 200 words each
    step_3:
      type: drop_lowest_confidence
      target_sections: knowledge
      min_confidence: 0.5
      description: Drop knowledge entries below 0.5 confidence
  protected_sections: task_plan,scope,state
```

### Step types

**`drop_optional`** -- Removes all sections with `priority: optional`. In the default recipe, this drops the `constraints` section. No additional fields needed.

**`summarize`** -- Truncates each subsection of the target to a maximum word count. Content beyond the limit is replaced with `[...truncated...]`.

Fields:
- `target_sections` -- substring match against section names (e.g., `upstream`)
- `max_words` -- maximum words per `###` subsection

**`drop_lowest_confidence`** -- Removes individual knowledge entries below a confidence threshold, starting with the lowest confidence first.

Fields:
- `target_sections` -- substring match against section names (e.g., `knowledge`)
- `min_confidence` -- confidence threshold below which entries are eligible for removal

### Protected sections

The `protected_sections` field is a comma-separated list of section names that are exempt from all compression steps. Protected sections are never dropped, summarized, or modified regardless of their `priority` value.

The default protects `task_plan`, `scope`, and `state`. To protect additional sections, add them to the list:

```yaml
  protected_sections: task_plan,scope,state,decisions,knowledge
```

### Disabling compression

Set `enabled: false` to skip compression entirely. The payload is dispatched at whatever size it assembles to. Useful for minimal recipes where you know the payload will be small.

```yaml
compression:
  enabled: false
```

### Fallback behavior

If no recipe file is found or the compression block is empty, the engine falls back to a hardcoded 3-step sequence matching the default recipe: drop optional sections, summarize upstream to 200 words per subsection, and drop lowest-confidence knowledge entries.

---

## Manifest Configuration

The manifest is a metadata header prepended to every assembled payload. It provides a table of contents with line ranges, estimated token counts, and priorities for each section. The `manifest:` block controls what the manifest includes.

```yaml
manifest:
  enabled: true
  include_token_count: true
  include_section_list: true
  include_compression_applied: true
```

| Field | Default | What it controls |
|-------|---------|-----------------|
| `enabled` | `true` | Whether the manifest header is included at all. |
| `include_token_count` | `true` | Per-section and total estimated token counts. |
| `include_section_list` | `true` | The section table with line ranges and priorities. |
| `include_compression_applied` | `true` | Notes about which compression steps were applied. |

Example manifest output:

```markdown
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge (8 entries) | 12-45 | ~1200 | filtered |
| Decisions | 47-62 | ~400 | filtered |
| Scope | 64-98 | ~800 | required |
| Upstream Context | 100-130 | ~600 | required |
| Task Plan | 132-180 | ~1100 | required |
| State Context | 182-190 | ~200 | required |
| **Total** | | **~4450** | |
```

Line numbers are absolute, so agents can reference specific ranges in their output.

---

## Common Patterns

### Minimal Recipe (lightweight tasks)

For simple tasks that only need the task plan and state coordinates. Produces a small payload with no compression needed.

```yaml
sections:
  task_plan:
    source: task_plan
    priority: required
    order: 10
    filter: none
    cache_hint: dynamic
  state:
    source: computed
    priority: required
    order: 20
    filter: none
    cache_hint: dynamic

compression:
  enabled: false

manifest:
  enabled: true
  include_token_count: true
  include_section_list: true
  include_compression_applied: false
```

**When to use**: tasks that are self-contained and do not need project history, upstream context, or knowledge entries. Examples: writing a test for a function whose signature is in the task plan, creating a configuration file from a template.

### Heavy-Context Recipe (complex tasks)

For tasks that need full project context with relaxed compression thresholds. Protects knowledge and decisions from being dropped.

```yaml
sections:
  knowledge:
    source: KNOWLEDGE.md
    priority: required
    order: 10
    filter: scope
    cache_hint: static
  decisions:
    source: DECISIONS.md
    priority: required
    order: 20
    filter: staleness
    cache_hint: static
  constraints:
    source: template
    priority: compressible
    order: 30
    filter: none
    cache_hint: static
  scope:
    source: phase_plan
    priority: required
    order: 40
    filter: none
    cache_hint: semi-static
  upstream:
    source: phase_summaries
    priority: compressible
    order: 50
    filter: none
    cache_hint: dynamic
  task_plan:
    source: task_plan
    priority: required
    order: 60
    filter: none
    cache_hint: dynamic
  state:
    source: computed
    priority: required
    order: 70
    filter: none
    cache_hint: dynamic

compression:
  enabled: true
  steps:
    step_1:
      type: summarize
      target_sections: upstream
      max_words: 300
      description: Truncate upstream summaries to 300 words
    step_2:
      type: drop_lowest_confidence
      target_sections: knowledge
      min_confidence: 0.3
      description: Drop knowledge entries below 0.3 confidence
  protected_sections: task_plan,scope,state,knowledge,decisions
```

**When to use**: tasks that integrate across multiple phases or depend on architectural decisions. Examples: implementing an API that must match interfaces from a prior phase, writing integration tests that span multiple subsystems.

### Phase-Specific Override

For an entire phase that has different context needs than the default. This example is for a documentation phase that emphasizes upstream summaries and drops knowledge entries.

```yaml
sections:
  scope:
    source: phase_plan
    priority: required
    order: 10
    filter: none
    cache_hint: semi-static
  upstream:
    source: phase_summaries
    priority: required
    order: 20
    filter: none
    cache_hint: dynamic
  task_plan:
    source: task_plan
    priority: required
    order: 30
    filter: none
    cache_hint: dynamic
  state:
    source: computed
    priority: required
    order: 40
    filter: none
    cache_hint: dynamic

compression:
  enabled: true
  steps:
    step_1:
      type: summarize
      target_sections: upstream
      max_words: 400
      description: Allow longer upstream summaries for doc context
  protected_sections: task_plan,scope,state,upstream

manifest:
  enabled: true
  include_token_count: true
  include_section_list: true
  include_compression_applied: true
```

Place this file at `.orchestrator/milestones/{M}/phases/{P}/context-recipe.yaml` and all tasks in that phase will use it.

---

## Troubleshooting

### Section does not appear in the payload

- **Cause**: the section is missing from the recipe's `sections:` block.
- **Fix**: add the section entry with all five required fields (`source`, `priority`, `order`, `filter`, `cache_hint`).

### Section appears but has no content

- **Cause**: the source file does not exist at the expected location.
- **Fix for file sources**: ensure the `.md` file exists at the milestone directory root (`.orchestrator/milestones/{M}/`).
- **Fix for `phase_summaries`**: ensure upstream phases have summary files written. Summaries are generated after phase completion.
- **Fix for `phase_plan` / `task_plan`**: ensure the phase or task has been planned (the plan file must exist).

### Compression drops a section you need

- **Cause**: the section has `priority: optional` and a `drop_optional` compression step is configured.
- **Fix**: change the section's `priority` to `compressible` or `required`, or add the section name to `protected_sections`.

### YAML parse error

- **Cause**: the recipe YAML is malformed. The parser requires strict 2-space indentation and max 2 levels of nesting.
- **Fix**: ensure all section fields are indented with exactly 4 spaces (2 levels: 2 for section name + 2 for field). Compression step fields use 6 spaces (3 levels). Do not use tabs.

### Recipe override not taking effect

- **Cause**: the file is not named `context-recipe.yaml` or is not placed in the correct directory.
- **Fix**: verify the filename is exactly `context-recipe.yaml` and the file is at the correct level in the hierarchy (task, phase, or milestone directory). Use the `--recipe` flag to test the file directly.

### Token estimate is unexpectedly high

- **Cause**: a large knowledge base or verbose upstream summaries are inflating the payload.
- **Fix**: tighten compression by lowering `max_words` on the `summarize` step, raising `min_confidence` on the `drop_lowest_confidence` step, or setting verbose sections to `priority: optional`.

### Protected section is still being modified

- **Cause**: the section name in `protected_sections` does not match the section key in the `sections:` block.
- **Fix**: ensure the names match exactly. For example, if your section is keyed as `task_plan`, use `task_plan` in the protected list (not `task-plan` or `taskplan`).

---

## Cross-References

- [Recipes Reference](../references/recipes.md) -- full reference for section schemas, source types, compression step types, and resolution order
- [Routing Reference](../references/routing.md) -- model tier selection, fallback chains, and budget controls
- [File Formats Reference](../references/file-formats.md) -- state file schemas for all orchestrator artifacts
- [Getting Started](getting-started.md) -- installation and first-run guide
- Default recipe: [`templates/context-recipe.yaml`](../templates/context-recipe.yaml)
- Recipe parser: [`scripts/lib/recipe-parser.sh`](../scripts/lib/recipe-parser.sh)
- Context assembler: [`scripts/dispatch/build-context.sh`](../scripts/dispatch/build-context.sh)
- Compression engine: [`scripts/dispatch/compress-payload.sh`](../scripts/dispatch/compress-payload.sh)
