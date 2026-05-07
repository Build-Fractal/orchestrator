# Authoring Conventions

How to write content the orchestrator consumes — applies to artifact authors
(humans and LLM-dispatched task agents alike). This doc covers code
conventions for decision / background / analysis / memory / question entries
plus already-enabled mkdocs-material features that make content render well in
the wiki without churning source schemas.

Authority: this doc is referenced from `commands/dispatch.md` (payload
guidance), so any task whose deliverables include code-anchored entries
(DR-CODE-NNN, MEM-NNN, etc.) or wiki-rendered prose inherits these
conventions through the dispatch payload.

---

## Code Conventions for Decision-Log Entries

### Heading shape

The orchestrator's decision log (`.orchestrator/DECISIONS.md`) uses
`DR-CODE-NNN` codes as load-bearing cross-reference anchors. The legacy
shape `### DR-CODE-NNN — Human title` reads as code-soup in the right-side
TOC and forces every reader to mentally strip the prefix before they see the
human concept. The new shape leads with the human concept and renders the
code as a body chip:

```markdown
### Migration to standalone mode { #dr-code-015 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-015</span>
{: .code-chip-row }

- **When**: M015/P02
- **Scope**: arch
- **Choice**: ...
- **Revisable**: No

Human-readable rationale paragraph here.
```

Before/after pair, taken verbatim from `.orchestrator/DECISIONS.md` (D003):

> **Before** (legacy shape — what we migrated away from):
>
> ```markdown
> ### D003 — Remove state_root: from .orchestrator/config.yml in T04
> ```
>
> **After** (current shape — every entry in `DECISIONS.md` matches):
>
> ```markdown
> ### Remove state_root: from .orchestrator/config.yml in T04 { #dr-code-003 }
>
> <span class="md-tag md-tag-icon md-tag--decision">DR-CODE-003</span>
> {: .code-chip-row }
> ```

The `{ #dr-code-nnn }` anchor preserves cross-reference URLs verbatim
(mkdocs-material's `attr_list` extension consumes the heading-attribute
syntax). External links of the form `DECISIONS.md#dr-code-003` continue to
resolve after migration.

The body-chip pattern is rendered by a small CSS snippet at
`wiki/docs/stylesheets/code-chips.css` (referenced via `extra_css:` in
`wiki/mkdocs.yml`). No mkdocs-material `tags:` plugin is required — the
chip styling is plugin-free.

### Contract surface

The framework-owned shape-lint verifier at
`scripts/verify/decisions-shape-lint.sh` enforces three invariants on
`.orchestrator/DECISIONS.md`:

1. Every `### ` heading matches `^### .+ \{ #(dr|bg|an|mem|q)-[a-z0-9-]+ \}$`.
2. Zero legacy 7-column-table rows (`| Dnnn |`) remain after migration.
3. Every `{ #anchor }` declared on a heading line is unique within the file.

Run it before committing changes to `DECISIONS.md`:

```bash
bash scripts/verify/decisions-shape-lint.sh
```

The phase-suite wrapper at `tools/verify/m037-p01-decisions-shape.sh`
invokes the same verifier with a fixed target path, suitable for the M037/P01
phase-suite aggregator.

### Code prefixes

- `DR-CODE-NNN` — orchestrator decision-log entries (`.orchestrator/DECISIONS.md`).
- `BG-CODE-NNN` — background-context entries (informational; do not bind future work).
- `AN-CODE-NNN` — analysis entries (findings tied to a phase or milestone).
- `MEM-NNN` — knowledge entries (`.orchestrator/knowledge/<category>/MEM*.md` and KNOWLEDGE.md cross-refs).
- `Q-NNN` — open-question entries in spec / phase-context drafts (also written `#Q-N` inline in proposals).

The body-chip pattern (`<span class="md-tag md-tag-icon md-tag--decision">CODE</span>`)
is uniform across prefixes; only the modifier class changes
(`--decision`, `--background`, `--analysis`, `--knowledge`, `--question`).
The shape-lint regex anchors `(dr|bg|an|mem|q)`, so all five prefixes pass
the same structural check.

### When to use each prefix

- **Use `DR-CODE-NNN`** when a choice binds future work — the entry will be
  cited from later decisions, plans, or audits, and reversing it requires a
  superseding `DR-CODE-NNN` (not a silent edit). Example: `DR-CODE-003`
  records why `state_root:` was removed from config; the resolver semantics
  it codifies remain authoritative.

- **Use `BG-CODE-NNN`** when capturing background context that informs but
  does not bind future work — vendor docs digest, ecosystem state at a
  point in time, "what we already knew before starting M0XX". Background
  entries are advisory; later phases may freely diverge without superseding.

- **Use `AN-CODE-NNN`** when capturing analytic findings tied to a specific
  phase or milestone — root-cause analyses, comparative tables of options,
  cost/quality empirical measurements. Analysis entries cite evidence and
  often feed into a sibling `DR-CODE-NNN` that records the choice the
  analysis informed.

- **Use `MEM-NNN`** when capturing reusable patterns, conventions, or
  constraints that survive past the milestone they were learned in.
  `MEM001` (bash 3.2 + POSIX sh) and `MEM029` (edition-resolution two-tier
  detection) are canonical examples — both are referenced from many phases.
  Knowledge entries live in `.orchestrator/knowledge/<category>/MEM*.md`
  and are surfaced through `KNOWLEDGE.md` cross-references.

- **Use `Q-NNN`** for open questions in spec / phase-context / proposal
  drafts — items that need operator resolution before plan-time. Inline
  short-form `#Q-N` (no `CODE` infix) is the convention in proposals;
  long-form `Q-NNN` with a body chip is the convention for spec / context
  drafts that the shape-lint verifier scans.

---

## Mkdocs-Material Features Authors Can Leverage

The orchestrator's wiki tooling enables a richer mkdocs-material toolkit
than most artifacts use. Authors writing specs, phase plans, proposals,
and decision-log entries should reach for these features when they improve
readability — they're free; they ship with every install via the bundled
`wiki/mkdocs.yml`.

### Mermaid diagrams via `pymdownx.superfences`

Already enabled. Use ` ```mermaid ` fenced blocks for sequence diagrams,
flowcharts, ER diagrams in specs and phase plans:

```text
    ```mermaid
    sequenceDiagram
      participant U as User
      participant O as Orchestrator
      U->>O: orchestrator:auto
      O->>O: dispatch loop
    ```
```

Mermaid renders client-side via mkdocs-material's bundled renderer — no
extra plugin or build step required.

### Content reuse via `pymdownx.snippets`

Already enabled. Use the `--8<--` syntax to include shared boilerplate
from a sibling file once, instead of copy-pasting across artifacts:

```text
    --8<-- "references/payload-shape-snippet.md"
```

Useful for reusable callouts (e.g., "this command is intensity-aware") that
otherwise drift across copies.

### Admonition variants via `admonition`

Already enabled. `note`, `tip`, `warning`, `abstract`, `example`,
`success`, `failure`, and `danger` all render with theme-aware icons:

```text
    !!! warning
        This rule survived three M021 revisions; do not relax casually.
```

Prefer admonitions over bold-italic prose for callouts that survive
multiple revisions — readers visually skip past bold easier than past an
admonition's colored gutter.

### Inline status chips via `attr_list`

Already enabled. Use `attr_list` block-level attributes to attach status
chips and CSS classes to any inline element:

```text
    Migration is **complete**{: .status-chip .status-shipped }.
```

This is the same mechanism the body-chip pattern uses for `DR-CODE-NNN`
display.

### Content tabs via `pymdownx.tabbed`

Already enabled. Use `===` tab markers to lay out side-by-side comparison
panels (e.g., before/after, runtime A vs runtime B):

```text
    === "Claude Code"
        Settings live at `.claude/settings.json`.
    === "Codex CLI"
        Settings live at `.codex/config.toml`.
```

### Collapsible admonitions via `pymdownx.details` (added in M037 P01 T05)

Use `???` instead of `!!!` to make any admonition collapsible. Pairs well
with long evidence sections in phase summaries:

```text
    ??? example "M032 acceptance battery output (collapsible)"
        ```
        BATTERY: pass=10 skip=1 fail=0
        ...
        ```
```

`pymdownx.details` is added by M037/P01/T05's polish-bundle. If this doc
lands before T05 ships, the `???` syntax falls back to plain text until
T05's `markdown_extensions` change merges; the convention itself is stable.

### Task lists via `pymdownx.tasklist` (added in M037 P01 T05)

Use `- [ ]` / `- [x]` to render must-haves, verification steps, or roadmap
progress as clickable checkboxes:

```text
    - [x] Card-grid template emits grid-cards block
    - [ ] DECISIONS.md migrated to new heading shape
```

Renders as visual checkboxes once T05's `pymdownx.tasklist (custom_checkbox: true)`
ships.

### Navigation polish via `navigation.prune` (added in M037 P01 T05)

`navigation.prune` reduces rendered HTML by ~33% on PBJ-central-scale
sidebars (70+ nav entries) by collapsing unselected branches in the served
HTML. No author action required — just write content; the polish bundle
handles the rest.

---

## When to Apply Which Convention

- **Authoring a decision-log entry** → use the heading-shape +
  body-chip + bullet-block pattern. Run `decisions-shape-lint.sh` before
  committing.
- **Authoring a knowledge entry** → use `MEM-NNN`; long-form goes in
  `.orchestrator/knowledge/<category>/MEM<NNN>.md`; short cross-ref goes in
  `KNOWLEDGE.md`.
- **Authoring a spec / phase plan / proposal** → reach for Mermaid
  diagrams, content tabs, admonitions, and (post-T05) collapsible details
  for evidence sections. Inline status chips via `attr_list` for at-a-glance
  state.
- **Authoring background or analysis context** → use `BG-CODE-NNN` /
  `AN-CODE-NNN` with the same body-chip pattern as decisions, but mark the
  entry as advisory in the prose.
- **Capturing an open question** → use `#Q-N` short-form inline in
  proposals, `Q-NNN` long-form with body chip in specs / context drafts.

---

## Cross-References

- `.orchestrator/DECISIONS.md` — every decision-log entry uses the new heading shape.
- `commands/dispatch.md` — payload-guidance reference for LLM-dispatched task agents.
- `wiki/mkdocs.yml` — `markdown_extensions` and `extra_css` declarations.
- `wiki/docs/stylesheets/code-chips.css` — pill styling for body chips.
- `scripts/verify/decisions-shape-lint.sh` — framework-owned shape-lint contract surface.
- `tools/verify/m037-p01-decisions-shape.sh` — phase-suite wrapper.
