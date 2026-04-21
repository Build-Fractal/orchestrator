---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M012"
name: "wiki/README.md first-deploy checklist + deploy-wrapper section"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `wiki/docs/index.md` finalized and points readers at `wiki/README.md` (operator guide) for deploy / preview instructions.
- P01+P02+P03 complete: `wiki/README.md` already carries `Install`, `Preview`, `Regenerate`, `Scope`, `Link resolution`, `Running the link checker`, `Pre-deploy integration (P04)`, `Giscus mapping`, `Remapping threads after consolidation` sections. The file is 276 lines at P03 close.
- `scripts/wiki/wiki-deploy.sh` does not yet exist (T03 creates it). T02 writes the README section that authoritatively names the wrapper.

## Description

Extend `wiki/README.md` with two new sections that turn this file into the single operator reference for deploying and redeploying the dogfood wiki:

1. **`## First-deploy checklist`** — the strictly-ordered steps a maintainer runs exactly once when standing up a fresh GitHub Pages deployment. Names every `GISCUS_*` env var, the GitHub Discussions prerequisite, the chosen discussions category, the `gh-pages` branch, and the `mkdocs gh-deploy --force` invocation (via `scripts/wiki/wiki-deploy.sh`).

2. **`## Running the deploy wrapper`** — the recurring-use reference for `scripts/wiki/wiki-deploy.sh`: what it chains, what flags it honors (`--dry-run`, `--help`, `--root`, `--skip-smoke`), what failure modes each gate raises, and how to read the `GATE:` / `BUILD:` / `DEPLOY:` output lines.

This task writes the README content. The wrapper itself is T03.

## Description of exact section content

Append the two sections to `wiki/README.md` in order, **after** the existing `## Remapping threads after consolidation` block. Do not modify the P02- or P03-authored sections.

## Steps

1. **Append `## First-deploy checklist`** to `wiki/README.md`:

   ```markdown
   ## First-deploy checklist

   Run this exactly once when standing up the dogfood wiki on a fresh
   GitHub Pages deployment. Subsequent deploys use the "Running the
   deploy wrapper" section below.

   ### 1. Enable GitHub Discussions on the repository

   Settings → General → Features → check **Discussions**. Giscus reads
   from and writes to Discussions; the deploy will build successfully
   without this step, but the comment threads will 404 on first click.

   ### 2. Choose a Giscus discussions category

   Create a Discussions category named `Wiki Comments` (or pick an
   existing one). Note the category name and the category ID — the
   category ID is visible in the URL when you edit the category on
   GitHub, or retrievable via `gh api graphql` with a
   `repositoryDiscussionCategories` query. See
   <https://giscus.app> for the category-ID lookup tool.

   ### 3. Set the four `GISCUS_*` environment variables

   Export these in the shell that will run the deploy wrapper:

   ```
   export GISCUS_REPO="<org>/<repo>"
   export GISCUS_REPO_ID="<opaque-node-id>"
   export GISCUS_CATEGORY="Wiki Comments"
   export GISCUS_CATEGORY_ID="<opaque-node-id>"
   ```

   A missing or empty value trips the pre-build config-check gate with
   a diagnostic line naming the missing var — see `scripts/diagnostics/
   wiki-giscus-config-check.sh`.

   ### 4. Enable GitHub Pages with the `gh-pages` branch source

   Settings → Pages → Source → **Deploy from a branch** → Branch:
   `gh-pages` → `/ (root)`. On the very first deploy the branch does
   not yet exist; the wrapper creates it.

   ### 5. Ensure `gh` is on PATH

   The deploy wrapper itself does not call `gh` — `mkdocs gh-deploy`
   handles the push — but the Giscus remap flow (`scripts/diagnostics/
   wiki-giscus-remap.sh`) requires `gh` for any future consolidation.

   ### 6. Run the deploy wrapper

   From the repo root:

   ```
   bash scripts/wiki/wiki-deploy.sh
   ```

   On success the last two lines read `DEPLOY: pushing to gh-pages`
   and `OK: deployed to https://<org>.github.io/<repo>/`. On any gate
   failure the wrapper aborts before pushing and emits a `FAIL:` line
   naming which gate failed.

   ### 7. Record the deploy

   Copy the deploy URL and commit SHA into
   `.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`. That
   file's schema is asserted by `scripts/verify/m012-p04-deploy-record.sh`.

   ### 8. Smoke-test the deployed URL

   Open the deployed URL. Confirm:

   - The home page carries the four orientation sections (What this
     site is / How to navigate / Where to comment / Audience scope).
   - Every rendered page carries a Giscus thread at the bottom.
   - The search box returns hits for at least one term from every
     top-level section (Constitution, Decisions, Knowledge, Milestones).
   - Sign in with GitHub, post a test comment on any page, reload the
     page — the comment persists (US2 / SC-5).
   ```

2. **Append `## Running the deploy wrapper`** immediately after the
   first-deploy checklist:

   ```markdown
   ## Running the deploy wrapper

   `scripts/wiki/wiki-deploy.sh` is the single documented command
   for deploying or redeploying the dogfood wiki. It chains four
   gate-shaped invocations before invoking `mkdocs gh-deploy --force`
   and aborts on the first failure.

   ### Pipeline

   1. `scripts/diagnostics/wiki-giscus-config-check.sh` — verifies
      every `GISCUS_*` env var is set.
   2. `mkdocs build -f wiki/mkdocs.yml` — renders `wiki/site/`.
   3. `scripts/diagnostics/wiki-link-check.sh --site wiki/site` — walks
      the built HTML, flags broken in-scope links.
   4. `scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site` —
      asserts every page carries the Giscus loader.

   Then, on success: `mkdocs gh-deploy --force -f wiki/mkdocs.yml`
   pushes `wiki/site/` to the `gh-pages` branch.

   ### Flags

   - `--dry-run` — run all four gates, skip the final `mkdocs
     gh-deploy`, print `DRY-RUN: would deploy` and exit 0.
   - `--help` — print the usage block naming each gate and each
     supported flag, then exit 0.
   - `--root <dir>` — override the project root (default: invocation
     cwd).
   - `--skip-smoke` — skip gate (4) only. Not recommended for
     production deploys; useful during P04 development before the
     fixture site contains Giscus-configured pages.

   ### Output lines

   - `GATE: <name> PASS|FAIL` — one per gate.
   - `BUILD: ok|fail` — `mkdocs build` result.
   - `DEPLOY: pushing to gh-pages` — pre-push announcement on the
     live path.
   - `DRY-RUN: would deploy` — terminator on `--dry-run` success.
   - `OK: deployed to <url>` — terminator on live-path success.
   - `FAIL: <gate> <diagnostic>` — terminator on any gate failure.

   ### Exit codes

   - `0` — every gate PASS and (live path) `mkdocs gh-deploy` exit 0.
   - `1` — any gate FAIL, `mkdocs build` fail, or `mkdocs gh-deploy`
     fail.
   - `2` — usage error (unknown flag, missing argument, invalid
     `--root`).

   ### Failure triage

   - `GATE: giscus-config FAIL` — one or more `GISCUS_*` env vars is
     unset. Re-export per the first-deploy checklist step 3.
   - `BUILD: fail` — `mkdocs build` emitted errors (often a nav entry
     pointing at a non-existent page). Regenerate stubs + nav:
     `bash scripts/wiki/wiki-generate-stubs.sh && bash
     scripts/wiki/wiki-generate-nav.sh`, then rerun the wrapper.
   - `GATE: link-check FAIL` — the built site contains a broken
     in-scope link. Inspect the `BROKEN:` lines in the gate output;
     the usual fix is a missing stub (regenerate) or a typoed
     anchor in a canonical artifact.
   - `GATE: giscus-smoke FAIL` — a rendered HTML page is missing the
     Giscus loader. Check `wiki/overrides/partials/comments.html` is
     present and `wiki/mkdocs.yml` still carries `theme.custom_dir:
     overrides`.
   ```

3. **Do not** modify any other section of `wiki/README.md`. Do not
   re-order existing sections. Do not touch `wiki/docs/index.md` (T01
   owns it).

## Must-Haves

- `wiki/README.md` exists, ≥ 300 lines (T02 adds roughly 120 lines on
  top of P03's 276), and contains:
  - `## First-deploy checklist` — exact heading
  - `## Running the deploy wrapper` — exact heading
  - Literal `GISCUS_REPO` (appears in both P03's mapping section and
    T02's step 3 — dedup ok)
  - Literal `GISCUS_REPO_ID`
  - Literal `GISCUS_CATEGORY`
  - Literal `GISCUS_CATEGORY_ID`
  - Literal `gh-pages`
  - Literal `mkdocs gh-deploy`
  - Literal `Discussions` (naming the GitHub feature)
  - Literal `discussions category`
  - Literal `wiki-deploy.sh` reference
- The existing P02/P03 sections (`Install`, `Preview`, `Regenerate`,
  `Scope`, `Link resolution`, `Running the link checker`, `Pre-deploy
  integration (P04)`, `Giscus mapping`, `Remapping threads after
  consolidation`) are byte-identical before and after T02's edits.

## Verification

- Check: `bash scripts/verify/m012-p04-readme-first-deploy.sh`
- Check: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P04`

## Inputs

### From Previous Tasks

- `wiki/docs/index.md` (from T01) — the home page points at `wiki/README.md`. T02's `## Running the deploy wrapper` section is the section T01 hands off to.

### From Disk (Pre-existing)

- `wiki/README.md` (276 lines at P03 close) — carries Install / Preview / Regenerate / Scope / Link resolution / Running the link checker / Pre-deploy integration (P04) / Giscus mapping / Remapping threads after consolidation sections. T02 appends two new sections; it does not modify any existing section.
- `scripts/diagnostics/wiki-giscus-config-check.sh` (P03) — pre-build env-var gate. T02's checklist + wrapper docs reference its failure signature.
- `scripts/diagnostics/wiki-link-check.sh` (P02) — built-site link walker. T02's wrapper docs reference its `BROKEN:` output shape.
- `scripts/diagnostics/wiki-giscus-smoke.sh` (P03) — built-site Giscus smoke walker. T02's wrapper docs reference its per-page assertion.

## Constraints

- **AD-3 SSOT** — the checklist and wrapper docs name file paths and
  commands; they do not reprint any `.orchestrator/**.md` body text.
- **Constitution XV** (surgical precision) — T02 touches exactly one
  file (`wiki/README.md`) and appends exactly two new sections.
- **Constitution XIV** (no speculative complexity) — no "future flag"
  documentation, no unshipped commands. Every command the docs
  reference either exists at P03 close (config-check, link-check,
  smoke, remap) or ships in T03 (`wiki-deploy.sh`).
- **Bash 3.2 compat** — T02 ships no shell scripts.
- **Marker-comment discipline** — unlike P01/P03's mkdocs.yml edits,
  README sections do not use `# >>> M012-P04 ... # <<<` markers;
  section boundaries are the `## Heading` lines themselves.

## Expected Output

- `wiki/README.md` grows by ~120 lines with two new top-level sections
  appended at the bottom. The pre-existing sections are byte-identical.
- `grep -n 'First-deploy checklist' wiki/README.md` — exactly one match.
- `grep -n 'Running the deploy wrapper' wiki/README.md` — exactly one
  match.
- `grep -c 'GISCUS_' wiki/README.md` — at least 8 matches (4 in P03's
  Giscus-mapping block + 4 in T02's checklist step 3).
- The T05 gate `m012-p04-readme-first-deploy.sh` passes.
