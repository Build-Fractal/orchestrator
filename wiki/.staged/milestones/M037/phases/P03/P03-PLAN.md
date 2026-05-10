---
schema_version: "1.0"
type: phase-plan
id: "P03"
parent: "M037"
milestone: "M037"
authoring_mode: "retroactive"
authored_at: "2026-05-07"
goal: "PBJ-feedback-driven polish bundle. After PBJ-central round-3 dogfood signaled the wiki was visibly broken on greenfield (orphan cards, missing icons, bundle-rooted nav titles, OOS-collapse noise) and reference-corpus reading required orientation primitives (breadcrumb, file-feedback affordance, glossary include), iteratively ship round-N.5 polish bundles until PBJ signals reader satisfaction."
demo_sentence: "PBJ-central reviews the live wiki against the latest bundle and replies 'looking good in the wiki now' — the dogfood-signal gate the original M037-ROADMAP P03 boundary map cited as the reader-acceptance contract."
gate_status: "satisfied — PBJ-central confirmation 2026-05-07 after round-5"
formal_roadmap_scope: "FR-12..FR-17 deferred to post-launch (see .orchestrator/proposals/M037-fr-12-17-deferred-scope.md)"
---

# M037 P03 — Round-3.5 / Round-4 / Round-5 PBJ-Feedback Polish Series

## Authoring note

This plan is **retroactive**, authored at M037 closure (2026-05-07) to
document what actually shipped in P03. Round-3.5 through round-5 landed
as direct commits driven by PBJ-central dogfood feedback, not through
the formal `orchestrator:plan-phase` + `orchestrator:dispatch` cycle.

The original P03 scope at `M037-ROADMAP.md:32` (FR-12..FR-17 — tag-driven
nav, GitHub source-link rewrite, knowledge card grid, 3 plugins, optional
Material `social`/`meta`) was de-facto narrowed at round-3.5 commit time
(`79b0f7a9` 2026-05-07): "Re-scoped from original F1.2/F2/F5 + plugins to
a PBJ-driven 8-fix tactical bundle". That narrowing held through
round-4 + round-5. Per the closure decision, FR-12..FR-17 ships as a
post-launch fast-follow under `post-launch-wiki-ux-and-adapters.md`;
this plan documents the bundle that actually shipped.

## Phase narrative

P03 became an iterative polish loop with PBJ-central as the live dogfood
signal. Each round:

1. PBJ team installs the latest bundle into their project, runs `wiki-init.sh`
   under the new shape, deploys, observes against their reader audience.
2. PBJ files concrete defects ("X renders broken on greenfield", "Y is
   missing", "Z reads confusingly").
3. The orchestrator team scopes a tactical bundle, ships it as a single
   commit, pushes, pings PBJ with a SHA range to retest.
4. Loop until PBJ signals satisfaction.

The loop converged at round-5. PBJ confirmation: "pbj is looking good in
the wiki now" (2026-05-07).

## Rounds shipped

### Round 3.5 (commit `79b0f7a9`, 2026-05-07T16:22:51-04:00) — 8 PBJ-driven fixes

**P1: Visibly broken on greenfield**

- **P1.1** — `wiki/mkdocs.yml` `pymdownx.emoji` with material.icons
  generator: fixes `:fontawesome-…:` / `:octicons-…:` card icons
  rendering as literal text on greenfield install.
- **P1.2** — `scripts/wiki/wiki-generate-stubs.sh` `render_landing_cards()`:
  pre-filter orphan cards (`#orphan-card-${slug}`) so link-check no longer
  catches placeholder anchors AND the all-orphan-zero-rendered case
  leaves `index.md` unchanged instead of writing an empty
  `<div class="grid cards">`.
- **P1.3** — `scripts/lifecycle/wiki-init.sh` final step: invokes
  `wiki-generate-stubs` + `wiki-generate-nav` BEFORE the `--deploy` block,
  so staged-into-project installs render project-local nav with human
  titles instead of the bundle's literal upstream `[M030](../../../../milestones/M030/index.md)+/proposals/*`
  tree.
- **P1.4** — Glossary include-wrapper with idempotent stub-replacement
  (P03 round-3.5 polish, glossary-projection robustness).

**P2: Reference-corpus reading experience**

- **P2.1** — Frontmatter `version:` projection + `published:`-desc sort
  on stub-generator: each chunk page metadata table surfaces the
  chunk's `version:` field; sort defaults stabilize.
- **P2.2** — `file://` → `<repo_url>/blob/main/` projection in both
  metadata-only and with-sibling reference-stub paths (precursor to
  the formal FR-13 GitHub source-link rewrite, but applied only at
  the metadata-table emission level — full-pipeline FR-13 deferred
  post-launch).
- **P2.3** — `[unknown]` suffix dropped on proposals (cosmetic
  polish on stage badge derivation).

**P3: Orientation primitives**

- **P3.1** — Absorbed `wiki/overrides/main.html` breadcrumb shim from
  PBJ verbatim (PBJ-team-authored extension that the bundle now ships).
- **P3.2** — File-feedback affordance banner above the Comments block
  (Giscus partial integration giving readers a per-page "feedback on
  this content" surface).

### Round 3.5 sync (commit `6919bdb9`, 2026-05-07) — wiki regen sync

Re-runs `wiki-generate-nav.sh` + `wiki-generate-stubs.sh` against the
orchestrator's own wiki tree to project the round-3.5 polish into the
dogfood wiki. Pure tooling-output regeneration; no source changes
beyond the round-3.5 bundle.

### Round 4 (commit `19be603d`, 2026-05-07T17:35:23-04:00) — wiki/overrides/ refresh

PBJ-central surfaced 2026-05-07 that the round-3.5 P3.1 breadcrumb shim
and P3.2 file-feedback aside / [M032](../../../../milestones/M032/index.md) dual-template surface shipped in
the bundle but never reached existing projects: `install-claude-code.sh`
tripped the operator-owned oracle on `wiki/`; `wiki-init.sh`'s
`PRE_STAGE_NO_OP` short-circuited when `wiki/mkdocs.yml` existed.

Adds a framework-managed `wiki/overrides/` refresh step in `wiki-init.sh`
that copies `wiki/overrides/main.html` and `wiki/overrides/partials/comments.html`
from the bundle into the project's `wiki/overrides/` regardless of
pre-stage status, with operator-authored content preserved via
extant-file diff guard. Closes the staging gap.

### Round 5 (commit `b81b9334`, 2026-05-07T19:43:00-04:00) — drop navigation.sections

PBJ-central surfaced 2026-05-07 that the live wiki rendered top-level
sections (`Reference — CMS rules`, `Reference — Regulatory docs`,
`Milestones`, etc.) as bold flat lists of all children, requiring
readers to scroll past every entry to navigate between sections.
Operator quote: "the list of items in the left nav is in sections,
those should be collapsed by default."

Root cause: `theme.features: navigation.sections` opts into the flat
shape (mkdocs-material designed behavior). Default Material behavior
(no flag) renders each section as a collapsible drawer with chevron.
`navigation.indexes` is independent and stays.

Bundle change: dropped `- navigation.sections` from `wiki/mkdocs.yml`.
yaml-merge no-op gotcha confirmed via dry-run probe — operators with
existing projects must manually delete the line from their
`wiki/mkdocs.yml` after `wiki-init.sh` runs (ping included
manual-edit instruction). Greenfield projects get correct behavior
automatically. List-element-replacement gap in yaml-merge is a
separate post-launch fix.

## What was NOT shipped (formal scope deferred)

FR-12 (tag-driven nav buckets), FR-13 (full GitHub source-link rewrite
across Tier 1 chunk-projection pass), FR-14 (`/knowledge/` card grid),
FR-15 (`topic_tags:` → `tags:` adapter + `mkdocs-redirects` +
`mkdocs-git-revision-date-localized-plugin`), FR-16 (Material `social`
plugin), FR-17 (Material `meta` plugin) — all deferred to post-launch
per [`.orchestrator/proposals/M037-fr-12-17-deferred-scope.md`](../../../../proposals/M037-fr-12-17-deferred-scope.md). The
round-3.5 P2.2 metadata-only `file://` rewrite is a *partial* slice of
FR-13 surface area but does not satisfy FR-13's Tier 1 chunk-projection
pass requirement.

## Acceptance evidence at close

- `tests/m037-acceptance/run-acceptance-battery.sh` — `BATTERY: pass=11
  skip=0 fail=0` (2026-05-07T19:30:00Z; full battery green after the
  round-5 bundle change).
- `bash scripts/verify/wiki-strict-build.sh` — `PASS: wiki-strict-build
  (0 errors, 0 warnings)`.
- yaml-merge dry-run probe — confirmed the round-5 `navigation.sections`
  drop is a no-op for existing projects (manual-edit guidance shipped to
  PBJ in re-engagement ping).

## Verification ledger

Per-round phase-suite pass rates were captured at commit time:

- Round 3.5 phase-suite (`tools/verify/m037-p03-round-3.5-phase-suite.sh` if
  present, otherwise the M037 P01+P02 phase-suites stayed green): no
  regressions on P01 (`pass=9 fail=0`) or P02 (`pass=5 fail=0`).
- Round 4: confirmed `wiki/overrides/` refresh reaches existing projects
  via fresh-install fixture path.
- Round 5: 14/14 stub-path tests green (M036/P03 phase-suite as
  collateral regression check on the `extract-tier-2-llm.sh` `live`
  branch addition that landed alongside in commit `c03efcc4`).

## Affects M037 closure

P03 closure satisfies the M037 demo sentence ("non-author SME team
gives positive wiki signal"). M037 closes against:

- Phase suite at the milestone boundary (acceptance battery `pass=11`).
- PBJ live-dogfood satisfaction signal.
- Validate-milestone PASS once this `P03-SUMMARY.md` lands.

## Cross-references

- Round 3.5 commit: `79b0f7a9` + sync `6919bdb9`
- Round 4 commit:   `19be603d`
- Round 5 commit:   `b81b9334`
- M036a P03 live-LLM smoke (parallel pre-launch operational follow-up,
  closed 2026-05-07 commit `c03efcc4`) — not part of M037 P03 but
  shipped same day; `extract-tier-2-llm.sh` `live` branch is unrelated
  to wiki polish.
- FR-12..FR-17 deferral: [`.orchestrator/proposals/M037-fr-12-17-deferred-scope.md`](../../../../proposals/M037-fr-12-17-deferred-scope.md)
- Forward proposal absorbing this scope:
  [`.orchestrator/proposals/post-launch-wiki-ux-and-adapters.md`](../../../../proposals/post-launch-wiki-ux-and-adapters.md)
