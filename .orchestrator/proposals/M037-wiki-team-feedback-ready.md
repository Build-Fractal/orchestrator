# Proposal: M037 — Wiki Team-Feedback-Ready (PBJ Round 3)

**Captured**: 2026-05-06 from PBJ-central-mono-repo round-3 dogfood brief
**Shape**: Pre-launch milestone, two phases (P01 ship-it minimum / P02 round 3.5 polish)
**Predecessors**: M032 (wiki distribution + init integration, closed 2026-05-05), papercut-sweep rounds 1+2 (closed in commits `e4c3c8f7` and `90c18f07`), M036a (reference-corpus pipeline producing the chunks the wiki renders, closed 2026-05-02)
**Source**: PBJ-central-mono-repo round-3 brief (2026-05-06). Rounds 1 and 2 closed the `mkdocs build --strict` blockers (B1–B8). Round 3 surfaces a different class of issue: the wiki **renders correctly but is not yet usable for a non-author**. The operator's stated next step is opening the wiki to the PBJ team (Don / Jenn / Polly + occasional contributors) for feedback this week. Current state would produce noise instead of signal — readers get lost in slug-shaped nav and an operator-onboarding-doc homepage before they reach the content the operator wants feedback on.

## Why this is pre-launch (not a post-launch fast-follow)

The PBJ team is the **live dogfood signal for the entire orchestrator process** — they are the second downstream consumer beyond the orchestrator itself, and the only one currently exercising the full reference-corpus + spec + decision-log + milestone-history surface. Their feedback during the next two weeks shapes whether the orchestrator launches with confidence or with unknowns.

If they open the wiki and the wiki distracts them — slug-soup nav, a homepage that reads like a developer README, code-soup TOCs — the feedback signal degrades from "is the orchestrator process right?" to "the wiki is unusable." That contaminates exactly the validation loop M035-launch is supposed to ride into release.

The post-launch `wiki-ux-deep` proposal (`.orchestrator/proposals/post-launch-wiki-ux-and-adapters.md`) covers differentiated polish (knowledge-graph viewer, faceted search, AI Q&A widget, lifecycle-stage badges). M037 is upstream of that — it's the readability-and-discoverability cut that makes the wiki **usable** at all for non-authors. F3/F5/F1.2 in the PBJ brief were originally noted as candidates for `wiki-ux-deep`; promoting them to M037 narrows the post-launch proposal to its actual differentiated scope.

## Goal

After M037 ships, a non-author reader (PBJ domain SME, validator pilot, occasional contributor) lands on the wiki and:

1. **Homepage gives them a clickable map.** Card-grid landing page with project-defined section blurbs, not an operator README.
2. **Reference nav reads as human-meaningful titles**, not `REF-cms-rule-cms-qso-21-06-nh-2020-12`-shaped slugs.
3. **Decisions TOC reads as scannable concepts**, not a list of `DR-CODE-NNN` codes.
4. **Top-level surfaces are visually first-class** via tabbed navigation, not buried in a sidebar.
5. **Edit / view-source / TOC-depth / install-template polish** all land in the same pass since they touch the same files.

P01 ships the minimum cut that achieves this. P02 lands the medium-effort items (tag-driven nav subgrouping, GitHub source-link rewrite, knowledge page restructure, three optional plugins) after PBJ team's first feedback signal informs the bucket-mapping and section-shape choices.

## Strict scope

This is **wiki tooling readability + discoverability hardening**, not:

- **Knowledge-graph viewer / faceted search / AI Q&A** — `wiki-ux-deep` proposal owns those (post-launch, demand-driven).
- **External-tool adapters (Jira / Notion / Obsidian)** — separate post-launch milestone (`external-tool-adapters` per the same proposal).
- **Validator-audience polish** — round 4, after PBJ team's first feedback signal lands.
- **`include-markdown` redesign** — round 2 closed the rewrite-relative-urls behavior; the include-markdown architecture is sound. Don't redesign.
- **Eliminating DR-### / MEM-### codes from source content** — codes are load-bearing for cross-references and grep-ability. Fix is presentation (heading shape, body chips), not removal.
- **Source-side `version:` → `title:` field rename** — read `version:` at projection time, don't churn the source schema.

## P01 — "PBJ ship-it minimum" (immediate, ~2 days)

The smallest set of changes that fixes failures-of-first-impression for a non-author reader.

### F3 — Card-grid landing page (homepage only)

**Reproducer**: open `/` of any orchestrator-managed wiki. Current `index.md` reads as an operator README — sections "How to navigate", "Where to comment", "Deploy & preview", "Audience scope". Tells the reader the wiki exists; gives no clickable map.

**Fix shape**:

- New template `templates/wiki-index-cards.md.tmpl` emits the mkdocs-material `grid cards` block (already supported via `attr_list` + `md_in_html`, both already enabled — zero new plugin dependencies).
- New config schema in `.orchestrator/config.yml`:
  ```yaml
  wiki:
    landing_cards:
      - section: constitution
        icon: material/gavel
        title: "Constitution"
        blurb: "9 principles that govern PBJ Central. Privacy, source authority, gate enforcement."
      - section: decisions
        icon: material/history
        title: "Decisions"
        blurb: "Architectural decisions, BG-### gate history, milestone shape commitments."
      # ...
  ```
- Default `landing_cards` list when project hasn't customized: one card per top-level nav section, generic blurbs derived from section name.
- Generator reads top-level nav sections from the same source records `wiki-generate-nav.sh` consumes.

**Defer**: `/knowledge/` card-grid (F5 Path A) — moves to P02.

### F1.1 — `version:` → nav title

**Reproducer**: PBJ-central currently has 70+ entries titled `REF-cms-rule-cms-qso-21-06-nh-2020-12`-shaped slugs in one nav section. Same shape across regulatory-doc / training-material / glossary sections. Source chunks have `version:` frontmatter with human-readable labels (`"QSO-21-06-NH (December 4, 2020)"`); the projection layer ignores it.

**Fix shape**:

- `scripts/wiki/wiki-generate-stubs.sh` reads source chunk's `version:` frontmatter, sets stub's `title:` field. Fallback to chunk-id slug when `version:` missing.
- Verify `scripts/wiki/wiki-generate-nav.sh` honors stub frontmatter `title:` (likely already does; if not, teach it).
- Regression fixture under `tests/m037-acceptance/` exercising the `version:` → nav title path on a synthetic chunk with both `version:` present and absent.

### F4.1 — DR-### heading-shape pivot (authoring convention + this repo's own model)

**Reproducer**: open `/decisions/` on any orchestrator-managed project. Right-side TOC reads as a list of `DR-CODE-NNN` codes — the human-readable label trails after the dash and the reader's eye can't find an anchor.

**Fix shape**:

- Edit this repo's own `.orchestrator/DECISIONS.md` from `### DR-CODE-NNN — Human title` to `### Human title { #dr-code-nnn }` with the code rendered as a body chip (small permalink-style suffix) — preserves stable URLs via `attr_list` anchor.
- Promote as orchestrator authoring convention in `references/architecture.md` (or appropriate doc) — applies to DR-### / BG-### / AN-### / MEM-### / Q-### conventions.
- `commands/dispatch.md` payload guidance updated to reference the convention when artifact-authoring tasks emit decision-log entries.

**This is content-side and authoring-convention work** — small surface area in this repo, but generalizes to every consumer project's authoring patterns.

### F6 — `navigation.tabs` + `tabs.sticky`

**Fix shape**: trivial `mkdocs.yml` template change — add `navigation.tabs` and `navigation.tabs.sticky` to `theme.features`. Promotes top-level sections (Constitution / Decisions / Milestones / Knowledge / Reference) to a tabbed header instead of sidebar-only.

### F4.2 — `toc_depth: 2`

**Fix shape**: trivial `mkdocs.yml` template change — `toc.toc_depth: 2`. Drops `####` from TOC; top-level docs (constitution, decisions) become scannable. Granular pages (MEM entries, phase plans) can override per-page via frontmatter when needed.

### F7.1 — `content.action.edit` + `edit_uri`

**Fix shape**: `mkdocs.yml` template change — `content.action.edit` and `content.action.view` features + `edit_uri: edit/main/wiki/docs/` (per-project). `edit_uri` value derived from project's `repo_url` (already in `mkdocs.yml`) at template-emit time.

**Defer**: `mkdocs-git-revision-date-localized-plugin` — net-new plugin dependency, moves to P02.

### Bundled — install-template `config.yml` clobber fix

**Reproducer**: `.orchestrator/proposals/install-template-preserve-operator-keys.md`. PBJ-central re-authors the `wiki:` block in `.orchestrator/config.yml` after every `orchestrator:update`.

**Fix shape**: per the existing proposal — install template merges operator-authored keys instead of clobbering. Bundled into M037 because we're already touching template territory; not bundled into M035 because M035 doesn't touch `config.yml` template emission and bundling there would expand its surface area.

### P01 acceptance criteria (preview — formalized at `orchestrator:specify` time)

- Card-grid homepage renders on PBJ-central with project-defined cards.
- Reference nav titles read as `version:` strings on PBJ-central's reference corpus.
- DECISIONS.md TOC on this repo reads as human concepts.
- `mkdocs build` clean (no new warnings introduced).
- PBJ-central re-runs `orchestrator:update` and the `wiki:` config block survives the install refresh.
- Acceptance battery `tests/m037-acceptance/` covers the projection paths with synthetic fixtures.

## P02 — "round 3.5" (after first PBJ feedback signal, ~2–3 days)

These are real wins but not first-impression blockers. Deferring lets PBJ team's review feedback inform the bucket-mapping and section-shape choices before we lock them.

### F1.2 — Tag-driven nav subgrouping

`wiki-generate-nav.sh` reads `topic_tags:` from each chunk, groups into buckets via deterministic config-driven mapping. Example: `qso` → "QSO letters", `pbj-policy-manual` → "Policy manuals & FAQs". Recommend cheap path (tag-driven in nav-generator, config-yml-driven mapping) over `mkdocs-awesome-pages-plugin` adoption — defer the plugin unless tag-driven grouping doesn't generalize cleanly to regulatory-doc / training-material sections.

Compose with `navigation.collapse` + `navigation.prune` mkdocs.yml features once subgroups exist.

### F2 — GitHub source-link rewrite (Tier 0 metadata + Tier 1 sidebar)

When stub generator's B7 metadata-table fallback emits `external_pointer:`, transform `file://<repo-root>/<rel-path>` → `<repo_url>/blob/<default-branch>/<rel-path>`. Read `repo_url` from `mkdocs.yml`; default branch from `git symbolic-ref refs/remotes/origin/HEAD` with fallback to `main`. Pass-through when `external_pointer:` doesn't resolve under project root.

Apply to **both Tier 0 chunks** (where the metadata table is the only pointer to source) and **Tier 1 chunks** (where extracted plaintext renders but readers may want the original PDF for layout / figures / signed letterhead).

### F5 — Knowledge page card grid (Path A)

`/knowledge/` becomes a reader-friendly card grid (same template as F3). Major knowledge areas surfaced as cards (analysis schema, glossary, copy library, source-doc registry, etc.). The auto-projected `knowledge.md` content remains accessible at a power-user URL (`/knowledge/_index/` or similar — final shape decided after PBJ feedback). Path B (preserved hand-authored summary) and Path C (explicit reader/author split) deferred unless PBJ signal calls for them.

### F7.2 — `mkdocs-git-revision-date-localized-plugin`

Adds last-modified timestamps from git history. Reader-trust signal. Net-new plugin dependency — install bundle adds it to the wiki Python toolchain.

### `mkdocs-tags` plugin

Auto-generates `/tags/<tag>/` topic-pivot pages from `tags:` frontmatter. Composes with F1.2 nav grouping (structured nav by document family + tag index by topic = dual win). Requires `topic_tags:` → `tags:` adapter at projection time (don't churn source schema).

### `mkdocs-redirects` plugin

Insurance against future renames. Adopt before team adoption ramps and bookmarks accumulate.

## Sequencing rationale

P01 lands first as a single PR / single dogfood iteration. PBJ team enters wiki immediately after merge. P02 lands after their first feedback signal (likely 3–5 days post-P01-merge) — enough time to surface bucket-mapping preferences and section-shape feedback before locking F1.2 / F5 design.

M037 jumps the queue ahead of M035 P00+P01 because M035 has no external deadline (dev-ergonomics: `--mode=symlink` install + version-drift warning are internal velocity); M037 P01 has an external deadline (PBJ team feedback this week).

M037 runs **parallel to** the existing pre-launch operational follow-ups:
- **M036a P03 live-LLM smoke test** (≤ 2026-05-08) — independent surface area (extraction pipeline), runs in parallel.
- **M033 friendly-tester pass** (≤ 2026-05-12) — independent surface area (init UX), runs in parallel.

After M037 P01 ships and PBJ team enters the wiki, M037 P02 follows on first feedback signal. M035 P00+P01 follows after that. M035 P02–P06 IS the launch event.

## Out of scope for M037

- mkdocs theme swap. Recommendation: stay on mkdocs-material — covers everything needed for an internal team wiki / regulatory reference / decision log.
- Custom theme build. Disproportionate cost.
- Heavy `mkdocs-awesome-pages-plugin` adoption before tag-driven grouping is tested.
- Eliminating codes (DR-### / MEM-### / BG-###) from source content.
- `include-markdown` architecture redesign.
- Source-side `version:` → `title:` field rename.
- Validator-audience polish (round 4).
- Knowledge-graph viewer, faceted search, AI Q&A, lifecycle-stage badges (`wiki-ux-deep` proposal).
- External-tool adapters (`external-tool-adapters` proposal).

## Open questions for the eventual full brief

1. **P01 scope creep guard** — F3 card-grid template + `wiki.landing_cards:` config schema is the medium-effort item in P01. Should the schema be minimal-viable (icon + title + blurb + section, no advanced features like cards-per-row, card-color, badge-overlay) for P01, with extensions deferred to P02 / round 4?
2. **Default landing-card content** — when a project hasn't customized `wiki.landing_cards:`, what generic blurbs ship? Auto-generate from section name (`"Constitution"` → `"Project constitution. <section_count> principles."`)? Or hand-authored generic strings keyed on section name?
3. **F4.1 authoring convention rollout** — does the heading-shape pivot apply retroactively to existing `.orchestrator/DECISIONS.md` content across consumer projects (operator runs a one-shot rewriter), or only to new entries authored after the convention lands?
4. **`config.yml` clobber fix scope** — does the install template merge logic apply to all operator-authored top-level keys, or only to the `wiki:` block (the immediate pain point)? Bundling broader merge logic risks expanding M037 surface area.
5. **`wiki:` config schema versioning** — once `landing_cards:` lands as a real schema, do we owe schema-evolution handling for projects on older configs? Or accept "missing key = use defaults" as the forward-compat strategy?
6. **P02 trigger condition** — does P02 ship on a calendar trigger (e.g., 5 days after P01 merge regardless), or strictly after PBJ team has filed at least N concrete pieces of nav-or-section-shape feedback?

## Predecessors / hard dependencies

- **M032** (wiki distribution + init integration, closed 2026-05-05) — provides the `scripts/wiki/`, `mkdocs.yml` template, install-template plumbing M037 modifies.
- **M036a** (reference-corpus pipeline, closed 2026-05-02) — produces the chunks (with `version:` and `topic_tags:` frontmatter) that F1.1 / F1.2 / F2 read at projection time.
- **Papercut-sweep rounds 1+2** (in commits `e4c3c8f7` and `90c18f07`) — closed B1–B8 build-strict blockers; M037 starts from a clean-rendering baseline.

No blocking dependencies on M033, M035, or M036b. M037 P01 ships standalone.

## Concrete next step

`orchestrator:specify M037` consumes this brief as input. Spec authoring then evaluates → roadmap (likely 2 phases mapped 1:1 to P01 / P02) → plan-phase P01 → execute → verify → consolidate. P02 enters planning after PBJ team's first feedback signal lands.
