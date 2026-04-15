# Recipes Reference

> Progressive disclosure reference for the speckit-orchestrator context recipe system.
> Self-contained — read this document to understand recipe schemas, source types,
> compression, and resolution order without reading source code.

> Audience: extenders, contributors

## Overview

A **recipe** is a YAML file that declares which sections to include in a dispatch payload, how to compress them when the payload exceeds the token budget, and what metadata to include in the manifest header. Recipes drive the entire context assembly pipeline: `build-context.sh` reads a recipe, parses its `sections:` block, dispatches each section to a handler, and assembles the final payload.

Every dispatch payload — the context document that an agent receives when executing a task — is assembled from a recipe. The default recipe lives at `templates/context-recipe.yaml`. Projects can override it at the milestone, phase, or task level to customize which context reaches the agent.

Key properties:

- **Declarative**: recipes describe *what* to include, not *how* to build it. The assembly engine handles resolution, filtering, and ordering.
- **Parseable without jq**: the YAML schema is constrained to max 2 levels of nesting so that `grep`/`sed`/`awk` can parse it (NFR-202). No external JSON tools are required.
- **Overridable**: place a `context-recipe.yaml` at any level of the milestone/phase/task hierarchy to override the default. The engine resolves the most specific recipe automatically (FR-211).

Constitution alignment: Principle X (Templating Over Inference), Principle XI (Single Source of Truth).

---

## Section Schema

Each entry under the `sections:` block declares one section of the dispatch payload. A section has five fields plus its name (the YAML key).

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `source` | string | yes | How to resolve the section content. See [Source Types](#source-types). |
| `priority` | enum | yes | Compression eligibility. One of: `required`, `compressible`, `optional`. |
| `order` | integer | yes | Sort key for payload assembly. Lower values appear earlier in the payload. Static sections should use low values; dynamic sections should use high values. |
| `filter` | enum | yes | Post-resolution filtering strategy. One of: `none`, `scope`, `staleness`, `confidence`. |
| `cache_hint` | enum | yes | Prompt caching guidance. One of: `static`, `semi-static`, `dynamic`. |

### Priority Values

- **`required`** — section is never dropped during compression. The `protected_sections` list in the compression config reinforces this: sections named there are exempt from all compression steps.
- **`compressible`** — section may be summarized or have entries removed during compression, but is not dropped wholesale.
- **`optional`** — section is the first to be dropped when the payload exceeds the token budget (compression step type `drop_optional`).

### Filter Values

- **`none`** — no post-resolution filtering. The handler's output is used as-is.
- **`scope`** — entries are filtered by scope (milestone/phase path matching + dependency chain). Used by the knowledge section to include only entries relevant to the current phase and its upstream dependencies.
- **`staleness`** — entries are filtered by recency. Stale entries (those not updated within a staleness window) may be excluded. Used by the decisions section.
- **`confidence`** — entries are filtered by confidence score. Low-confidence entries may be excluded during compression. Used as a secondary filter on knowledge entries.

### Cache Hint Values

These values guide prompt caching boundary placement. They do not affect content — they tell the assembly engine where cache breakpoints are most effective.

- **`static`** — content rarely changes across dispatches (e.g., knowledge entries, decisions, constraint templates). Place at the start of the payload for maximum cache reuse.
- **`semi-static`** — content changes per phase but not per task (e.g., phase plan, scope). Stable within a phase's lifetime.
- **`dynamic`** — content changes every dispatch (e.g., state context, task plan, upstream summaries). Place at the end of the payload.

### Example Section Declaration

```yaml
sections:
  knowledge:
    source: KNOWLEDGE.md
    priority: compressible
    order: 10
    filter: scope
    cache_hint: static
```

---

## Source Types

The `source` field determines which handler resolves the section content. Six source types are supported.

### `computed`

Generates content programmatically at assembly time. Currently supports one computed section: **state**, which emits the State Context block with milestone, phase, task, and tier fields read from the roadmap.

```yaml
state:
  source: computed
  priority: required
  order: 60
  filter: none
  cache_hint: dynamic
```

Output example:

```markdown
## State Context

- **Current State**: executing
- **Milestone**: M001
- **Phase**: P02
- **Task**: T01
- **Tier**: C
```

### `file`

Resolves to a markdown file at the milestone directory root. The `source` value is the filename (e.g., `KNOWLEDGE.md`, `DECISIONS.md`). Two filenames receive special handling:

- **`KNOWLEDGE.md`** — routed to the knowledge handler, which runs scope filtering, graph traversal (1-hop related entries), deduplication, and entry resolution from the knowledge index.
- **`DECISIONS.md`** — routed to the decisions handler, which runs scope filtering against the current phase's dependency chain.

Any other `.md` filename is read with a raw `cat` from the milestone directory.

```yaml
knowledge:
  source: KNOWLEDGE.md
  priority: compressible
  order: 10
  filter: scope
  cache_hint: static

decisions:
  source: DECISIONS.md
  priority: compressible
  order: 20
  filter: staleness
  cache_hint: static
```

### `phase_summaries`

Concatenates summaries from upstream (dependency) phases. The handler reads the current phase's `depends` field from the roadmap, then includes each dependency phase's `{PhaseID}-SUMMARY.md` file under an `## Upstream Context` heading with `### {PhaseID} Summary` subheadings.

If no upstream dependencies exist or no summary files are found, emits "No upstream summaries available."

```yaml
upstream:
  source: phase_summaries
  priority: compressible
  order: 50
  filter: none
  cache_hint: dynamic
```

### `phase_plan`

Extracts the Goal, Demo, and Must-Haves sections from the current phase's `{PhaseID}-PLAN.md` file. Emits a `## Scope` heading with `### Goal`, `### Demo`, and `### Must-Haves` subheadings.

```yaml
scope:
  source: phase_plan
  priority: required
  order: 40
  filter: none
  cache_hint: semi-static
```

### `task_plan`

Includes the full contents of the current task's `{TaskID}-PLAN.md` file under a `## Task Plan` heading. This is the primary instruction document for the dispatched agent.

```yaml
task_plan:
  source: task_plan
  priority: required
  order: 60
  filter: none
  cache_hint: dynamic
```

### `template`

Generates content from a predefined template with environment variable substitution. Currently supports one template section: **constraints**, which emits verification criteria, duration budget, dispatch budget, and budget enforcement mode.

The engine reads these values from environment variables set before dispatch:

| Env Var | Default | Description |
|---------|---------|-------------|
| `SH_VERIFICATION_CRITERIA` | "See phase plan must-haves" | Criteria for task verification |
| `SH_DURATION_BUDGET` | "2h" | Time budget for the task |
| `SH_DISPATCH_BUDGET` | "3" | Maximum dispatch attempts |
| `SH_BUDGET_ENFORCEMENT` | "warn" | How budget overruns are handled |

```yaml
constraints:
  source: template
  priority: optional
  order: 30
  filter: none
  cache_hint: static
```

---

## Compression

When an assembled payload exceeds the token budget (default: 30,000 tokens, configurable via `--budget`), the compression engine applies graduated steps in declaration order until the payload fits. Compression is driven by the `compression:` block in the recipe.

### Configuration

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

### Step Types

#### `drop_optional`

Removes all sections whose `priority` is `optional`. In the default recipe, this drops the `constraints` section. No additional configuration fields are needed.

**Fields**: none (operates on the manifest's priority metadata).

#### `summarize`

Truncates each `###` subsection of the target section to a maximum word count. Content beyond the limit is replaced with `[...truncated...]`. Useful for shrinking verbose upstream phase summaries.

**Fields**:
- `target_sections` — substring match against section names (e.g., `upstream` matches "Upstream Context")
- `max_words` — maximum words per `###` subsection (default: 200)

#### `drop_lowest_confidence`

Splits the target section into individual entries (delimited by `---` frontmatter boundaries), sorts them by `confidence:` field ascending, and removes the lowest-confidence entries one at a time until the payload fits the budget.

**Fields**:
- `target_sections` — substring match against section names (e.g., `knowledge` matches "Knowledge")
- `min_confidence` — confidence threshold below which entries are eligible for removal (default: 0.5; accepted for recipe compatibility but enforcement is deferred to a future release)

### Protected Sections

The `protected_sections` field is a comma-separated list of section names that are **never** modified or removed by any compression step. In the default recipe, `task_plan`, `scope`, and `state` are protected — these contain the core instructions and coordinates that the agent needs.

### Fallback Behavior

If no recipe file is found or the compression block is empty, the engine falls back to a hardcoded 3-step sequence that matches the default recipe exactly:

1. Drop optional sections
2. Summarize upstream to 200 words per subsection
3. Drop lowest-confidence knowledge entries

This ensures standalone operation without a recipe file.

---

## Manifest

The manifest is a metadata header prepended to every assembled payload. It provides a table of contents with line ranges, estimated token counts, and priorities for each section. Agents and humans can use the manifest to navigate the payload efficiently.

### Configuration

```yaml
manifest:
  enabled: true
  include_token_count: true
  include_section_list: true
  include_compression_applied: true
```

### Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Whether to include a manifest header at all. |
| `include_token_count` | boolean | `true` | Include estimated token counts per section and total. |
| `include_section_list` | boolean | `true` | Include the section table with line ranges. |
| `include_compression_applied` | boolean | `true` | Note which compression steps were applied (when compression occurs). |

### Manifest Table Format

When enabled, the manifest appears as a markdown table immediately after the payload title:

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
| Constraints | 192-200 | ~150 | required |
| **Total** | | **~4450** | |
```

Line numbers are absolute (relative to the start of the payload file), so agents can reference specific line ranges in their responses.

---

## Resolution Order (FR-211)

Recipes follow a **most-specific-wins** resolution order. When assembling a payload for a given task, the engine searches for a `context-recipe.yaml` file at four locations in order:

1. **Task directory** — `.orchestrator/milestones/{M}/phases/{P}/tasks/context-recipe.yaml`
2. **Phase directory** — `.orchestrator/milestones/{M}/phases/{P}/context-recipe.yaml`
3. **Milestone directory** — `.orchestrator/milestones/{M}/context-recipe.yaml`
4. **Default** — `templates/context-recipe.yaml` (shipped with the extension)

The first file found wins. This means:

- A task-level recipe overrides everything — use this for one-off tasks that need unusual context (e.g., a migration task that needs no knowledge entries but needs the full feature spec).
- A phase-level recipe applies to all tasks in that phase — use this when an entire phase has different context needs (e.g., a documentation phase that needs upstream summaries but no constraints).
- A milestone-level recipe applies to all phases and tasks — use this when the entire milestone has non-standard context requirements.
- The default recipe applies when no override exists at any level.

### CLI Override

The `--recipe` flag on `build-context.sh` bypasses the resolution chain entirely:

```bash
build-context.sh <orch_root> <milestone> <phase> <task> --recipe /path/to/custom-recipe.yaml
```

This is primarily useful for testing custom recipes before placing them in the hierarchy.

---

## Custom Recipe Authoring

### Step 1: Start from the Default

Copy the default recipe as your starting point:

```bash
cp templates/context-recipe.yaml \
   .orchestrator/milestones/M002/phases/P03/context-recipe.yaml
```

### Step 2: Edit Sections

Modify the `sections:` block. You can:

- **Remove sections** — delete the entire section entry to exclude it from the payload.
- **Add sections** — add a new entry with a `file` source pointing to any `.md` file at the milestone root.
- **Change priority** — set a section to `optional` to allow it to be dropped during compression, or `required` to protect it.
- **Reorder sections** — change `order` values to control payload ordering (lower = earlier).

Example: a recipe for a documentation phase that drops knowledge and decisions but adds a style guide:

```yaml
sections:
  scope:
    source: phase_plan
    priority: required
    order: 10
    filter: none
    cache_hint: semi-static

  task_plan:
    source: task_plan
    priority: required
    order: 20
    filter: none
    cache_hint: dynamic

  state:
    source: computed
    priority: required
    order: 30
    filter: none
    cache_hint: dynamic

  upstream:
    source: phase_summaries
    priority: optional
    order: 40
    filter: none
    cache_hint: dynamic
```

### Step 3: Customize Compression

Adjust the `compression:` block to match your section changes. If you removed the `knowledge` section, the `drop_lowest_confidence` step targeting knowledge will have no effect — you can remove it for clarity.

```yaml
compression:
  enabled: true
  steps:
    step_1:
      type: drop_optional
      description: Remove optional sections if over budget
    step_2:
      type: summarize
      target_sections: upstream
      max_words: 150
      description: Truncate upstream to 150 words
  protected_sections: task_plan,scope,state
```

### Step 4: Verify

Run `build-context.sh` with `--recipe` to test your custom recipe before relying on resolution:

```bash
scripts/dispatch/build-context.sh \
  .orchestrator M002 P03 T01 \
  --recipe .orchestrator/milestones/M002/phases/P03/context-recipe.yaml
```

Check the output:

- The manifest table lists the sections you declared.
- Section ordering matches your `order` values.
- Protected sections survive compression.
- Removed sections do not appear.

### Step 5: Place in the Hierarchy

Once verified, the recipe is already in the correct location for FR-211 resolution. Future dispatches for tasks in that phase will automatically use it.

### Common Patterns

**Minimal recipe** — for simple tasks that only need the task plan and state:

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

**Heavy-context recipe** — for complex tasks that need full knowledge, decisions, and upstream context with relaxed compression:

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

---

## Cross-References

- [Routing Reference](routing.md) — model tier selection, fallback chains, and budget controls
- [File Formats Reference](file-formats.md) — state file schemas for all orchestrator artifacts
- [Architecture Reference](architecture.md) — system-level view of how recipes fit into the dispatch pipeline
- [Hooks Reference](hooks.md) — hook lifecycle that runs alongside recipe-driven dispatch
- [Engine Reference](engine.md) — the autonomous loop that calls `build-context.sh`
- [Events Reference](events.md) — `DISPATCH_START` and `SAFETY_WARNING` events emitted during recipe resolution
- Default recipe: [`templates/context-recipe.yaml`](../templates/context-recipe.yaml)
- Recipe parser: [`scripts/lib/recipe-parser.sh`](../scripts/lib/recipe-parser.sh)
- Context assembler: [`scripts/dispatch/build-context.sh`](../scripts/dispatch/build-context.sh)
- Section handlers: [`scripts/dispatch/lib/section-handlers.sh`](../scripts/dispatch/lib/section-handlers.sh)
- Compression engine: [`scripts/dispatch/compress-payload.sh`](../scripts/dispatch/compress-payload.sh)
