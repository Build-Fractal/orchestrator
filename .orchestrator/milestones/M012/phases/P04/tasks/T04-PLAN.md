---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M012"
name: "First-deploy execution + DEPLOY-RECORD.md"
depends_on: ["T03"]
---

## Prerequisites

- T01 complete: `wiki/docs/index.md` finalized.
- T02 complete: `wiki/README.md` first-deploy checklist + deploy-wrapper section.
- T03 complete: `scripts/wiki/wiki-deploy.sh` exists, is executable, chains the four P02/P03 gates before `mkdocs gh-deploy --force`.
- `gh-pages` branch may or may not exist on the remote — `mkdocs gh-deploy --force` creates it on first run.
- `.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md` does not yet exist.

## Description

Execute (or record as pending) the first deploy of the dogfood wiki, and write the structured deploy record that P04's Must-Haves gate on.

Two execution paths are acceptable:

1. **Live deploy (preferred, human operator)** — a maintainer with `GISCUS_*` env vars set and push rights to `gh-pages` runs the wrapper. The wrapper exits 0 with `OK: deployed to <url>` on success. The operator pastes the URL, commit SHA, and per-gate results into `DEPLOY-RECORD.md`.

2. **Fixture-shaped record (auto-mode path)** — when executed by a sandboxed autonomous dispatch without network access or without `GISCUS_*` secrets, the agent writes a record whose `deployed_url: pending` and `commit_sha: pending` sentinel values indicate human operator follow-up. The gate (T05 `m012-p04-deploy-record.sh`) accepts these sentinels in Tier 1; Tier 4 UAT (consolidate-phase human verification) promotes them to real values.

This dual path is explicit in the Truths of P04-PLAN.md. The cleaner long-term pattern — a live deploy from a scheduled GitHub Action — is out of scope for M012 (M013 / M014 may wire it); M012 ships the wrapper and the record schema, and the first live push is a one-time operator action that can land before or during consolidation.

## Description: DEPLOY-RECORD.md schema

The record file is the structured artifact P04 gates on. Its schema is intentionally minimal — seven fields — so the gate is trivial and the operator can fill it in in under 60 seconds.

## Steps

1. **Attempt the live deploy (human operator path)**. From the repo root, with the four `GISCUS_*` env vars set and `gh-pages` push rights:

   ```
   bash scripts/wiki/wiki-deploy.sh
   ```

   Capture the last three lines. On success they read (approximately):

   ```
   GATE: giscus-smoke PASS
   DEPLOY: pushing to gh-pages
   OK: deployed to gh-pages
   ```

   After the wrapper exits 0, the deployed URL is
   `https://<gh-owner>.github.io/spec-kit-orchestrator/` once GitHub
   Pages has finished building the `gh-pages` branch (typically within
   a minute of push). Capture:

   - the URL
   - the latest commit SHA on `main` (the source of truth) — `git rev-parse HEAD`
   - the timestamp in ISO-8601 UTC — `date -u +%Y-%m-%dT%H:%M:%SZ`
   - the four per-gate results from the wrapper output

2. **If the live deploy is not possible at plan-execution time (sandbox, no secrets, no push rights)**, write the record with the `pending` sentinel values. The gate accepts this path.

3. **Create `.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`** with exactly this shape:

   ```markdown
   ---
   schema_version: "1.0"
   type: deploy-record
   milestone: "M012"
   phase: "P04"
   deployed_url: "https://<gh-owner>.github.io/spec-kit-orchestrator/"
   commit_sha: "<40-char-sha>"
   deployed_at: "2026-04-21T00:00:00Z"
   deployer: "<github-handle>"
   gate_giscus_config_result: "pass"
   gate_mkdocs_build_result: "pass"
   gate_link_check_result: "pass"
   gate_giscus_smoke_result: "pass"
   ---

   # M012/P04 First-deploy record

   ## Deploy summary

   Deployed via `scripts/wiki/wiki-deploy.sh` from the repo root.
   Pushed to the `gh-pages` branch of this repository; GitHub Pages
   serves the built site from that branch.

   ## Wrapper output (abbreviated)

   ```
   GATE: giscus-config PASS
   BUILD: ok
   GATE: link-check PASS
   GATE: giscus-smoke PASS
   DEPLOY: pushing to gh-pages
   OK: deployed to gh-pages
   ```

   ## Notes

   - First deploy: creates the `gh-pages` branch and triggers an
     initial GitHub Pages build. Subsequent deploys reuse the branch
     and force-push the new built output.
   - GitHub Pages can take up to a minute to serve a freshly pushed
     `gh-pages` update. If the deployed URL returns 404 immediately
     after the wrapper exits 0, wait 60s and reload.
   - If `gh-pages` is a protected branch, `mkdocs gh-deploy --force`
     requires an administrator override. This is not the default;
     the wrapper assumes direct force-push is allowed.

   ## Pending-value path

   If `deployed_url` or `commit_sha` above reads `pending`, the record
   was written without network access at plan-execution time. A human
   operator must rerun `bash scripts/wiki/wiki-deploy.sh` and paste
   the real values before the M012 milestone closes.
   ```

   Fixture-path variant: replace `deployed_url` with the literal string `pending`, `commit_sha` with `pending`, and `deployed_at` with the agent's invocation timestamp (not `pending` — the record was written at a real time). Flip any gate whose result cannot be verified to `"skip"`.

4. **Do not** create any other file in this task. Do not modify the wrapper. Do not modify any upstream diagnostic. Constitution XV.

## Must-Haves

- `.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md` exists, ≥ 25 lines, and contains:
  - YAML frontmatter with `schema_version`, `type: deploy-record`, `milestone: "M012"`, `phase: "P04"`, `deployed_url`, `commit_sha`, `deployed_at`, `deployer`, and four `gate_*_result` fields (`giscus_config`, `mkdocs_build`, `link_check`, `giscus_smoke`).
  - The literal string `gh-pages` in the body.
  - The literal string `wiki-deploy.sh` in the body.
  - Each `gate_*_result` value is one of `pass`, `fail`, `skip`, or `pending`.
  - `deployed_url` is either a URL starting with `http` OR the literal sentinel `pending`.
  - `commit_sha` is either a 40-char hex string OR the literal sentinel `pending`.

## Verification

- Check: `bash scripts/verify/m012-p04-deploy-record.sh`
- Check: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P04`

## Inputs

### From Previous Tasks

- `scripts/wiki/wiki-deploy.sh` (from T03) — the wrapper the operator runs. DEPLOY-RECORD.md references it by basename. API: zero positional args; flags `--dry-run`, `--help`, `--root DIR`, `--skip-smoke`. Exit 0 on success; terminator line is `OK: deployed to <url>` or `DRY-RUN: would deploy`.
- `wiki/README.md` (from T02) — the operator reads the `## First-deploy checklist` to set up GitHub Pages + Discussions before step 1 of this task. Steps 1–5 of the checklist are prerequisites for the live deploy path here.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M012/phases/P04/` — the phase directory. Created during roadmap generation; the payload file lives here already.
- `mkdocs gh-deploy` behavior (external): on first invocation for a repo, creates the `gh-pages` orphan branch, commits the contents of `wiki/site/`, and pushes. `--force` overrides non-fast-forward safeguards. Source branch identification is inferred from `git remote get-url origin` and the current HEAD.
- GitHub Pages serving behavior (external): once `gh-pages` exists and Pages is configured with "Deploy from a branch → gh-pages → / (root)", GitHub serves `wiki/site/index.html` at `https://<owner>.github.io/<repo>/` within ~60s of push.

## Constraints

- **AD-3 SSOT** — DEPLOY-RECORD.md does not copy any canonical artifact body. It carries operational metadata only.
- **Constitution XV (surgical precision)** — T04 creates exactly one file.
- **Constitution XIV (no speculative complexity)** — no deploy-log parser, no HTML scraper, no URL liveness check. The record is a write-once operator artifact.
- **Loud failure tolerance** — if the live deploy fails partway through, the record still gets written with the failing gate's result set to `fail`. The operator then fixes the underlying issue, re-runs the wrapper, and updates the record.
- **Auto-mode safety** — the auto-mode path (sandbox, no network) writes `pending` sentinels. This is the `fixture-shaped` path mentioned in the phase-plan Truth. A human operator completes the record before the milestone closes.
- **Bash 3.2 compat** — T04 ships no shell scripts.

## Expected Output

- `.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md` exists with the schema above.
- If executed on the live path: the URL is reachable, every rendered page carries a Giscus thread, and SC-5 (a test comment persists across a redeploy) can be manually verified as part of the consolidation-phase UAT walkthrough in `P04-SUMMARY.md`.
- If executed on the fixture path: the `pending` sentinels are clearly present; the T05 gate passes; a human operator resumes the live deploy during consolidation.
