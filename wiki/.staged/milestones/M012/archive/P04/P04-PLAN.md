---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M012"
goal: "Finalize the dogfood wiki home page, extend `wiki/README.md` with the consolidated operator guide + first-deploy checklist, wire a single `scripts/wiki/wiki-deploy.sh` that chains the P03 Giscus config-check → `mkdocs build` → P02 link-check → P03 Giscus smoke-test → `mkdocs gh-deploy --force` (any gate failure aborts the deploy), perform the first deploy to the repo's `gh-pages` branch, and record the US1..US5 end-to-end walkthrough + SC-1..SC-11 verification in `P04-SUMMARY.md` at phase close."
demo_sentence: "From the repo root, a maintainer with `GISCUS_*` env vars set and `gh` on PATH runs `bash scripts/wiki/wiki-deploy.sh` — the script greps stdout showing `GATE: giscus-config PASS`, `BUILD: ok`, `GATE: link-check PASS`, `GATE: giscus-smoke PASS`, then `DEPLOY: pushing to gh-pages`, and exits 0. `bash scripts/wiki/wiki-deploy.sh --dry-run` prints the same four gate lines plus `DRY-RUN: would deploy` without touching the remote. `bash scripts/verify/m012-p04-phase-suite.sh` exits 0 after running every P04 gate. `wiki/docs/index.md` no longer contains the word `placeholder`; `wiki/README.md` carries a `## First-deploy checklist` section naming every GISCUS_* env var and the `gh-pages` branch. `.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md` records the deployed URL, the commit SHA, and the four gate results."
risk: "low"
depends_on: ["P01", "P02", "P03"]
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M012/P04 verification logic lives inside
     scripts/verify/m012-p04-*.sh files; the Check commands here invoke them.
     MEM004 carve-out applies to the internals of those scripts, not to these
     Check lines. -->

### Truths

- `wiki/docs/index.md` is the finalized home page (P01 placeholder replaced): contains a concise one-line project tagline, four orientation sections (What this site is / How to navigate / Where to comment / Audience scope), a "Deploy & preview" pointer to `wiki/README.md`, links by path to the five top-level rendered artifacts (constitution, decisions, knowledge, milestone-summary, milestones), and does NOT contain the word "placeholder". The file remains ≤ 120 lines (Constitution VI — a home page is not a documentation dump) and contains zero copied `.orchestrator/**.md` body text (AD-3 SSOT — every canonical artifact is reached via its stub route, never inlined here). US1 / SC-3.
  - Check: `bash scripts/verify/m012-p04-index-finalized.sh`

- `wiki/README.md` carries a `## First-deploy checklist` section naming — as literal strings — `GISCUS_REPO`, `GISCUS_REPO_ID`, `GISCUS_CATEGORY`, `GISCUS_CATEGORY_ID`, the `gh-pages` branch, the GitHub Discussions feature, the `discussions category` step, and the `mkdocs gh-deploy --force` command. The checklist references `scripts/wiki/wiki-deploy.sh` by name. US3 / SC-4 / SC-9.
  - Check: `bash scripts/verify/m012-p04-readme-first-deploy.sh`

- `scripts/wiki/wiki-deploy.sh` exists, is Bash 3.2 compatible, is executable, accepts `--dry-run`, `--help`, `--root <dir>`, and `--skip-smoke` flags, and on the live path chains exactly four gate-shaped invocations in order before deploy: (1) `scripts/diagnostics/wiki-giscus-config-check.sh`, (2) `mkdocs build -f wiki/mkdocs.yml`, (3) `scripts/diagnostics/wiki-link-check.sh --site wiki/site`, (4) `scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site`. Any non-zero exit from any gate aborts before `mkdocs gh-deploy --force` runs. Emits `GATE: <name> PASS|FAIL`, `BUILD: ok|fail`, `DEPLOY: pushing to gh-pages`, and one `DRY-RUN:` / `OK:` / `FAIL:` terminator line. US3 / SC-4 / SC-9 / FR-5 / FR-7.
  - Check: `bash scripts/verify/m012-p04-deploy-wrapper-contract.sh`

- `scripts/wiki/wiki-deploy.sh --help` prints a usage block naming each of the four chained gates (by basename) and each of the four supported flags (`--dry-run`, `--help`, `--root`, `--skip-smoke`), so an operator can discover the contract without reading the source.
  - Check: `bash scripts/verify/m012-p04-deploy-wrapper-help.sh`

- `scripts/wiki/wiki-deploy.sh --dry-run` exits 0 without invoking `mkdocs gh-deploy`, without writing to the `gh-pages` branch, and without making any `gh` API calls — verified by running it under an env with every `GISCUS_*` var set to `"x"` and asserting the four `GATE: ... PASS` lines plus the `DRY-RUN: would deploy` terminator land on stdout. If `mkdocs` is absent the dry-run emits `SKIP: mkdocs not installed` and still exits 0 (Tier 1 acceptable; strict build stays a Tier 4 UAT step per P01/P02/P03 conventions).
  - Check: `bash scripts/verify/m012-p04-deploy-wrapper-dry-run.sh`

- When `GISCUS_REPO_ID` is unset, `scripts/wiki/wiki-deploy.sh` aborts at gate (1) with exit 1 and a diagnostic line naming the missing env var — it does NOT silently deploy an empty-Giscus site (Constitution VI cross-cutting concern "Loud failure on missing external config"; SC-9).
  - Check: `bash scripts/verify/m012-p04-deploy-wrapper-loud-fail.sh`

- [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../../../milestones/M012/phases/P04/DEPLOY-RECORD.md) records the first deploy with a YAML-frontmatter record carrying: `deployed_url`, `commit_sha`, `deployed_at` (ISO-8601), and four `gate_*_result: pass|fail|skip` fields — one each for `giscus_config`, `mkdocs_build`, `link_check`, `giscus_smoke`. Body section names the `gh-pages` branch and links to the deploy wrapper. First deploy may be manually executed by the operator; auto-mode tolerates a fixture-shaped deploy record so Tier 1 verify is green in sandboxes without network access (fixture `deployed_url: pending` sentinel is accepted by the gate).
  - Check: `bash scripts/verify/m012-p04-deploy-record.sh`

- `wiki/docs/index.md` — zero `.orchestrator/**.md` body text copied in. The SSOT gate reuses the P01 ≤ 25-line threshold with a P04 override to 120 lines (one home page deserves orientation prose) but still refuses any paragraph that appears verbatim in an upstream stub target. Constitution VI + AD-3.
  - Check: `bash scripts/verify/m012-p04-index-ssot.sh`

- Every `.sh` file touched or created by P04 (`scripts/wiki/wiki-deploy.sh`, every `scripts/verify/m012-p04-*.sh`) is Bash 3.2 compatible — no `declare -A`, no `mapfile`/`readarray`, no `${var^^}`/`${var,,}`, no `<(…)`/`>(…)` process substitution, no `&>` merge redirect in non-comment code (Constitution VIII, SC-11, MEM001). Self-inclusive with assignment-line carve-out mirroring the P02/P03 compat pattern.
  - Check: `bash scripts/verify/m012-p04-bash32-compat.sh`

- `wiki/` remains self-contained after P04 — `git rm -r wiki/` plus removal of `scripts/wiki/` plus removal of `scripts/diagnostics/wiki-*.sh` plus removal of `scripts/verify/m012-p0[1-4]-*.sh` does not break the orchestrator (no test, no script outside the wiki blast radius imports or invokes P04 artifacts). Extends the P03 allow-list for `scripts/verify/m012-p04-*.sh` and `scripts/wiki/wiki-deploy.sh`. SC-10 / Constitution VI.
  - Check: `bash scripts/verify/m012-p04-wiki-removable.sh`

- `P04-SUMMARY.md` (written at phase close, not during task execution — this Truth is Tier 3 at plan time and promotes to Tier 1 once the summary lands) walks each of M012 User Stories US1..US5 end-to-end against the deployed site, and enumerates SC-1..SC-11 with a `pass|fail|skip` verdict + one-line evidence pointer each. The phase-suite gate below surfaces a SKIP marker until the summary exists; `check-must-haves.sh` promotes it to Tier 1 post-write.
  - Check: `bash scripts/verify/m012-p04-summary-walkthrough.sh`

- `bash scripts/verify/m012-p04-phase-suite.sh` orchestrates all ten P04 gates and exits 0 only when every gate exits 0. Mirrors the P03 parallel-indexed-variable orchestrator.
  - Check: `bash scripts/verify/m012-p04-phase-suite.sh`

### Artifacts

- `wiki/docs/index.md` (min 40 lines, contains "How to navigate") — finalized home page replacing the P01 placeholder. Must no longer contain the literal word "placeholder".
- `wiki/README.md` (min 300 lines, contains "First-deploy checklist") — extended from P03's 276 lines with `## First-deploy checklist` + `## Running the deploy wrapper` sections.
- `scripts/wiki/wiki-deploy.sh` (min 120 lines, contains "mkdocs gh-deploy") — chained deploy wrapper.
- [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../../../milestones/M012/phases/P04/DEPLOY-RECORD.md) (min 25 lines, contains "gh-pages") — first-deploy record with YAML frontmatter + gate-result fields.
- `scripts/verify/m012-p04-index-finalized.sh` (min 30 lines, contains "placeholder") — asserts P01 placeholder prose is gone and required orientation sections are present.
- `scripts/verify/m012-p04-index-ssot.sh` (min 30 lines, contains "SSOT") — asserts no `.orchestrator/**.md` body text is inlined into the home page.
- `scripts/verify/m012-p04-readme-first-deploy.sh` (min 40 lines, contains "GISCUS_REPO_ID") — asserts checklist section + required env-var names + `gh-pages` mention + `wiki-deploy.sh` reference.
- `scripts/verify/m012-p04-deploy-wrapper-contract.sh` (min 60 lines, contains "wiki-deploy.sh") — asserts the wrapper chains the four gate invocations in order and honors the four flags.
- `scripts/verify/m012-p04-deploy-wrapper-help.sh` (min 25 lines, contains "--help") — asserts `--help` names every chained gate basename and every supported flag.
- `scripts/verify/m012-p04-deploy-wrapper-dry-run.sh` (min 50 lines, contains "DRY-RUN") — runs the wrapper under a fixture env and asserts no `gh-pages` push happens.
- `scripts/verify/m012-p04-deploy-wrapper-loud-fail.sh` (min 40 lines, contains "GISCUS_REPO_ID") — runs the wrapper under a fixture env with `GISCUS_REPO_ID` unset and asserts exit 1.
- `scripts/verify/m012-p04-deploy-record.sh` (min 40 lines, contains "gh-pages") — asserts the DEPLOY-RECORD.md YAML frontmatter schema + required fields.
- `scripts/verify/m012-p04-bash32-compat.sh` (min 40 lines, contains "declare -A") — self-inclusive Bash 3.2 compat scan with assignment-line carve-out.
- `scripts/verify/m012-p04-wiki-removable.sh` (min 30 lines, contains "wiki-deploy.sh") — extends P01 self-contained gate to the P04 surface; mirrors the P03 pattern.
- `scripts/verify/m012-p04-summary-walkthrough.sh` (min 40 lines, contains "SC-1") — asserts `P04-SUMMARY.md` (when present) names US1..US5 and enumerates SC-1..SC-11 each with a verdict token.
- `scripts/verify/m012-p04-phase-suite.sh` (min 50 lines, contains "m012-p04") — phase-suite orchestrator.

### Key Links

- `wiki/docs/index.md` → `constitution` (home page points at the constitution stub route)
- `wiki/docs/index.md` → `decisions` (home page points at the decisions stub route)
- `wiki/docs/index.md` → `knowledge` (home page points at the knowledge section index route)
- `wiki/docs/index.md` → `milestones` (home page points at the milestones section index route)
- `wiki/README.md` → `wiki-deploy.sh` (operator guide references the deploy wrapper by basename)
- `wiki/README.md` → `First-deploy checklist` (documented section heading)
- `wiki/README.md` → `gh-pages` (documents the GitHub Pages branch name)
- `scripts/wiki/wiki-deploy.sh` → `wiki-giscus-config-check.sh` (wrapper invokes P03 pre-build gate)
- `scripts/wiki/wiki-deploy.sh` → `wiki-link-check.sh` (wrapper invokes P02 link-checker against the built site)
- `scripts/wiki/wiki-deploy.sh` → `wiki-giscus-smoke.sh` (wrapper invokes P03 post-build smoke walker)
- `scripts/wiki/wiki-deploy.sh` → `mkdocs gh-deploy` (wrapper invokes the deploy command)
- [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../../../milestones/M012/phases/P04/DEPLOY-RECORD.md) → `wiki-deploy.sh` (record references the wrapper)
- `scripts/verify/m012-p04-phase-suite.sh` → `scripts/verify/m012-p04-index-finalized.sh` (orchestrated gate)
- `scripts/verify/m012-p04-phase-suite.sh` → `scripts/verify/m012-p04-index-ssot.sh` (orchestrated gate)
- `scripts/verify/m012-p04-phase-suite.sh` → `scripts/verify/m012-p04-readme-first-deploy.sh` (orchestrated gate)
- `scripts/verify/m012-p04-phase-suite.sh` → `scripts/verify/m012-p04-deploy-wrapper-contract.sh` (orchestrated gate)
- `scripts/verify/m012-p04-phase-suite.sh` → `scripts/verify/m012-p04-deploy-wrapper-help.sh` (orchestrated gate)
- `scripts/verify/m012-p04-phase-suite.sh` → `scripts/verify/m012-p04-deploy-wrapper-dry-run.sh` (orchestrated gate)
- `scripts/verify/m012-p04-phase-suite.sh` → `scripts/verify/m012-p04-deploy-wrapper-loud-fail.sh` (orchestrated gate)
- `scripts/verify/m012-p04-phase-suite.sh` → `scripts/verify/m012-p04-deploy-record.sh` (orchestrated gate)
- `scripts/verify/m012-p04-phase-suite.sh` → `scripts/verify/m012-p04-bash32-compat.sh` (orchestrated gate)
- `scripts/verify/m012-p04-phase-suite.sh` → `scripts/verify/m012-p04-wiki-removable.sh` (orchestrated gate)
- `scripts/verify/m012-p04-phase-suite.sh` → `scripts/verify/m012-p04-summary-walkthrough.sh` (orchestrated gate)

## Tasks

### T01: Finalized `wiki/docs/index.md` home page (replace P01 placeholder) + index SSOT guard

See `.orchestrator/milestones/M012/phases/P04/tasks/T01-PLAN.md`.

### T02: `wiki/README.md` first-deploy checklist + deploy-wrapper section

See `.orchestrator/milestones/M012/phases/P04/tasks/T02-PLAN.md`.

### T03: `scripts/wiki/wiki-deploy.sh` — chained deploy wrapper (config-check → build → link-check → smoke → gh-deploy)

See `.orchestrator/milestones/M012/phases/P04/tasks/T03-PLAN.md`.

### T04: First-deploy execution + `DEPLOY-RECORD.md`

See `.orchestrator/milestones/M012/phases/P04/tasks/T04-PLAN.md`.

### T05: Phase verification suite — eleven gates + phase-suite orchestrator

See `.orchestrator/milestones/M012/phases/P04/tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04 ──► T05
```

Strict linear chain.

- **T01** replaces the P01 `wiki/docs/index.md` placeholder with finalized orientation content. Must land first so the home page links downstream tasks will cite are in place, and so the SSOT guard (T05) has something to scan.
- **T02** extends `wiki/README.md` with the `## First-deploy checklist` and `## Running the deploy wrapper` sections. Runs after T01 so the README can point at the finalized home page. Runs before T03 so the wrapper's `--help` output can reference the README sections by heading.
- **T03** ships `scripts/wiki/wiki-deploy.sh` — the single documented deploy command. Runs after T02 so the README's first-deploy checklist names the wrapper authoritatively. Runs before T04 because T04 is the first real invocation.
- **T04** performs the first deploy (operator-driven; auto-mode tolerates the `pending` sentinel in DEPLOY-RECORD.md) and writes the record. Runs after T03 so the wrapper exists.
- **T05** ships the eleven M012/P04 verification gates + phase-suite orchestrator, each gate targeting one of T01–T04's outputs plus the cross-cutting Bash 3.2 and wiki-removable invariants.

## Files Likely Touched

- `wiki/docs/index.md` (modify — replace P01 placeholder with finalized home page; ≤ 120 lines; zero body-copy from `.orchestrator/**.md`)
- `wiki/README.md` (modify — append `## First-deploy checklist` + `## Running the deploy wrapper` sections after P03's Giscus-mapping block)
- `scripts/wiki/wiki-deploy.sh` (create — chained deploy wrapper with `--dry-run`, `--help`, `--root`, `--skip-smoke` flags)
- [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../../../milestones/M012/phases/P04/DEPLOY-RECORD.md) (create — YAML-frontmatter record of the first deploy; fixture sentinel `deployed_url: pending` tolerated by Tier 1 gate)
- `scripts/verify/m012-p04-index-finalized.sh` (create)
- `scripts/verify/m012-p04-index-ssot.sh` (create)
- `scripts/verify/m012-p04-readme-first-deploy.sh` (create)
- `scripts/verify/m012-p04-deploy-wrapper-contract.sh` (create)
- `scripts/verify/m012-p04-deploy-wrapper-help.sh` (create)
- `scripts/verify/m012-p04-deploy-wrapper-dry-run.sh` (create)
- `scripts/verify/m012-p04-deploy-wrapper-loud-fail.sh` (create)
- `scripts/verify/m012-p04-deploy-record.sh` (create)
- `scripts/verify/m012-p04-bash32-compat.sh` (create)
- `scripts/verify/m012-p04-wiki-removable.sh` (create)
- `scripts/verify/m012-p04-summary-walkthrough.sh` (create)
- `scripts/verify/m012-p04-phase-suite.sh` (create)
- `scripts/verify/m012-p01-wiki-self-contained.sh` (modify — extend the containment allow-list to include `scripts/verify/m012-p04-*.sh` and `scripts/wiki/wiki-deploy.sh`, mirroring the P02/P03 extension pattern)
