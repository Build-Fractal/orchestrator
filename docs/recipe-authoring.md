# Recipe Authoring Guide

**A context recipe is a YAML file that controls exactly what context an agent receives when the orchestrator dispatches a task — and the whole workflow is copy the default, edit it, test it.**

> Audience: users · Role: reference (deep guide)

## TL;DR

- A **context recipe** declares which sections go into a dispatch **payload** (the document a fresh agent reads to execute one task), in what order, how to compress them if too large, and what the manifest header shows.
- The default recipe at [`templates/context-recipe.yaml`](../templates/context-recipe.yaml) already includes every section with sensible defaults. **Most projects never touch it.**
- To customize: `cp` the default to a milestone/phase/task directory, edit it, then test with `build-context.sh --recipe ...`. The orchestrator auto-resolves the most specific recipe at dispatch time.

**Prerequisites / assumes you know:** the orchestrator is installed and a project is initialized — see [Getting Started](getting-started.md). Recipes are resolved **relative to an existing milestone/phase/task directory tree** under `.orchestrator/milestones/`. If you don't have one yet, run `/orchestrator-start` (warm front door) or `/orchestrator-do "<task>"` (one-shot entry) to create the structure first; this guide assumes those directories already exist. Terms like *dispatch*, *Quick/Standard/Full intensity*, and `.orchestrator/` state are defined in [Getting Started](getting-started.md).

## Section index

| Jump to | What it covers |
|---------|----------------|
| [Quick start](#quick-start) | The three-step copy-edit-test loop |
| [When you'd customize](#when-youd-customize-a-recipe) | Four reasons, each with a concrete trigger |
| [Section configuration](#section-configuration) | Adding, removing, reprioritizing, reordering sections |
| [Source types reference](#source-types-reference) | The six source types + custom files |
| [Cache hints explained](#cache-hints-explained) | static / semi-static / dynamic, defined up front |
| [Compression configuration](#compression-configuration) | Step types + the `drop_lowest_confidence` algorithm |
| [Manifest configuration](#manifest-configuration) | What the payload header shows and why |
| [Common patterns](#common-patterns) | Three copy-paste recipe templates |
| [Troubleshooting](#troubleshooting) | Symptom → cause → fix |
| [See also](#see-also) | Canonical references |

---

## Quick start

The fastest way to create a custom recipe is to copy the default, edit it, and test it. (Paths below are repo-relative; run them from your project root.)

**1. Copy the default recipe to the level you want to override.**

```bash
# Phase-level override
cp templates/context-recipe.yaml \
   .orchestrator/milestones/M001/phases/P02/context-recipe.yaml

# Milestone-level override
cp templates/context-recipe.yaml \
   .orchestrator/milestones/M001/context-recipe.yaml
```

**2. Edit the copy.** Remove sections you do not need, change priorities, adjust compression. Each option is detailed in the sections below.

**3. Test before relying on it.** The `--recipe` flag points the assembler at any file directly:

```bash
scripts/dispatch/build-context.sh \
  .orchestrator M001 P02 T01 \
  --recipe .orchestrator/milestones/M001/phases/P02/context-recipe.yaml
```

**Done.** Once the file is in place, the orchestrator automatically resolves the most specific recipe for future dispatches of that phase/milestone/task — no further wiring needed. (See [resolution order](#how-recipes-resolve) for how "most specific" is decided.)

---

## When you'd customize a recipe

Reach for a custom recipe only when one of these triggers fires. If none apply, the default is fine.

| Reason | Concrete trigger — customize when… | What you'd change |
|--------|------------------------------------|-------------------|
| **A phase needs different context** | …you're planning a docs-only or refactor phase where knowledge entries are noise but upstream summaries matter. | Drop `knowledge`, raise `upstream` priority. Place at phase level. |
| **A single task needs extra context** | …one migration/integration task must read the full feature spec or an API reference the rest of the phase doesn't. | Add a [custom file source](#custom-file-sources). Place at task level. |
| **You want a smaller payload (save tokens)** | …a phase has many trivial, self-contained tasks (write a test from a signature, render a template) and you're paying for context they ignore. | Use the [minimal recipe](#minimal-recipe-lightweight-tasks); disable compression. |
| **You want to protect sections from being dropped** | …compression keeps dropping `decisions` or `knowledge` on a complex task and the agent loses critical history. | Add the section name to [`protected_sections`](#protected-sections) and/or set `priority: required`. |

---

## Section configuration

The `sections:` block declares which sections appear in the payload. Each section is a YAML key (any lowercase string with underscores) plus **five required fields**.

| Field | Values | Purpose |
|-------|--------|---------|
| `source` | see [Source types](#source-types-reference) | Where the content comes from. |
| `priority` | `required` · `compressible` · `optional` | How the section behaves under [compression](#priority-and-compression). |
| `order` | integer (lower = earlier) | Position in the assembled payload. |
| `filter` | `none` · `scope` · `staleness` · `confidence` | Which content-filter runs on the source before assembly. |
| `cache_hint` | `static` · `semi-static` · `dynamic` | Prompt-cache boundary hint — see [Cache hints](#cache-hints-explained). |

One section from the default recipe:

```yaml
sections:
  knowledge:
    source: KNOWLEDGE.md
    priority: compressible
    order: 10
    filter: scope
    cache_hint: static
```

### Adding a section

Insert a new entry under `sections:` with all five fields. For custom content, use a `.md` filename as the `source`; the file must exist at the milestone root (`.orchestrator/milestones/{M}/`).

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

### Removing a section

Delete the entire section entry from the `sections:` block. For example, removing `constraints`:

```yaml
  constraints:
    source: template
    priority: optional
    order: 30
    filter: none
    cache_hint: static
```

If a [compression step](#compression-configuration) targets a section you removed (e.g. a `drop_lowest_confidence` step on `knowledge`), the step simply has no effect. Removing the step too is tidier but optional.

### Priority and compression

`priority` controls what compression may do to a section when the payload exceeds budget:

| Priority | Behavior | Use for |
|----------|----------|---------|
| `required` | Never dropped or modified. | Context the agent absolutely needs. |
| `compressible` | May be summarized or have entries removed, but never dropped whole. | Useful-but-shrinkable context. |
| `optional` | First to be dropped when over budget. | Nice-to-have context. |

```yaml
  decisions:
    source: DECISIONS.md
    priority: required      # was: compressible
    order: 20
    filter: staleness
    cache_hint: static
```

Sections in [`compression.protected_sections`](#protected-sections) are exempt from compression regardless of `priority`. If you upgrade a section to `required`, consider adding it to `protected_sections` as well.

### Order

`order` sets the section's position in the payload (lower appears earlier). It does **not** affect compression or filtering — but placing stable context early and dynamic context late improves prompt-cache hit rates.

| Order range | Content kind | Cache hint |
|-------------|--------------|------------|
| 1–20 | Static, cacheable (knowledge, decisions) | `static` — place early for reuse |
| 30–45 | Semi-static (scope, constraints, spec_context, reference) | `semi-static` |
| 50–70 | Dynamic (upstream summaries, task plan, state) | `dynamic` |

```yaml
  upstream:
    source: phase_summaries
    priority: compressible
    order: 45          # moved earlier, was 50
    filter: none
    cache_hint: dynamic
```

---

## Source types reference

The `source` field tells the assembly engine how to resolve a section's content. The default recipe ships nine sections across these source types.

| `source` value | Resolves to | Filter applied | Notes |
|----------------|-------------|----------------|-------|
| `computed` | Programmatically generated content | — | Currently the `state` section (milestone/phase/task/tier coordinates). |
| `KNOWLEDGE.md` | Knowledge entries file at milestone root | `scope` | Scope-filters to the current phase + its dependencies, does 1-hop graph traversal for related entries, deduplicates. **Name collision — see below.** |
| `DECISIONS.md` | Architectural decisions register at milestone root | `staleness` | Scope-filtered against the phase's dependency chain. |
| `phase_summaries` | Concatenated upstream (dependency) phase summaries | `none` | Reads the phase's `depends` field from the roadmap. Emits "No upstream summaries available." when there are none. |
| `phase_plan` | Goal, Demo, Must-Haves from the current phase plan | `none` | Provides phase-level scope for the task. |
| `task_plan` | Full contents of the current task plan | `none` | The primary instruction document — everything the agent needs to execute. |
| `template` | Predefined template + env-var substitution | `none` | Currently the `constraints` section: verification criteria, duration/dispatch budgets, enforcement mode. |
| `spec_context` | Scope-filtered spec chunks (story/requirement/etc.) | `scope` | `priority: compressible`, `order: 35`. |
| `reference` | Task-scoped reference-corpus chunks (M036) | `scope` | `priority: optional`, `order: 45`; token budget governed by the `reference:` block (default 4000) — see [the default recipe](../templates/context-recipe.yaml). |
| *any other `.md`* | Custom file at milestone root | per `filter` | See [custom file sources](#custom-file-sources). |

### Disambiguating the `KNOWLEDGE.md` name collision

The string `KNOWLEDGE.md` is used in two unrelated places — don't conflate them:

- **As a `source` value in a recipe** (`source: KNOWLEDGE.md`) it names the **knowledge source type** — the per-milestone knowledge-entries file read into the payload's Knowledge section.
- **`.orchestrator/KNOWLEDGE.md` at the project root** is the **knowledge-graph index** for the whole project — the consolidated hot/warm/cold map. That index is **not** the file a recipe section reads; recipe sources resolve relative to the milestone root (`.orchestrator/milestones/{M}/`), not the project root.

In short: the recipe `source: KNOWLEDGE.md` is a *section input*; the root `KNOWLEDGE.md` is the *project index*. They share a filename, nothing else.

### Custom file sources

Any other `.md` filename as a `source` is read directly from the milestone root. This is how you inject project-specific context:

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

## Cache hints explained

`cache_hint` declares how often a section's content changes, so the assembler can order stable content first and improve prompt-cache reuse across dispatches. Define these once here; the examples and the [order table](#order) reference them.

| Cache hint | Changes… | Examples |
|------------|----------|----------|
| `static` | Rarely — stable across a whole milestone | `knowledge`, `decisions`, `constraints` |
| `semi-static` | Per phase, but not per task | `scope`, `spec_context`, `reference` |
| `dynamic` | Every dispatch | `task_plan`, `upstream`, `state` |

The hint is advisory for cache-boundary placement; it does not change which content is included or compressed.

### How recipes resolve

The engine searches for `context-recipe.yaml` at four locations, **most-specific-wins**, and uses the first one found **in its entirety** (recipes are never merged):

| Precedence | Location |
|------------|----------|
| 1 (highest) | Task dir — `.orchestrator/milestones/{M}/phases/{P}/tasks/context-recipe.yaml` |
| 2 | Phase dir — `.orchestrator/milestones/{M}/phases/{P}/context-recipe.yaml` |
| 3 | Milestone dir — `.orchestrator/milestones/{M}/context-recipe.yaml` |
| 4 (default) | `templates/context-recipe.yaml` |

**When to use each level:**

- **Task** — one-off tasks with unusual needs (a migration task needing the full spec as a custom file source).
- **Phase** — an entire phase differs (a docs phase prioritizing upstream summaries over knowledge).
- **Milestone** — the whole milestone is non-standard (a refactor needing decisions but not constraints).

**CLI override** — `--recipe` bypasses resolution entirely, ideal for testing before placing a file:

```bash
scripts/dispatch/build-context.sh \
  .orchestrator M001 P02 T01 \
  --recipe /path/to/your-project/experimental-recipe.yaml
```

---

## Compression configuration

When an assembled payload exceeds the **token budget** (default 30,000 tokens; derived from the selected model's `context_budget` in routing config — see [Routing Reference](../references/routing.md)), the compression engine applies graduated steps **in declaration order** until the payload fits. The `compression:` block controls this.

**How graduated compression works:** after each step the engine re-estimates tokens. If the payload now fits, remaining steps are skipped. If all steps run and it still exceeds budget, it is dispatched as-is with a warning.

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

| `type` | What it does | Fields |
|--------|--------------|--------|
| `drop_optional` | Removes all sections with `priority: optional` (in the default, that drops `constraints` and `reference`). | none |
| `summarize` | Truncates each `###` subsection of the target to `max_words`; overflow becomes `[...truncated...]`. | `target_sections` (substring match against section names), `max_words` |
| `drop_lowest_confidence` | Removes individual knowledge entries, lowest confidence first, until the payload fits. | `target_sections` (substring match), `min_confidence` (**see algorithm note**) |

### The `drop_lowest_confidence` algorithm

This step is more subtle than it looks — read this before tuning `min_confidence`:

1. The target section (e.g. `knowledge`) is split into individual entries on `---` frontmatter boundaries; each entry's `confidence:` value is read (defaulting to `0.90` if absent).
2. Entries are sorted by confidence **ascending** (lowest first).
3. The engine removes entries **one at a time**, re-checking the budget after each removal, and **stops the moment the payload fits** — it does *not* drop all sub-threshold entries in a batch.
4. **Tie-breaking:** entries with equal confidence are removed in original entry order (the sort is stable on the entry index), so the earliest-declared of a tied group goes first.
5. **`min_confidence` is currently inert.** It is accepted for recipe-schema compatibility but is **not** enforced as a drop threshold — the engine drops purely "until under budget" regardless of the value. (This preserves byte-for-byte parity with the pre-refactor default; a threshold-guarded variant is a future change.) **Practical consequence:** do not rely on `min_confidence: 0.5` to *protect* entries at or above 0.5 — a large payload can still drop high-confidence entries. To truly protect knowledge, set `priority: required` and add it to `protected_sections`.

### Protected sections

`protected_sections` is a comma-separated list of section names exempt from **all** compression steps — never dropped, summarized, or modified, regardless of `priority`. The default protects `task_plan,scope,state`. Add more as needed:

```yaml
  protected_sections: task_plan,scope,state,decisions,knowledge
```

### Disabling compression

Set `enabled: false` to skip compression entirely — the payload dispatches at whatever size it assembles to. Useful for minimal recipes where the payload is known to be small.

```yaml
compression:
  enabled: false
```

### Fallback behavior

If no recipe is found or the `compression` block is empty, the engine falls back to a hardcoded 3-step sequence matching the default recipe: `drop_optional` → `summarize upstream` (200 words/subsection) → `drop_lowest_confidence` on knowledge.

---

## Manifest configuration

The **manifest** is a metadata header prepended to every payload: a table of contents with line ranges, estimated token counts, and a priority label per section. It exists so the agent can locate sections precisely (line numbers are absolute, so agents can cite ranges in their output) and so you can audit what compression did. It is a *header for the receiving agent and for debugging* — agents read it as part of the payload. The `manifest:` block controls its contents.

```yaml
manifest:
  enabled: true
  include_token_count: true
  include_section_list: true
  include_compression_applied: true
```

| Field | Default | Controls |
|-------|---------|----------|
| `enabled` | `true` | Whether the header is included at all. |
| `include_token_count` | `true` | Per-section and total estimated token counts. |
| `include_section_list` | `true` | The section table with line ranges and priorities. |
| `include_compression_applied` | `true` | Notes about which compression steps ran. |

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

The **Priority** column uses the manifest's display labels (distinct from the recipe `priority` field): `required` for protected/required sections, `filtered` for scope/staleness-filtered sources (`knowledge`, `decisions`, `spec_context`, `reference`), and `optional` for droppable sections. Compressed subsections additionally carry an inline `<!-- compressed:tier2 ... -->` marker in the body.

---

## Common patterns

### Minimal recipe (lightweight tasks)

Just the task plan and state coordinates — a small payload, no compression.

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

**When to use:** self-contained tasks needing no project history, upstream context, or knowledge — e.g. writing a test for a function whose signature is in the task plan, or rendering a config file from a template.

### Heavy-context recipe (complex tasks)

Full project context with relaxed compression, protecting knowledge and decisions from being dropped.

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

**When to use:** tasks integrating across phases or depending on architectural decisions — e.g. implementing an API that must match a prior phase's interfaces, or integration tests spanning subsystems.

### Phase-specific override

An entire phase with different needs than the default. This example is a documentation phase that emphasizes upstream summaries and drops knowledge entries.

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

Place this at `.orchestrator/milestones/{M}/phases/{P}/context-recipe.yaml` and every task in that phase uses it.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Section does not appear in the payload | Section missing from the `sections:` block. | Add the entry with all five fields (`source`, `priority`, `order`, `filter`, `cache_hint`). |
| Section appears but is empty | Source file/content missing at the expected location. | **File sources:** ensure the `.md` exists at the milestone root. **`phase_summaries`:** ensure upstream phases have summary files (written after phase completion). **`phase_plan`/`task_plan`:** ensure the phase/task has been planned (plan file must exist). |
| Compression drops a section you need | Section has `priority: optional` and a `drop_optional` step runs. | Change `priority` to `compressible`/`required`, or add the name to `protected_sections`. |
| High-confidence knowledge still gets dropped | `min_confidence` is **inert** — `drop_lowest_confidence` drops until under budget regardless of threshold (see [algorithm](#the-drop_lowest_confidence-algorithm)). | Set the section to `priority: required` and add it to `protected_sections`. Tightening `min_confidence` alone won't protect it. |
| YAML parse error | Malformed recipe — parser requires strict 2-space indentation, up to 3 nesting levels. | Section fields = 4 spaces (2 levels); compression step fields = 6 spaces (3 levels). No tabs. |
| Recipe override not taking effect | File misnamed or misplaced. | Filename must be exactly `context-recipe.yaml`, at the correct level (task/phase/milestone dir). Test with `--recipe`. |
| Token estimate unexpectedly high | Large knowledge base or verbose upstream summaries inflating the payload. | Lower `max_words` on `summarize`, set verbose sections to `priority: optional`, or tighten budget. |
| Protected section still modified | Name in `protected_sections` doesn't match the section key. | Match exactly — `task_plan`, not `task-plan` or `taskplan`. |

**Manifest priority labels** (the values shown in the manifest's Priority column): `required` = protected/never-touched; `filtered` = scope/staleness-filtered sources (`knowledge`, `decisions`, `spec_context`, `reference`); `optional` = eligible for `drop_optional`. A `compressed:tier2` marker in the body indicates a section was head-dropped during tier-2 compression.

---

## See also

- [Recipes Reference](../references/recipes.md) — full section schemas, source types, compression step types, resolution order
- [Routing Reference](../references/routing.md) — model tier selection, `context_budget`, fallback chains
- [File Formats Reference](../references/file-formats.md) — state-file schemas for all orchestrator artifacts
- [Getting Started](getting-started.md) — installation and first-run guide

**Source of truth on disk:**

- Default recipe: [`templates/context-recipe.yaml`](../templates/context-recipe.yaml)
- Recipe parser: [`scripts/lib/recipe-parser.sh`](../scripts/lib/recipe-parser.sh)
- Context assembler: [`scripts/dispatch/build-context.sh`](../scripts/dispatch/build-context.sh)
- Compression engine: [`scripts/dispatch/compress-payload.sh`](../scripts/dispatch/compress-payload.sh)
