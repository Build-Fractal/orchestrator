# Feature Specification: M012 Spec Wiki — Dogfood Browseable Surface for `.orchestrator/` Artifacts

**Feature Branch**: `022-spec-wiki`
**Created**: 2026-04-18
**Status**: Draft
**Milestone**: M012 (see `.orchestrator/milestone-summary.md`, roadmap entry "Spec Wiki — MkDocs + Giscus comments; stakeholder-readable site")
**Input**: User description: "M012 Spec Wiki: dogfood-only MkDocs site that renders `.orchestrator/` artifacts (constitution, DECISIONS.md, KNOWLEDGE.md, milestone-summary.md, per-milestone evaluations/plans/summaries) as a browsable wiki. Each page has a Giscus comment thread (repo/category via config, deferred to deploy). Deployed via `mkdocs gh-deploy` to GitHub Pages. Goal: the team can read, cross-link, and comment on orchestrator artifacts without opening raw markdown."

## Problem Statement

The orchestrator generates a growing body of durable state at `.orchestrator/` — the constitution, `DECISIONS.md` (12+ architectural decision entries), `KNOWLEDGE.md`, `milestone-summary.md`, and per-milestone `CONTEXT/EVALUATION/ROADMAP/SUMMARY` files plus nested phase and task plans. These are the ground truth the orchestrator runs on (Constitution VI — State On Disk Is Truth) and the primary learning surface (Constitution VII — Knowledge Compounds).

Today the only way to read any of this is to open raw markdown files in an editor or GitHub's file browser. Three consequences:

1. **No navigation surface.** There is no sidebar, no breadcrumb, no "you are here" across ~200+ markdown artifacts spread over 14 milestone directories. Finding `DECISIONS.md` entry D009 while reading M011's summary requires switching files.
2. **No commenting surface.** When a team member reads a decision or summary and wants to flag a concern, capture a followup, or ask a question, there is no in-context place to leave that comment. Comments land in PRs (transient) or Slack (searchless) or get lost.
3. **No cross-link rendering.** Internal references (e.g., a milestone summary says "see `DECISIONS.md` D009") render as plain text in GitHub's file view and as broken links in most external preview tools. The team cannot chase a reference with one click.

M012 ships the minimum surface that fixes all three for the team's own use during the M013/M014 dogfooding window. It is explicitly **not** a public-facing site (M009 scope), **not** a comment-classification or automation layer (M014 scope), and **not** a knowledge graph (M020 scope, whose promote-or-dissolve trigger is evaluated at the close of this milestone's relevant phase per `.orchestrator/DECISIONS.md` D011).

The scope discipline matters. Every feature added beyond "render + comment" risks absorbing M013/M014/M020 scope. The spec must keep those out.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Team Member Navigates Orchestrator Artifacts Without Opening Raw Markdown (Priority: P1)

A team member who needs context on a past decision, a milestone's plan, or the current state of knowledge opens the deployed wiki in a browser, uses a left-hand sidebar or top navigation to reach the relevant artifact, and reads it with markdown rendered (headings styled, tables formatted, code fences highlighted). No file-tree spelunking in an editor; no raw markdown in a tab.

**Why this priority**: This is the core fix. Without navigable rendering, the wiki has no reason to exist.

**Independent Test**: Deploy the wiki to a GitHub Pages URL. From the home page, reach `DECISIONS.md` entry D009 in three clicks or fewer. Reach any per-milestone summary (e.g., `M011-SUMMARY.md`) in four clicks or fewer. Confirm markdown renders (no raw `##` prefixes visible to the reader).

**Acceptance Scenarios**:

1. **Given** the wiki is deployed, **When** a reader lands on the home page, **Then** they see a navigation surface listing (at minimum) Constitution, Decisions, Knowledge, Milestone Summary, and a Milestones section.
2. **Given** the reader clicks into a milestone (e.g., M011), **When** the milestone page renders, **Then** they see links to that milestone's CONTEXT, EVALUATION, ROADMAP, SUMMARY, and nested phase/task plans.
3. **Given** a rendered page, **When** the reader looks for a specific section, **Then** headings are visually distinct, tables are formatted, and code fences are highlighted.
4. **Given** the reader wants to search, **When** they use the site's search box, **Then** results return across all rendered pages (MkDocs default search is sufficient for dogfood).

---

### User Story 2 — Team Member Leaves A Comment On A Rendered Page That Persists Across Deploys (Priority: P1)

A team member reading a rendered artifact (e.g., a decision entry, a phase plan) can leave a comment below the content using their GitHub identity. The comment persists across redeploys of the site. Other team members can reply. The comment thread is scoped to that page, not to the whole site.

**Why this priority**: Commenting is the M013/M014 dogfooding prerequisite. M014's "classify and auto-apply wiki+GH comments" assumes wiki comments exist and are attached to specific artifacts. If M012 ships without per-page comment threads, M014 cannot dogfood its classifier on wiki traffic.

**Independent Test**: Open a rendered page on the deployed wiki. Sign in with GitHub. Post a comment. Reload the page. The comment is still visible. Redeploy the site. The comment is still visible. Open a second rendered page. Its comment thread is empty (threads are per-page, not global).

**Acceptance Scenarios**:

1. **Given** a rendered page, **When** the reader scrolls past the content, **Then** a comment thread appears at the bottom of the page.
2. **Given** an authenticated GitHub user, **When** they post a comment, **Then** the comment is attached to the originating GitHub Discussion for that page and visible to subsequent readers.
3. **Given** the site is redeployed after a content change, **When** a reader returns to the page, **Then** existing comments remain attached to that page.
4. **Given** two different pages, **When** comments are posted on each, **Then** each comment only appears on the page it was posted to.
5. **Given** the deploy environment lacks Giscus configuration (missing repo ID, category ID, or token), **When** the site builds, **Then** the build either (a) fails loudly with a clear message about the missing config, or (b) succeeds with a visible "comments disabled: missing config" placeholder — never silently omits the comment surface with no indication.

---

### User Story 3 — Maintainer Deploys Or Updates The Wiki With One Command (Priority: P1)

A team member who has updated an orchestrator artifact (amended a decision, added a milestone summary, graduated a knowledge entry) runs a single deploy command from the repo root and within minutes sees the change reflected on the deployed site. No multi-step release process, no hand-editing build artifacts, no CI dependency.

**Why this priority**: Dogfooding requires a fast feedback loop. If deploying the wiki requires a five-step release dance, people will not redeploy it, and the site will drift from the source of truth. A one-command deploy keeps the wiki honest.

**Independent Test**: After an orchestrator artifact is changed on `main`, run the documented deploy command from the repo root. Within 5 minutes (bounded by GitHub Pages propagation), the change is visible on the deployed URL. The deploy command is a single invocation — not a chain of manual steps documented in a runbook.

**Acceptance Scenarios**:

1. **Given** an artifact change committed on `main`, **When** the maintainer runs the documented deploy command, **Then** the command builds the site and publishes it to GitHub Pages in one invocation.
2. **Given** GitHub Pages is configured to serve the wiki, **When** the deploy command completes, **Then** the deployed URL serves the updated content within the site's propagation window (MkDocs' standard GitHub Pages propagation, typically under 5 minutes).
3. **Given** the deploy command fails (build error, auth error, permission error), **When** it exits non-zero, **Then** the error is surfaced in the terminal with enough detail to diagnose — not swallowed.
4. **Given** the site has never been deployed before, **When** the maintainer runs the deploy command for the first time, **Then** the initial deploy succeeds following the repo's `docs/` guide (which is part of this milestone's deliverables) — no unlisted manual steps.

---

### User Story 4 — Internal Cross-References Between Artifacts Resolve To Rendered Pages (Priority: P2)

When an artifact says "see `.orchestrator/DECISIONS.md` D009" or "see `M011-SUMMARY.md`" with a markdown link, clicking the link on the rendered site navigates to the rendered version of that target — not to the raw markdown file and not to a broken path.

**Why this priority**: Cross-references are how orchestrator artifacts already convey structure (`DECISIONS.md` references milestone summaries, summaries reference decisions, knowledge entries reference both). If they render as broken links on the wiki, readers fall back to raw markdown and the wiki loses its value. Priority P2 rather than P1 because the site is still usable without cross-link rewriting (sidebar navigation gets you there) — just less pleasant.

**Independent Test**: Open a rendered artifact that contains a link like `[D009](../DECISIONS.md#dr-code-009)` or `[M011 summary](milestones/M011/M011-SUMMARY.md)`. Click the link. It loads the rendered version of that target. The browser URL reflects the rendered route, not a raw `.md` path.

**Acceptance Scenarios**:

1. **Given** a rendered page containing a relative markdown link to another `.orchestrator/` artifact, **When** a reader clicks the link, **Then** the browser navigates to the rendered version of the target page.
2. **Given** a rendered page containing an anchor link to a heading within the same artifact, **When** a reader clicks the anchor, **Then** the browser scrolls to that heading.
3. **Given** a link that targets an artifact not included in the wiki scope (e.g., `scripts/foo.sh`, `tests/bar.sh`), **When** a reader clicks it, **Then** the behavior is documented — either the link resolves to the GitHub source (acceptable) or it is flagged during build as out-of-scope (acceptable). Silent broken links are not acceptable.

---

### User Story 5 — Comment Threads Survive Artifact Restructuring (Priority: P2)

If an artifact is moved or renamed (e.g., a milestone is archived from `.orchestrator/milestones/M011/` to `.orchestrator/archive/M011/`, or a file is renamed), its comment thread either (a) follows the new location deterministically, or (b) the migration path is documented and can be applied as a one-time fixup.

**Why this priority**: Orchestrator milestones get archived (see `orchestrator:consolidate`). If Giscus threads are keyed only to the file path, every consolidation silently orphans comment threads. P2 because archival is predictable and infrequent; a documented migration is acceptable. Not P1 because the dogfood window is short enough that the first consolidation can be handled manually if needed.

**Independent Test**: Pick a comment-thread key strategy that survives at least one path change. Document the chosen strategy. Test it by simulating a consolidation (move an artifact, redeploy, confirm the comment thread is either preserved or migratable with a documented script).

**Acceptance Scenarios**:

1. **Given** a Giscus mapping strategy is chosen (pathname, URL, title, specific term, og:title, etc.), **When** the mapping is documented in the repo, **Then** the tradeoffs (what survives a rename, what does not) are stated explicitly.
2. **Given** an artifact is moved to `.orchestrator/archive/`, **When** the site is redeployed, **Then** either the comment thread follows automatically (if the mapping supports it) or a documented migration script can relink it.

---

## Functional Requirements

- **FR-1**: The wiki source lives in-repo under a single directory (e.g., `wiki/` or `docs-wiki/`) containing `mkdocs.yml` and any static assets. Orchestrator artifacts are **not** copied into that directory — they are referenced from their canonical `.orchestrator/` locations via MkDocs configuration (symlinks, includes, or equivalent) so there is one source of truth.
- **FR-2**: The rendered wiki includes at minimum: `.orchestrator/memory/constitution.md`, `.orchestrator/DECISIONS.md`, `.orchestrator/KNOWLEDGE.md`, `.orchestrator/milestone-summary.md`, and every milestone directory's `M###-CONTEXT.md`, `M###-EVALUATION.md`, `M###-ROADMAP.md`, `M###-SUMMARY.md` plus any `phases/**/*.md` and `tasks/**/*.md` files.
- **FR-3**: Each rendered page hosts a Giscus comment thread. Thread mapping strategy is documented (see US5).
- **FR-4**: Giscus configuration (repo, repo ID, category, category ID, mapping) is supplied via `mkdocs.yml` — either hard-coded for the single dogfood deploy target, or env-interpolated at build time. Configuration is **not** committed in a way that hardcodes a production/public deploy.
- **FR-5**: A single deploy command (e.g., `mkdocs gh-deploy --force` or a documented wrapper script) publishes the site to GitHub Pages. The command is documented in `docs/` or `wiki/README.md`.
- **FR-6**: Internal markdown links between `.orchestrator/` artifacts resolve to rendered pages on the deployed site (see US4). Out-of-scope targets (scripts, tests) either resolve to GitHub source or are flagged at build.
- **FR-7**: The site build runs locally via a documented command (e.g., `mkdocs serve`) so artifact changes can be previewed before deploy.
- **FR-8**: Non-markdown `.orchestrator/` files (`execution-log.jsonl`, `doctor-history.jsonl`, `*-result.txt`, `VALIDATED` markers) are **not** rendered. The wiki is markdown-only.
- **FR-9**: Archived milestones under `.orchestrator/archive/` are either (a) rendered in a clearly labeled "Archive" section, or (b) excluded with the rationale documented. Either choice is acceptable; silent inclusion or silent exclusion is not.
- **FR-10**: The wiki home page (`index.md`) provides a one-page orientation: what this site is, how to navigate, where to comment, who the audience is (dogfood only).

## Success Criteria

- **SC-1**: The deployed wiki renders every in-scope `.orchestrator/` markdown artifact. A build-time check lists in-scope files and confirms each has a corresponding rendered page.
- **SC-2**: Every rendered page includes a Giscus comment thread. A build-time check (or a smoke-test script) confirms the Giscus `<script>` block is present on every generated HTML page.
- **SC-3**: A team member lands on the deployed home page and reaches any target artifact within four clicks. Measured by walking the site manually on the reviewed deploy URL.
- **SC-4**: The site is deployed via a single documented command. Confirmed by running the command end-to-end against a clean clone; no manual intermediate steps.
- **SC-5**: A team member signs in with GitHub, posts a test comment, reloads, sees their comment. Redeploys the site. Returns to the page. The comment is still there. Manual acceptance test during US2 verification.
- **SC-6**: Markdown cross-references between in-scope artifacts resolve to rendered routes, verified by a link-check script that walks the built site and reports broken links. Zero broken links for in-scope targets; out-of-scope targets either resolve externally or are enumerated in the build output.
- **SC-7**: The chosen Giscus mapping strategy is documented (in `wiki/README.md` or equivalent) with its explicit tradeoffs for rename/move.
- **SC-8**: Local preview (`mkdocs serve` or equivalent) works without deploying. Documented in `docs/` and confirmed by running it.
- **SC-9**: The deploy command fails loudly (non-zero exit, clear error message) when Giscus config is missing. Verified by temporarily unsetting the config and running the deploy.
- **SC-10**: The wiki directory in-repo is self-contained — its configuration, theme, and build pipeline live under one top-level directory, and removing that directory does not break the orchestrator itself. Verified by `git rm -r <wiki-dir>/` on a scratch branch followed by `tests/test-*.sh` green.
- **SC-11**: Bash 3.2 compatibility (Constitution VIII) for any shipped helper scripts (deploy wrapper, link checker, Giscus smoke test). No `declare -A`, no compound bash in agent-facing content.

## Non-Goals

- **External / public audience.** This is a dogfood milestone. External-facing polish — landing pages, SEO, branded theming, mobile UX tuning beyond MkDocs Material defaults, accessibility audit — is M009 (Launch & Ecosystem) scope.
- **Rendering `specs/**` or other non-`.orchestrator/` content.** The wiki covers orchestrator artifacts only. `specs/**` is authored for speckit interop and may or may not belong on a wiki later; that decision is out of scope here.
- **Rendering `commands/**`, `references/**`, `docs/**`, `README.md`.** Those are already rendered adequately on GitHub. Wiki scope is `.orchestrator/` state, not the repo as a whole.
- **Comment classification, triage, or auto-application.** That is M014's scope. M012 ships the comment *surface*; M014 ships the workflow on top.
- **GitHub Issues / Projects / Milestones sync.** That is M013's scope.
- **Automated deploys on push / CI integration.** Manual `mkdocs gh-deploy` is sufficient for dogfood. CI deploys can be added later; they are not a dogfood prerequisite.
- **A knowledge graph, clustering view, or graph-explore UI.** That is M020 territory (see `.orchestrator/DECISIONS.md` D011). D011's promote-or-dissolve trigger is evaluated at the close of M012's relevant phase — which features from the M020 criteria (cross-refs, review state, query surface) land in M012 is a **planning-phase decision**, not a spec-phase commitment.
- **Editing UI / in-browser authoring.** Artifacts are authored in-repo. The wiki renders; it does not edit.
- **Multiple deploy targets or preview environments.** One dogfood deploy is enough. Staging / preview / per-branch deploys are future work.
- **Pricing, usage, or cost analytics surfaced in the wiki.** That is M019 Tier 2/3 scope.
- **Custom search beyond MkDocs defaults.** MkDocs' built-in search is sufficient.
- **Offline export (PDF, ePub, etc.).** Not in scope.
- **Access control / private deploys.** GitHub Pages public is fine for a dogfood team repo. If access control is later required, that is a separate hardening effort.

## Constraints

- **Single source of truth.** Orchestrator artifacts remain at their canonical `.orchestrator/` paths. The wiki references them; it does not duplicate them. Any "copy into `wiki/` for rendering" shortcut that creates a second authoritative location is rejected.
- **Dogfood-scoped.** The wiki targets the team using the orchestrator during M013/M014. It is not a public launch surface. Non-goals above are binding.
- **Giscus requires GitHub Discussions.** The hosting repo must have Discussions enabled with a chosen category. This is a deploy-time prerequisite, not a feature the wiki itself provides. If the chosen repo does not have Discussions, the deploy cannot proceed until enabled.
- **Config placement.** Giscus IDs must not be hardcoded into committed source in a way that locks the wiki to a specific GitHub Discussions category. Use env interpolation or a documented `mkdocs.yml` override pattern so the same wiki can be redeployed against a different Discussions target if needed.
- **M020 trigger avoidance.** The spec does not pre-commit to shipping the D011 trigger criteria (cross-refs to `knowledge/**/MEM*.md`, reviewed/unreviewed state, dispatch-callable query surface). Planning decides which land based on dogfood needs. D011's evaluation runs mechanically against whatever ships; that evaluation is the point.
- **No mid-milestone scope insertion.** Constitution XV (Surgical Precision). Features not in this spec are either non-goals, future work, or out-of-scope — they do not accrete during planning or execution.
- **Bash 3.2 compatibility** (Constitution VIII) for any shipped shell tooling.
- **No compound bash in agent-facing content** (Constitution XV + M016's anti-pattern linter) for any dispatched task payloads.

## Assumptions

- **MkDocs + Material theme** is the default stack. Widely adopted, stable, GitHub Pages-friendly, supports nav + search + code highlighting + Giscus integration out of the box. Planning may substitute an equivalent if warranted; this spec is not framework-locked.
- **Giscus** is the default comment system. Maps one-to-one to GitHub Discussions, which the team already uses. No separate auth, no separate moderation surface. Planning may substitute an equivalent (utterances, native GitHub Discussions embeds) if Giscus proves unsuitable.
- **GitHub Pages** is the default host. Free, already tied to the repo, `mkdocs gh-deploy` is the standard deploy command. Planning may substitute an equivalent static host; in that case US3's "one command" constraint still applies.
- **Audience is the team using this orchestrator.** Not external contributors, not stakeholders pre-launch. Sets polish expectations to "works for us" not "ready for a demo."
- **Content volume is bounded and already organized.** `.orchestrator/` has existing directory structure; the wiki follows it. No content reorganization is required to ship.
- **Page-level comment thread is the right granularity.** Not paragraph-level, not heading-level. Matches how artifacts are authored and how readers engage with them. Planning may revisit if dogfood feedback contradicts.
- **Review state (if it ships) belongs at the artifact level.** If the D011 "reviewed/unreviewed" criterion lands, it is per-page, not per-heading. Planning decides.
- **First deploy is manual.** No CI is built for this milestone. If the wiki proves useful, CI auto-deploy is a post-M012 enhancement, not a dogfood blocker.

## Open Questions (defer to planning)

These are **not** decisions the spec makes. They are captured so planning starts with the list.

- Which `.orchestrator/archive/` milestones ship in the wiki? All, none, or a cutoff?
- Does the wiki include per-phase and per-task plans (`phases/**/*.md`, `tasks/**/*.md`), or only milestone-level artifacts? FR-2 says "include" but planning may trim if the resulting nav is unwieldy.
- Giscus mapping strategy: `pathname` (simple, breaks on rename), `title` (survives renames but fragile to title edits), `specific` with a manually-assigned term (most durable, highest authoring cost), or a custom `og:title` injection? Trade-off matrix belongs in planning.
- Does the wiki include a lightweight "last updated" footer per page sourced from git? (Cheap via MkDocs plugins; low priority.)
- Does the wiki include an auto-generated index of `DECISIONS.md` entries (D001…D012…) or rely on the file's own table-of-contents? (Affects how readers chase decision references.)
- Does the dogfood deploy target a dedicated repo (e.g., an `-wiki` repo) or this repo's own `gh-pages` branch? Affects whether the GitHub Discussions target is this repo's Discussions or a separate one.
- Does the wiki carry a "propose a change" link per page that opens the raw markdown in a GitHub edit flow? Low cost, may encourage in-context contributions.

## Dependencies

- **M011 close (complete).** Spec management milestone already shipped — not a content dependency, but the wiki will render M011's artifacts on day one.
- **M019 Tier 1 emitter (complete).** Execution-log records exist; the wiki does not render them (FR-8) but their presence affects repo state the wiki must coexist with.
- **GitHub Pages availability.** A deploy-time prerequisite, not a build-time one.
- **GitHub Discussions enabled on the deploy-target repo.** Required for Giscus to function.
- **No dependency on M013 or M014.** The wiki ships independently; M013 and M014 consume the comment surface downstream.

## Downstream Consumers (informational, not binding)

- **M013 (GitHub Native Integration)** will read/write to the wiki's backing GitHub Discussions for its pre-merge review gate.
- **M014 (Comment→Workflow Automation)** will ingest wiki comment threads as classifier input.
- **M020 decision trigger** (`.orchestrator/DECISIONS.md` D011): at the close of M012's relevant phase, a mechanical check counts how many of D011's three criteria (cross-refs to `knowledge/**/MEM*.md`, reviewed/unreviewed state, dispatch-callable query surface) shipped. ≥2 of 3 dissolves M020; ≤1 of 3 promotes M020. **This spec does not pre-commit to shipping any of the three** — planning decides based on dogfood needs. The trigger runs against whatever ships.
