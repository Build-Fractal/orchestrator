---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M037"
name: "Card-grid surface end-to-end (FR-1 + FR-2 + FR-3 + FR-4)"
depends_on: []
---

## Prerequisites

- `templates/orchestrator-config-default.yml` exists (verified at plan-authoring time, line 1+).
- `scripts/wiki/wiki-generate-stubs.sh` exists (verified at plan-authoring time).
- `scripts/wiki/wiki-generate-nav.sh` exists (verified at plan-authoring time).
- `wiki/docs/index.md` may or may not exist on disk — handler is idempotent overwrite when in self-application path.
- `wiki/mkdocs.yml` already enables `attr_list` + `md_in_html` + `pymdownx.superfences` (verified by Read of `wiki/mkdocs.yml:38-50`) — zero new mkdocs plugin deps required (CON-1).

## Description

Lands the card-grid homepage end-to-end. Authors a new `templates/wiki-index-cards.md.tmpl` (mkdocs-material `grid cards` block), adds the `wiki.landing_cards:` schema to the framework config-default file, extends `scripts/wiki/wiki-generate-stubs.sh` with a `render_landing_cards` step that reads the schema from `.orchestrator/config.yml` (or derives defaults from the top-level nav sections enumerated by `wiki-generate-nav.sh`), and writes the rendered card-grid block into `wiki/docs/index.md`. Closes US-1 acceptance scenarios 1-4 (with US-1 AS-4 closing only after T06 ships the FR-10 clobber fix).

The schema is **minimal-viable per #Q-1 resolution**: `section`, `icon`, `title`, `blurb`. Extensions (cards-per-row, color, badge-overlay) are P02/round-4 territory.

Default-fallback content (#Q-2 resolved): **hand-authored generic strings keyed on section name** — the section→blurb mapping is a sibling table at the top of `templates/wiki-index-cards.md.tmpl` (a `# DEFAULT_BLURBS` comment block parsed by the renderer). More robust than auto-generation against unknown section names.

## Steps

1. **Author `templates/wiki-index-cards.md.tmpl`**. The template is a mkdocs-material grid-cards block (`attr_list` + `md_in_html` already enabled — no new plugin deps). The shape:

   ```markdown
   <!--
   templates/wiki-index-cards.md.tmpl — M037/P01/T01 FR-1 card-grid template.
   Consumed by scripts/wiki/wiki-generate-stubs.sh::render_landing_cards.

   DEFAULT_BLURBS section-name → blurb mapping (used when wiki.landing_cards:
   is absent or empty per FR-3). Section names match top-level nav entries
   enumerated by wiki-generate-nav.sh.

   # DEFAULT_BLURBS
   # Constitution|fontawesome/solid/scale-balanced|Project constitution. Governing principles for every decision.
   # Decisions|fontawesome/solid/list-check|Decision log. Architectural choices, rationale, revision history.
   # Glossary|fontawesome/solid/book|Project glossary. Terms and one-line definitions.
   # Knowledge|fontawesome/solid/lightbulb|Knowledge entries. Patterns, conventions, lessons.
   # Milestones|fontawesome/solid/flag-checkered|Milestone summary. Per-milestone phases, tasks, outcomes.
   # Reference|fontawesome/solid/folder-tree|Reference corpus. Regulatory docs, training materials, glossaries.
   # Proposals|fontawesome/solid/pen-to-square|Proposal drafts and historical proposals.
   # END_DEFAULT_BLURBS
   -->

   <div class="grid cards" markdown>

   {{#each cards}}
   - :{{icon}}: **{{title}}**

       ---

       {{blurb}}

       [:octicons-arrow-right-24: {{title}}]({{section}})

   {{/each}}

   </div>
   ```

   The template is consumed by a bash renderer (no Mustache/Jinja runtime required) — the renderer iterates `cards` and emits the grid-cards block via `printf`. The handlebars-style braces above are documentation only; the renderer recognizes the `<!--` `# DEFAULT_BLURBS` block and substitutes literally.

2. **Add `wiki.landing_cards:` schema to `templates/orchestrator-config-default.yml`**. Append at end of file (after line 157):

   ```yaml

   # M037 — Wiki team-feedback-ready (FR-2)
   # The wiki: namespace is orchestrator-managed (operator-authored values for
   # any keys NOT enumerated in the framework default are preserved by the
   # FR-10 yaml-merge primitive, but new orchestrator-managed keys added in
   # future releases will merge under wiki:).
   #
   # landing_cards: drives the homepage card grid. Each entry declares
   # section (path to a top-level nav section), icon (mkdocs-material icon
   # ID), title (string), blurb (string). When the list is empty, the stub
   # generator falls back to defaults derived from the top-level nav sections
   # (FR-3). Operators customize this list to point readers at the content
   # they want feedback on.
   wiki:
     landing_cards: []             # M037 FR-2 — operator-customizable card list
   ```

3. **Add `render_landing_cards` step to `scripts/wiki/wiki-generate-stubs.sh`**. The step:
   - Reads `.orchestrator/config.yml` for the `wiki.landing_cards:` block (use the existing config-reader pattern — likely `scripts/state/read-config.sh` or inline grep/sed parsing). On absent/empty list: enumerate top-level nav sections from the existing `wiki-generate-nav.sh` data source (or by reading `wiki/mkdocs.yml`'s `nav:` block via `scripts/wiki/wiki-scan-sources.sh` if present), and synthesize one card per section by looking up the section name in the `DEFAULT_BLURBS` mapping inside `templates/wiki-index-cards.md.tmpl`.
   - For each card, validate the `section:` value resolves to a real top-level nav section. On miss: render the card with placeholder href `#orphan-card-{name}` and emit a build-time diagnostic to stderr (per US-1 AS-3 — does not fail the build).
   - Renders the grid-cards block by direct string concatenation (bash 3.2 + POSIX sh per MEM001) and writes it to `wiki/docs/index.md`. Preserve any leading content of `wiki/docs/index.md` BEFORE a sentinel marker (`<!-- M037-LANDING-CARDS-BEGIN -->` ... `<!-- M037-LANDING-CARDS-END -->`); replace only the bracketed region. On first run (sentinels absent), prepend the block at top of file. Idempotent re-runs.
   - When `wiki.landing_cards:` is empty AND the project has zero top-level nav sections (US-1 Edge Case "Card-grid template renders with no cards"): no card grid emitted, `wiki/docs/index.md` retains legacy content byte-identical.

4. **Author `tools/verify/m037-p01-card-grid.sh`** (Truth #1 verifier). Single-script-file shape, AD-19 compliant. The verifier:
   - Asserts `templates/wiki-index-cards.md.tmpl` exists and contains `grid cards`.
   - Asserts `templates/orchestrator-config-default.yml` contains `landing_cards:` under a `wiki:` block.
   - Asserts `scripts/wiki/wiki-generate-stubs.sh` contains a `render_landing_cards` token (function name or comment marker).
   - Asserts `wiki/docs/index.md` (this repo's own dogfood index) contains a `<div class="grid cards"` opening tag (post-execution; if running before stub generator has been invoked, asserts the sentinel markers `M037-LANDING-CARDS-BEGIN` exist OR the file is unchanged from baseline).

5. **Author `tests/m037-acceptance/p01-card-grid-homepage.sh`** (acceptance test, SC-1). Exercises the synthetic fixture path: writes a temp `.orchestrator/config.yml` under a fixture dir with three landing-card entries, invokes the stub generator against the fixture, asserts the rendered index.md contains exactly three card divs with the configured icon + title + blurb + section href. Then re-runs against a second fixture with no `wiki.landing_cards:` and asserts default cards are emitted (one per top-level nav section).

## Must-Haves

- Truth #1 (card-grid template emits grid-cards block per declared schema entry).
- Phase artifacts: `templates/wiki-index-cards.md.tmpl`, `tests/m037-acceptance/p01-card-grid-homepage.sh`.
- Phase Key Link: `scripts/wiki/wiki-generate-stubs.sh` → `templates/wiki-index-cards.md.tmpl`.
- SC-1 acceptance test passes.

## Verification

```bash
bash tools/verify/m037-p01-card-grid.sh
bash tests/m037-acceptance/p01-card-grid-homepage.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M037/phases/P01
```

## Notes

- Expected output of `tools/verify/m037-p01-card-grid.sh`: `PASS: m037-p01-card-grid (4/4)`.
- Expected output of `tests/m037-acceptance/p01-card-grid-homepage.sh`: a final line `PASS: p01-card-grid-homepage` after both fixture cases pass.
- `check-must-haves.sh` will not yet pass for the full phase until T06 ships the acceptance battery aggregator and other tasks complete; this task only contributes Truth #1, the card-grid template artifact, and the SC-1 fixture.
- Do NOT use `run-probe.sh` to invoke the verifier — it lives under `tools/verify/`, not under `/tmp` (Plan-Time Discipline rule 4).

## Inputs

### From Previous Tasks

(none — T01 is a leaf task in the dependency graph)

### From Disk (Pre-existing)

- `templates/orchestrator-config-default.yml` — appended-to with the new `wiki.landing_cards:` schema entry. Existing content (lines 1-157) preserved byte-identical above the appended block.
- `scripts/wiki/wiki-generate-stubs.sh` — extended with `render_landing_cards` step. Existing functions and entry points remain callable.
- `scripts/wiki/wiki-generate-nav.sh` — read-only; provides the top-level nav section enumeration consumed by the FR-3 fallback path.
- `wiki/mkdocs.yml` — read-only at this task; provides the existing `nav:` block as data source for the FR-3 fallback path. (Polish-bundle additions to `wiki/mkdocs.yml` are owned by T05, not T01.)
- `wiki/docs/index.md` — modified (or created if absent) with the rendered grid-cards block bracketed by `M037-LANDING-CARDS-BEGIN` / `M037-LANDING-CARDS-END` sentinels.

## Constraints

- **CON-1 — Zero new mkdocs plugin dependencies in P01**: this task uses `attr_list` + `md_in_html` (already enabled) + `pymdownx.superfences` (already enabled — covers Mermaid/admonition variants). No `requirements.txt` modifications; no new `plugins:` entries in `mkdocs.yml`.
- **CON-2 — Projection-not-source-mutation**: `render_landing_cards` reads `wiki.landing_cards:` from `.orchestrator/config.yml` and writes only to `wiki/docs/index.md`. Source chunks under `knowledge/` / `references/` / etc. are NOT touched.
- **CON-3 — Operator-authored keys survive**: the `wiki.landing_cards:` block in `templates/orchestrator-config-default.yml` ships as an empty list. T06's yaml-merge primitive ensures operator customizations to `wiki.landing_cards:` survive `orchestrator:update` refreshes.
- **MEM001 — bash 3.2 + POSIX sh compatible**: no associative arrays, no process substitution, no command substitution containing pipes. Single-script-file shape per AD-19.
- **AD-19 — Verifier shape**: project-owned verifier under `tools/verify/m037-p01-card-grid.sh` (milestone-prefixed slug). Single-script-file invocation only. No inline compound bash, no plain subshells, no `$()` containing pipes.

## Expected Output

- `templates/wiki-index-cards.md.tmpl` exists with the `grid cards` block + `DEFAULT_BLURBS` mapping (≥ 5 lines, contains "grid cards").
- `templates/orchestrator-config-default.yml` contains `wiki:` → `landing_cards: []` block.
- `scripts/wiki/wiki-generate-stubs.sh` contains a `render_landing_cards` step that reads schema, validates section paths, and writes the rendered block to `wiki/docs/index.md` with sentinel markers.
- `wiki/docs/index.md` contains a `<div class="grid cards"` block (after the stub generator is invoked).
- `tools/verify/m037-p01-card-grid.sh` exits 0 with `PASS:` summary line.
- `tests/m037-acceptance/p01-card-grid-homepage.sh` passes both fixture cases with a `PASS: p01-card-grid-homepage` final line.
