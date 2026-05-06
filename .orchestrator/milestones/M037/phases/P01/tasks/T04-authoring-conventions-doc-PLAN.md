---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M037"
name: "Authoring conventions doc + dispatch payload-guidance reference"
depends_on: ["T03"]
---

## Prerequisites

- T03 has restructured `.orchestrator/DECISIONS.md` to the new heading shape (this task uses the migrated file as an exemplar reference).
- `commands/dispatch.md` exists (verified at plan-authoring time).
- `wiki/mkdocs.yml` enables `attr_list`, `md_in_html`, `pymdownx.superfences`, `pymdownx.snippets`, `admonition`, `pymdownx.tabbed` (verified at plan-authoring time, lines 38-52). `pymdownx.details` and `pymdownx.tasklist` are added by T05's polish-bundle work, not this task — but the doc references them as authoring conventions because T05's plan ships in the same phase.

## Description

Authors `references/authoring-conventions.md` covering two audiences in one doc per #Q-3 (b) resolution: (a) DR/BG/AN/MEM/Q-### code conventions explaining the new heading shape from T03 and the rationale for code-as-body-chip; (b) already-enabled mkdocs-material features authors should leverage when writing content the orchestrator consumes (Mermaid via superfences, content reuse via snippets, admonition variants, attr_list inline status chips, content tabs via tabbed, and the new `pymdownx.details` collapsible admonitions + `pymdownx.tasklist` checkboxes added by T05).

Updates `commands/dispatch.md` payload-guidance section to reference the new doc so future LLM-dispatched task agents emit decision-log entries in the new heading shape AND can leverage the richer authoring toolkit (Mermaid in spec/plan diagrams, collapsible details for evidence sections, etc.).

## Steps

1. **Read T03's migrated `.orchestrator/DECISIONS.md`** to ground the exemplar excerpt. Pick one entry (e.g., D001 or a small-rationale entry) to use as a verbatim "before/after" pair in the doc.

2. **Author `references/authoring-conventions.md`** with the following section structure:

   ```markdown
   # Authoring Conventions

   How to write content the orchestrator consumes — applies to artifact authors
   (humans and LLM-dispatched task agents alike). This doc covers code
   conventions for decision/background/analysis/memory/question entries plus
   already-enabled mkdocs-material features that make content render well in
   the wiki without churning source schemas.

   ## Code Conventions for Decision-Log Entries

   ### Heading shape

   The orchestrator's decision log (`.orchestrator/DECISIONS.md`) uses
   `DR-CODE-NNN` codes as load-bearing cross-reference anchors. The legacy
   shape `### DR-CODE-NNN — Human title` reads as code-soup in the right-side
   TOC. The new shape leads with the human concept and renders the code as a
   body chip:

       ### Migration to standalone mode { #dr-code-015 }

       <span class="md-tag md-tag-icon md-tag--decision">DR-CODE-015</span>
       {: .code-chip-row }

       - **When**: M015/P02
       - **Scope**: ...

   The `{ #dr-code-nnn }` anchor preserves cross-reference URLs verbatim
   (mkdocs-material's `attr_list` extension handles the anchor).

   ### Code prefixes

   - `DR-CODE-NNN` — orchestrator decision-log entries (`.orchestrator/DECISIONS.md`).
   - `BG-CODE-NNN` — background-context entries.
   - `AN-CODE-NNN` — analysis entries.
   - `MEM-NNN` — knowledge entries (`.orchestrator/knowledge/<category>/MEM*.md`).
   - `Q-NNN` — open-question entries in spec / phase-context drafts.

   The body-chip pattern (`<span class="md-tag md-tag-icon md-tag--decision">CODE</span>`)
   is uniform across prefixes; only the modifier class changes (`--decision`,
   `--background`, `--analysis`, `--knowledge`, `--question`).

   ### When to use each prefix

   ...

   ## Mkdocs-Material Features Authors Can Leverage

   The orchestrator's wiki tooling enables a richer mkdocs-material toolkit
   than most artifacts use. Authors writing specs, phase plans, proposals,
   and decision-log entries should reach for these features when they
   improve readability:

   ### Mermaid diagrams via `pymdownx.superfences`

   Already enabled. Use ` ```mermaid ` fenced blocks for sequence diagrams,
   flowcharts, ER diagrams in specs and phase plans:

       ```mermaid
       sequenceDiagram
         participant U as User
         participant O as Orchestrator
         U->>O: orchestrator:auto
         O->>O: dispatch loop
       ```

   ### Content reuse via `pymdownx.snippets`

   Already enabled. Use the `--8<--` syntax to include shared boilerplate
   from a sibling file once, instead of copy-pasting across artifacts:

       --8<-- "references/payload-shape-snippet.md"

   ### Admonition variants via `admonition`

   Already enabled. `note`, `tip`, `warning`, `abstract`, `example`,
   `success`, `failure`, and `danger` all render with theme-aware icons:

       !!! warning
           This rule survived three M021 revisions; do not relax casually.

   ### Inline status chips via `attr_list`

   Already enabled. Use `attr_list` block-level attributes to attach status
   chips and CSS classes to any inline element:

       Migration is **complete**{: .status-chip .status-shipped }.

   ### Content tabs via `pymdownx.tabbed`

   Already enabled. Use `===` tab markers to lay out side-by-side comparison
   panels (e.g., before/after, runtime A vs runtime B):

       === "Claude Code"
           Settings live at `.claude/settings.json`.
       === "Codex CLI"
           Settings live at `.codex/config.toml`.

   ### Collapsible admonitions via `pymdownx.details` (added in M037 P01 T05)

   Use `???` instead of `!!!` to make any admonition collapsible. Pairs well
   with long evidence sections in phase summaries:

       ??? example "M032 acceptance battery output (collapsible)"
           ```
           BATTERY: pass=10 skip=1 fail=0
           ...
           ```

   ### Task lists via `pymdownx.tasklist` (added in M037 P01 T05)

   Use `- [ ]` / `- [x]` to render must-haves, verification steps, or
   roadmap progress as clickable checkboxes:

       - [x] Card-grid template emits grid-cards block
       - [ ] DECISIONS.md migrated to new heading shape

   ### Navigation polish via `navigation.prune` (added in M037 P01 T05)

   `navigation.prune` reduces rendered HTML by ~33% on PBJ-central-scale
   sidebars (70+ nav entries) by collapsing unselected branches in the
   served HTML. No author action required — just write content; the polish
   bundle handles the rest.

   ## When to Apply Which Convention

   ...

   ## Cross-References

   - `.orchestrator/DECISIONS.md` — every decision-log entry uses the new heading shape.
   - `commands/dispatch.md` — payload-guidance reference for LLM-dispatched task agents.
   - `wiki/mkdocs.yml` — markdown_extensions list.
   ```

   The doc MUST be ≥ 100 lines and MUST contain the literal strings `DR-CODE-NNN`, `navigation.prune`, `pymdownx.details`, and `Mermaid` for the artifact-shape verifier.

3. **Update `commands/dispatch.md` payload-guidance section**. Find the section that documents what authoring guidance to inject into dispatched task payloads (likely near the bottom of the file, possibly under a `## Payload Guidance` or `## Knowledge Inject` header). Add a paragraph:

   > **Authoring conventions**: dispatched task agents authoring decision-log
   > entries (DR-CODE-NNN), knowledge entries (MEM-NNN), or other code-anchored
   > artifacts MUST follow the heading-shape and body-chip conventions documented
   > in `references/authoring-conventions.md`. The doc also covers
   > already-enabled mkdocs-material features (Mermaid, collapsible details,
   > task lists, content tabs) that improve artifact readability without
   > requiring schema changes. Reference this doc in the dispatch payload
   > knowledge-inject for any task whose deliverables include decision/knowledge
   > entries or wiki-rendered prose.

   The exact placement and prose may flex; the verifier asserts only that
   `commands/dispatch.md` contains the literal string `references/authoring-conventions.md`.

4. **Author `tools/verify/m037-p01-authoring-conventions-doc.sh`** (Truth #8 verifier). Asserts:
   - `references/authoring-conventions.md` exists.
   - File has ≥ 100 lines.
   - File contains all four required substrings (`DR-CODE-NNN`, `navigation.prune`, `pymdownx.details`, `Mermaid`).
   - File contains a `## Code Conventions` section header.
   - File contains a `## Mkdocs-Material Features` section header.

5. **Author `tools/verify/m037-p01-dispatch-references-conventions.sh`** (Truth #9 verifier). Asserts `commands/dispatch.md` contains the literal string `references/authoring-conventions.md`.

## Must-Haves

- Truth #8 (`references/authoring-conventions.md` covers DR/BG/AN/MEM/Q codes + already-enabled features).
- Truth #9 (`commands/dispatch.md` references the new convention doc).
- Phase artifact: `references/authoring-conventions.md` (min 100 lines, contains "DR-CODE-NNN", "navigation.prune", "pymdownx.details", "Mermaid").
- Phase Key Links: `commands/dispatch.md` → `references/authoring-conventions.md`; `references/authoring-conventions.md` → `.orchestrator/DECISIONS.md`.

## Verification

```bash
bash tools/verify/m037-p01-authoring-conventions-doc.sh
bash tools/verify/m037-p01-dispatch-references-conventions.sh
```

## Notes

- Expected output of `tools/verify/m037-p01-authoring-conventions-doc.sh`: `PASS: m037-p01-authoring-conventions-doc (5/5)`.
- Expected output of `tools/verify/m037-p01-dispatch-references-conventions.sh`: `PASS: m037-p01-dispatch-references-conventions`.
- The `pymdownx.details` and `pymdownx.tasklist` references in this doc anticipate T05's polish-bundle additions; if the doc lands before T05's `wiki/mkdocs.yml` change, the doc still verifies (the verifier checks for the literal string, not for runtime feature availability). On phase close, both ship together.

## Inputs

### From Previous Tasks

- `.orchestrator/DECISIONS.md` (from T03)
  - Key API: file is the new-heading-shape exemplar. Read one entry verbatim to use as before/after pair in this doc.
  - Key types: markdown headings of shape `### Title { #dr-code-nnn }` followed by `<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-NNN</span>` body chip.

### From Disk (Pre-existing)

- `commands/dispatch.md` — modified to add the authoring-conventions reference paragraph.
- `wiki/mkdocs.yml` — read-only; verifies which `markdown_extensions` are already enabled (informs the "already-enabled features" section content).

## Constraints

- **MEM001 — bash 3.2 + POSIX sh** in the verifiers.
- **AD-19 — Verifier shape**: `tools/verify/m037-p01-authoring-conventions-doc.sh` and `tools/verify/m037-p01-dispatch-references-conventions.sh` are project-owned, milestone-prefixed, single-script-file shape.
- **No new plugins**: this task is doc-only; no `requirements.txt` or `mkdocs.yml plugins:` change. The doc's references to `pymdownx.details` + `pymdownx.tasklist` describe T05's additions, not this task's.

## Expected Output

- `references/authoring-conventions.md` exists with both major sections (code conventions + mkdocs-material features), ≥ 100 lines, all four required substrings present.
- `commands/dispatch.md` contains the literal string `references/authoring-conventions.md`.
- `tools/verify/m037-p01-authoring-conventions-doc.sh` exits 0.
- `tools/verify/m037-p01-dispatch-references-conventions.sh` exits 0.
