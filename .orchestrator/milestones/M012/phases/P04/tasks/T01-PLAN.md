---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M012"
name: "Finalized wiki/docs/index.md home page + index SSOT guard"
depends_on: []
---

## Prerequisites

- P01 complete: `wiki/docs/index.md` exists as a 19-line placeholder whose opening frontmatter reads `title: "spec-kit-orchestrator dogfood wiki"` and whose body contains the literal word `placeholder`.
- P01 complete: the MkDocs nav emits top-level stubs for Constitution, Decisions, Knowledge (with a `knowledge/` section index from P02), Milestone Summary, and Milestones. Each stub is rendered under `wiki/docs/<slug>.md` or `wiki/docs/<slug>/index.md` — the home page can safely link by slug (e.g., `constitution.md`, `decisions.md`, `knowledge/index.md`, `milestone-summary.md`, `milestones/index.md`).
- P02 complete: `include-markdown` with `rewrite_relative_urls: true` is active. Relative links on the home page resolve to rendered routes automatically.
- P03 complete: `wiki/overrides/partials/comments.html` emits a Giscus thread on every page (including this home page once deployed).

## Description

Replace P01's scaffold home page with the finalized orientation content. This is the single page every team member lands on, so it must answer four questions in the first screen of text: **What is this site?** / **How do I navigate it?** / **Where do I comment?** / **Who is this for?** Plus one maintainer-facing pointer: **How do I preview or redeploy?** (link to `wiki/README.md`).

Hard SSOT constraint (Constitution VI + AD-3): the home page is NOT a documentation dump. It orients and hands off — it never inlines body text from `.orchestrator/**.md`. Every substantive link routes to a canonical rendered stub; the home page itself stays ≤ 120 lines of prose + link lists.

This task does two things:

1. Overwrite `wiki/docs/index.md` with the finalized content.
2. Ship `scripts/verify/m012-p04-index-ssot.sh` — a P04-specific SSOT guard that trips if any home-page paragraph appears verbatim in one of the upstream rendered stub targets. (The P01 SSOT gate enforces ≤ 25-line artifact stubs; this one enforces the no-body-copy invariant specifically for the home page, which has a higher line allowance.)

## Steps

1. **Overwrite `wiki/docs/index.md`** with the finalized home page. Use this shape exactly — the four section headings (`## What this site is`, `## How to navigate`, `## Where to comment`, `## Audience scope`) are asserted by T05's `m012-p04-index-finalized.sh` gate:

   ```markdown
   ---
   title: "spec-kit-orchestrator dogfood wiki"
   ---

   # spec-kit-orchestrator dogfood wiki

   A browseable projection of the orchestrator's `.orchestrator/` state —
   Constitution, Decisions, Knowledge, every milestone's plans and
   summaries — rendered from canonical paths with no body-copy (AD-3).

   ## What this site is

   The dogfood wiki is an internal MkDocs Material site generated from
   the orchestrator's own state tree. Every rendered page is a thin
   include stub pointing at a canonical `.orchestrator/**.md` artifact
   (or a granular `knowledge/**/MEM*.md` entry). No artifact body is
   copied into this site — the scanner enumerates paths, the stub
   generator writes include-markdown shells, and MkDocs renders them at
   build time.

   This is **not** a public-facing site. External launch lives in M009.

   ## How to navigate

   Five entry points live in the left navigation:

   - **Constitution** — the seven governing principles.
     See [Constitution](constitution.md).
   - **Decisions** — the architectural decisions register (AD-1..AD-19+).
     See [Decisions](decisions.md).
   - **Knowledge** — consolidated narrative plus 25 granular MEM entries
     grouped by category. See [Knowledge](knowledge/index.md).
   - **Milestone Summary** — the cross-milestone rollup + extension
     guide. See [Milestone Summary](milestone-summary.md).
   - **Milestones** — per-milestone plans, phases, tasks, and summaries
     (M001..current). See [Milestones](milestones/index.md).

   The top-right search box indexes every rendered page.

   ## Where to comment

   Every page carries a Giscus thread at the bottom, anchored to that
   page's URL path. Sign in with GitHub to post; threads persist across
   redeploys. If an artifact is renamed or consolidated, the
   `scripts/diagnostics/wiki-giscus-remap.sh` script migrates the
   thread. See the `Remapping threads after consolidation` section of
   the operator guide.

   ## Audience scope

   This site is for the dogfood team — contributors who need to
   navigate the orchestrator's decision history, knowledge, and
   milestone progress without opening raw markdown. It is not a public
   documentation site, not a user guide, and not a marketing page.
   External documentation lives under `docs/` in the repo and ships via
   M009 launch.

   ## Deploy & preview

   Preview locally with `bash scripts/wiki/wiki-serve.sh` from the repo
   root. Deploy via `bash scripts/wiki/wiki-deploy.sh` (the wrapper
   chains link-check + Giscus config-check + smoke-test before invoking
   `mkdocs gh-deploy --force` against the `gh-pages` branch). Both
   commands plus the first-deploy checklist are documented in the
   operator guide — see the repo-root `wiki/README.md`.
   ```

   Target: ~75–95 lines. Must be ≤ 120. Must NOT contain the literal word `placeholder`. Must contain each of the four required section headings verbatim.

2. **Do not** link the home page to any absolute URL under `https://giscus.app` or `https://github.com/<org>/<repo>` — those are deploy-time details, and hardcoding them couples the static home page to one deployment target.

3. **Do not** modify any other file in this task. The README extension belongs to T02; the deploy wrapper to T03. Keep blast radius to one file (Constitution XV).

## Must-Haves

- `wiki/docs/index.md` exists, ≥ 40 lines, ≤ 120 lines, and contains:
  - The literal string `How to navigate`
  - The literal string `Where to comment`
  - The literal string `Audience scope`
  - A link to `constitution.md`
  - A link to `decisions.md`
  - A link to `knowledge/index.md`
  - A link to `milestones/index.md`
- `wiki/docs/index.md` does **not** contain the literal word `placeholder`.
- `wiki/docs/index.md` contains zero paragraph-length blocks (≥ 40 contiguous non-blank characters) that appear verbatim in any `.orchestrator/**.md` artifact. (SSOT guard — prevents body-copy creep.)

## Verification

- Check: `bash scripts/verify/m012-p04-index-finalized.sh`
- Check: `bash scripts/verify/m012-p04-index-ssot.sh`
- Check: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P04`

## Inputs

### From Previous Tasks

- None. T01 is the phase root.

### From Disk (Pre-existing)

- `wiki/docs/index.md` (P01 output) — 19-line placeholder carrying the `title: "spec-kit-orchestrator dogfood wiki"` frontmatter and the literal word `placeholder` in the body. T01 overwrites this file.
- `wiki/mkdocs.yml` (P01 + P02 + P03 output) — the nav block routes `/constitution/`, `/decisions/`, `/knowledge/`, `/milestone-summary/`, `/milestones/` to their respective stubs. The home page's relative links resolve against those routes at build time via MkDocs' default URL scheme.
- `wiki/overrides/partials/comments.html` (P03 output) — emits the Giscus `<script>` block. Independent of the home page; the home page does not need to reference it explicitly.

## Constraints

- **AD-3 SSOT** — no `.orchestrator/**.md` body text is copied into the home page. The SSOT gate scans upstream stub targets and trips on verbatim paragraph matches.
- **Constitution VI** (self-contained wiki) — no link on the home page escapes the `wiki/docs/` tree except the operator-guide pointer (`wiki/README.md`, which is the repo-root README for the wiki directory — not a rendered page).
- **Constitution XIV** (no speculative complexity) — no "coming soon" sections, no placeholder features, no TODO comments. Ship only what lands in M012.
- **Constitution XV** (surgical precision) — T01 touches exactly one file.
- **Bash 3.2 compat** — T01 ships no shell scripts; the compat gate scans scripts created in T03 and T05.
- **Giscus surface unchanged** — the home page does not declare `comments: false` in its frontmatter; it collects comments like every other page.

## Expected Output

- `wiki/docs/index.md` carries the finalized home page, 40 ≤ line-count ≤ 120, with the four required section headings and the five required stub-route links. The literal word `placeholder` is absent.
- Running `mkdocs build -f wiki/mkdocs.yml` (where available) produces `wiki/site/index.html` with the orientation content + a Giscus thread block from the theme override. No broken-link warnings for in-scope targets.
