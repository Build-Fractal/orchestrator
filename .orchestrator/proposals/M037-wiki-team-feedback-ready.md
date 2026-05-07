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

### F8 — `feedback/` routing arm in `wiki-generate-stubs.sh`

**Source**: `.orchestrator/proposals/papercut-sweep-wiki-deploy-2026-05-07.md` finding #1.

**Reproducer**: `KNOWLEDGE.md` cross-links to `feedback/<file>.md`. The wiki-deploy link-checker (correctly) treats those as in-scope and FAILs because no stubs exist at `wiki/docs/feedback/`. PBJ-central operator hand-scaffolded two stubs to get past gate 2.

**Fix shape**: new routing arm `feedback:<basename>` mirroring `proposals:*` (lines ~1056-1071) — stubs land at `wiki/docs/feedback/<basename>.md`, canonical source at `.orchestrator/feedback/<basename>.md`, fragment-only passthrough (`rewrite-relative-urls=false` per B5 precedent). Title-derivation fallback: feedback files don't carry `version:` the way reference-corpus chunks do — derive title from H1 of the source file; fall back to humanized basename when H1 absent. Section index emission via `register_child` so `wiki-generate-nav.sh` surfaces the bucket without manual `nav:` edits. Bundled into M037 P01 because we're already touching `wiki-generate-stubs.sh` for F1.1 (`version:` → nav title) — same file, same projection-time logic, same kind of fix.

**Severity**: medium. Bites every project past BG-001-style validation gates — `.orchestrator/feedback/` is the standard location for round-by-round SME signoff captures.

### F9 — `wiki-deploy.sh` Pages-rebuild verification — **SUPERSEDED by F12**

**Status**: SUPERSEDED 2026-05-07 by F12 (workflow-based publishing). F9 was a workaround for the legacy `pages-build-deployment` builder's stuck-queue failure mode — poll `gh api .../pages/builds/latest` after `git push origin gh-pages` for confidence the legacy builder rebuilt. F12 stops using the legacy builder entirely (deploys flow through `actions/deploy-pages` workflow triggered by push to main); there is no longer a gh-pages branch push to verify, and the legacy builder's stuck-queue mode is bypassed entirely. F9's operator-confidence intent transfers to F12: the new `wiki-deploy.sh` print-and-exit replacement surfaces the workflow URL, and operators get full Actions observability.

**Original source**: `.orchestrator/proposals/papercut-sweep-wiki-deploy-2026-05-07.md` finding #2 — kept as historical context. Acceptance criterion derived from F9 in P01 is replaced by F12's workflow-mode acceptance.

### F10 — `wiki-deploy` OUT-OF-SCOPE output collapse

**Source**: `.orchestrator/proposals/papercut-sweep-wiki-deploy-2026-05-07.md` finding #5.

**Reproducer**: PBJ-central deploy emits 178 `OUT-OF-SCOPE: ... -> https://github.com/.../discussions [external]` lines (one per page, all pointing at the same giscus discussions URL). Drowns the actionable signal (in-scope link checks, gate status, projection counts).

**Fix shape**: detect repeated OUT-OF-SCOPE patterns (same target URL across many source pages) and collapse to a single summary line: `OUT-OF-SCOPE: 178 pages -> https://github.com/.../discussions [external giscus]`. Keep first 3-5 unique OUT-OF-SCOPE targets as full lines for diagnostic context; collapse the rest to `(+N more)`. Honor `--verbose` flag to disable collapsing for debugging. Compounds with F9: an operator who can't find the actionable lines is more likely to misread a stale deploy as fresh.

**Severity**: low (output noise) but compounds with F9.

### F11 — `wiki/README.md` org-level discussions redirect callout

**Source**: `.orchestrator/proposals/papercut-sweep-wiki-deploy-2026-05-07.md` finding #7.

**Reproducer**: when the org has org-level Discussions enabled, `https://github.com/<Org>/<Repo>/discussions` 302s to `https://github.com/orgs/<Org>/discussions`. The repo's discussions still work via API and giscus, but the operator UX is confusing — "create category" UI lives at the org level until the operator navigates to the repo discussions categories management URL directly.

**Fix shape**: docs-only callout in `wiki/README.md` § "First-deploy checklist" pointing operators at `https://github.com/<Org>/<Repo>/discussions/categories` for category management when the org-level redirect catches them. Two paragraphs, no code change.

**Severity**: docs-only. Save the next operator the same dead-end the PBJ-central operator hit on 2026-05-07.

### F12 — Workflow-based Pages publishing scaffold (supersedes F9)

**Source**: `.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md` Gap 1.

**Reproducer**: `scripts/wiki/wiki-deploy.sh` calls `mkdocs gh-deploy --force` against the `gh-pages` branch. GitHub's legacy `pages-build-deployment` builder can wedge into a `queued` state that no documented API will let you cancel, force-cancel, or delete — `gh run cancel`, `gh api -X POST .../force-cancel`, `gh api -X DELETE .../runs/<id>`, `gh api -X DELETE repos/.../pages`, and toggling `build_type` between `legacy`/`workflow`/`legacy` all refuse. New pushes to `gh-pages` deduplicate against the zombie run and never build. PBJ-central dogfood lived through a 7-day stuck deploy (run `25145703975`) before giving up on the legacy builder.

**Severity**: HIGH. Every operator is one stuck-builder away from the same 7-day outage. The deploy primitive must not depend on a builder with no recovery API.

**Fix shape (4 sub-patches that ship together)**:

1. **Scaffold `.github/workflows/pages.yml`** — `wiki-init.sh` emits a workflow file using `actions/configure-pages@v5` + `actions/upload-pages-artifact@v3` + `actions/deploy-pages@v4`, triggered on `push: branches: [main]` + `workflow_dispatch`. Reference impl from dogfood commit `e7a722e` in `pbj-central-mono-repo`. End-to-end timing: ~50s build + ~10s deploy, total ~1 min from push to live. Verbatim YAML preserved in the handoff doc.
2. **Set `build_type: workflow` during init** — after the workflow is staged, call `gh api -X PUT "repos/$OWNER/$REPO/pages" -f build_type=workflow`. If `gh` is unavailable / unauthenticated, print a clear manual fallback with the same command for the operator.
3. **Demote `wiki-deploy.sh` live path** — keep gates 1-4 (giscus-config-check + mkdocs build + link-check + giscus-smoke) as local pre-push validation. Drop gate 5 (`mkdocs gh-deploy --force`). Replace with a print of the workflow URL + `git push origin main` instruction. M032 wiki-deploy quickstart docs need updating to match.
4. **Confirm `wiki/requirements.txt`** — workflow's `pip install -r wiki/requirements.txt` consumes it. If the scaffold doesn't already emit it, add with the same pinned deps the existing tooling uses.

**Acceptance**: fresh-install fixture produces `.github/workflows/pages.yml`; repo's Pages config shows `build_type: workflow`; `scripts/wiki/wiki-deploy.sh` no longer runs `mkdocs gh-deploy` on the live path; pushing to main triggers a `Deploy wiki to Pages` workflow run within ~10s that completes within ~2 min; no `pages-build-deployment` legacy runs are created. Test scaffold `tests/test-wiki-init-workflow-mode.sh` in the handoff doc.

### F13 — Private-repo `site_url` visibility branch

**Source**: `.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md` Gap 2.

**Reproducer**: scaffolded `wiki/mkdocs.yml` writes `site_url: https://<org>.github.io/<repo>/` derived from `repo_url`. mkdocs-material's `404.html` uses **absolute asset paths derived from `site_url`** (regular doc pages use relative paths and work fine). Public repos serve at `<org>.github.io/<repo>/` so the absolute paths resolve. Private repos (Pro/Team/Enterprise plans, including the dogfood project) serve at a randomized `<random>.pages.github.io/` URL **without the `/<repo>/` prefix**. Real pages render styled (relative paths). 404 pages render as a column of giant unstyled SVG icons — no copy, no theme, no layout. Looks like a CSS deployment failure; isn't.

**Severity**: medium-high. Operators hit 404s often, especially during stub-emission gaps (M037 P02 corpus-surface work-in-flight is a current source). The unstyled 404 reads as "deploy is broken" when actually only the asset paths are wrong. Currently visible to PBJ team members on every broken nav click.

**Fix shape**: `scripts/lifecycle/wiki-init.sh` detects repo visibility via `gh api "repos/$OWNER/$REPO" --jq .visibility`. For private: write empty `site_url` (mkdocs-material falls back to relative-only paths in 404.html). For public: write the existing `https://<org>.github.io/<repo>/` shape. Mock-`gh` test fixture at `tests/test-wiki-init-private-site-url.sh` covering both branches; existing public-repo behavior must not regress. Verbatim bash + regression test in the handoff doc.

**Severity rationale for P01**: surfaced from the same dogfood session as F12; same `wiki-init.sh` surface area; bundling avoids two separate ship cycles. Smaller fix than F12 (~10 lines bash vs. workflow scaffold + deploy-flow inversion).

**Alternatives considered (deferred)**: workflow-time `site_url` env-var override (F2-style — more moving parts, good follow-up for per-environment URLs); hand-written `wiki/docs/overrides/404.html` with relative paths (ongoing maintenance burden as upstream 404.html evolves). Smallest scaffold delta + matches existing wiki-init "detect repo state, write conf accordingly" pattern → visibility branch is the choice.

### P01 acceptance criteria (preview — formalized at `orchestrator:specify` time)

- Card-grid homepage renders on PBJ-central with project-defined cards.
- Reference nav titles read as `version:` strings on PBJ-central's reference corpus.
- DECISIONS.md TOC on this repo reads as human concepts.
- `mkdocs build` clean (no new warnings introduced).
- PBJ-central re-runs `orchestrator:update` and the `wiki:` config block survives the install refresh.
- `.orchestrator/feedback/*.md` files project to `wiki/docs/feedback/` stubs without manual scaffolding (F8).
- ~~F9 (Pages-rebuild poll)~~ — superseded by F12 below; no acceptance criterion derived from F9 in P01.
- 178-page fixture emits one OUT-OF-SCOPE summary line for the giscus target instead of 178 lines (F10); `--verbose` restores per-occurrence emission.
- `wiki/README.md` first-deploy checklist contains the org-level discussions redirect callout (F11).
- Fresh-install fixture produces `.github/workflows/pages.yml`; repo Pages config shows `build_type: workflow`; `wiki-deploy.sh` no longer runs `mkdocs gh-deploy` on the live path; push to main triggers a `Deploy wiki to Pages` workflow run that completes within ~2 min; no `pages-build-deployment` legacy runs created (F12).
- `tests/test-wiki-init-workflow-mode.sh` passes (F12 regression).
- `wiki-init.sh` writes empty `site_url` for private repos (`gh api repos/X --jq .visibility = private`) and the existing `https://<org>.github.io/<repo>/` shape for public; `mkdocs build` against private fixture produces a `site/404.html` with relative stylesheet hrefs (F13).
- `tests/test-wiki-init-private-site-url.sh` passes both branches (F13 regression).
- M032 wiki-deploy quickstart docs reflect the new "git push triggers deploy" flow (F12 documentation update).
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
