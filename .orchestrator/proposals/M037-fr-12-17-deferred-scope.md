---
schema_version: "1.0"
type: proposal
title: "M037 FR-12..FR-17 deferred scope (post-launch wiki readability polish)"
status: deferred-post-launch
target_milestone: "post-launch wiki-ux-deep + external-tool-adapters"
captured: "2026-05-07"
captured_at_close_of: "M037"
parent_proposal: ".orchestrator/proposals/post-launch-wiki-ux-and-adapters.md"
---

# M037 FR-12..FR-17 — Deferred to Post-Launch

## Why this exists

M037 (wiki team-feedback-ready) originally scoped P03 as a formal phase
shipping FR-12..FR-17 (tag-driven nav buckets, GitHub source-link rewrite,
`/knowledge/` card grid, `mkdocs-tags` + `mkdocs-redirects` +
`mkdocs-git-revision-date-localized` plugins, optional Material `social` +
`meta` plugin candidates). See `.orchestrator/milestones/M037/M037-ROADMAP.md`
boundary map at line 32 for the original scope.

What actually shipped in P03 was a **PBJ-feedback-driven polish series**
(round-3.5 / round-4 / round-5 — commits `79b0f7a9`, `6919bdb9`, `19be603d`,
`b81b9334`) that addressed the actually-blocking reader-side defects
PBJ-central surfaced during the live dogfood loop. None of those commits
implemented FR-12..FR-17 directly.

PBJ-central confirmed "looking good in the wiki now" after round-5 landed
(2026-05-07). With the live dogfood signal positive against the as-shipped
shape, FR-12..FR-17 is no longer launch-blocking. Investing pre-launch
weeks in plugin work for an audience that hasn't filed feedback against
the current shape would consume runway better spent on M035 packaging.

This proposal captures FR-12..FR-17 as a **post-launch fast-follow** so
the formal roadmap scope isn't lost in a sentence buried in CLAUDE.md.

## Scope

Verbatim from `M037-ROADMAP.md:32` boundary map (de-restated here so the
proposal is self-contained):

- **FR-12 — `wiki.nav_buckets:` config schema + tag-driven nav subgrouping**:
  `wiki-generate-nav.sh` reads `wiki.nav_buckets:` to deterministically
  group reference entries under config-declared buckets (e.g. "QSO letters",
  "Policy manuals & FAQs", "Training materials") instead of the current
  flat 70+-entry list. "Uncategorized" sibling bucket for tag-less chunks.
  Operator-authored buckets survive byte-identical via the P01 yaml-merge
  primitive.
- **FR-13 — GitHub source-link rewrite at projection time**: stub generator
  metadata-table emission (Tier 0) and Tier 1 chunk-projection pass rewrite
  source `file://` paths to `<repo_url>/blob/<default-branch>/...` so every
  chunk page carries a working "view source" affordance. CON-4 default-branch
  fallback to `main` (helper at `scripts/wiki/resolve-default-branch.sh`
  shipped in P01).
- **FR-14 — `/knowledge/` card grid**: `/knowledge/` projection consumes the
  P01 card-grid template primitive (`templates/wiki-index-cards.md.tmpl`)
  via either a new `wiki.knowledge_cards:` schema or a scoped reuse of
  `wiki.landing_cards:` (final shape decided at FR-14 plan-time). Power-user
  URL `/knowledge/_index/` for legacy auto-projected content.
- **FR-15 — `topic_tags:` → `tags:` adapter + 3 plugins**: projection-time
  adapter mapping the M036a chunk frontmatter's `topic_tags:` to mkdocs-material's
  built-in `tags:` field (preserving operator-authored `tags:` when both
  present per Edge-Case rule). `wiki/requirements.txt` extends with two
  external pinned plugins: `mkdocs-redirects`, `mkdocs-git-revision-date-localized-plugin`.
  Material's built-in `tags` plugin (no external dep) covers the third
  capability.
- **FR-16 (optional) — Material `social` plugin auto-OG-cards**: gated on
  first PBJ feedback signal post-launch. `mkdocs-material[imaging]`
  system-deps probe in `wiki-init.sh`.
- **FR-17 (optional) — Material `meta` plugin folder-frontmatter-defaults**:
  also gated on first PBJ post-launch signal. Example pattern at
  `wiki/docs/<section>/.meta.yml`.

## Why now is wrong (de-facto narrowing rationale)

- **PBJ-central is satisfied with current shape.** The dogfood signal
  drove round-3.5/4/5 to address the visibly-broken cases that prevented
  reader use. With PBJ now reading happily, FR-12..FR-17 is enrichment,
  not remediation.
- **M035 is the actual launch readiness blocker.** The npm/homebrew/curl-pipe-bash
  publishing pipelines and `--mode=symlink` dev-ergonomics are what gate
  the 2026-05-15 pilot. Wiki polish does not.
- **FR-12 + FR-15 require a tag taxonomy decision that is dogfood-signal-dependent.**
  Both FRs assume `topic_tags:` populates a useful nav-bucket clustering.
  M036a chunks today carry small/sparse `topic_tags:` lists; the right
  bucket vocabulary is observable only after a real validator audience
  scrolls the live wiki. Shipping FR-12 pre-launch risks designing buckets
  that don't match how readers actually want to navigate.

## What gets done now (M037 closure)

- M037 closes against the **PBJ-feedback-driven scope as the de-facto P03 scope**.
- This proposal preserves the formal FR-12..FR-17 scope as a recognizable
  post-launch fast-follow.
- The post-launch `post-launch-wiki-ux-and-adapters.md` proposal (which
  CLAUDE.md describes as "narrowed by M037 absorbing F3/F5/F1.2 readability
  scope") is the structural absorber.

## What unblocks taking this on post-launch

- **First PBJ-team navigation-or-section-shape feedback against the live
  wiki** (the original gate condition from `M037-ROADMAP.md:32`) — supplies
  the bucket taxonomy and the prioritization signal.
- **M035 closure** so packaging surface area is stable.
- **Live validator-pilot rotation** so we have non-PBJ reader signal to
  confirm bucket vocabulary generalizes beyond a single project.

## Cross-references

- `.orchestrator/milestones/M037/M037-ROADMAP.md` — formal P03 boundary
  map (FR-12..FR-17 listed at line 32–38)
- `.orchestrator/milestones/M037/phases/P03/P03-PLAN.md` — retroactive
  plan documenting the actually-shipped polish-series scope
- `.orchestrator/milestones/M037/phases/P03/P03-SUMMARY.md` — phase
  summary listing round-3.5 / round-4 / round-5 commits + acceptance
  evidence
- `.orchestrator/proposals/post-launch-wiki-ux-and-adapters.md` — the
  parent post-launch proposal that absorbs this scope
- CLAUDE.md `## Forward Roadmap` — references this deferral under the
  M037 closure entry
