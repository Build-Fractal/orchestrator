---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M012"
goal: "Attach a Giscus comment thread to every rendered page via the MkDocs Material theme-override mechanism (AD-3 — no body-copy injection), fail the build loudly when Giscus config is missing, ship a smoke-test that walks the built site and asserts a Giscus <script> block on every generated HTML page, and ship a Bash 3.2 idempotent remap script that migrates thread mappings when an artifact is consolidated/renamed."
demo_sentence: "From the repo root, a developer runs (cd wiki && mkdocs build) and every HTML page under wiki/site/ ends with a Giscus <script> tag (confirmed by bash scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site exiting 0); unsetting GISCUS_REPO_ID and rerunning the build fails with a clear diagnostic (confirmed by bash scripts/verify/m012-p03-config-loud-fail.sh); running bash scripts/diagnostics/wiki-giscus-remap.sh --dry-run old/path new/path prints the rename operations without executing them; bash scripts/verify/m012-p03-phase-suite.sh exits 0."
risk: "medium"
depends_on: ["P01"]
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M012/P03 verification logic lives inside
     scripts/verify/m012-p03-*.sh files; the Check commands here invoke them. -->

### Truths

- `wiki/overrides/partials/comments.html` exists and renders a Giscus `<script>` tag using MkDocs Material's comments-partial override mechanism, driven by values from `mkdocs.yml`'s `extra.giscus.*` block (AD-3 SSOT — comments are injected by the theme, not by rewriting artifact bodies).
  - Check: `bash scripts/verify/m012-p03-comments-partial.sh`

- `wiki/mkdocs.yml` declares `theme.custom_dir: overrides` and carries an `extra.giscus` configuration block with the five required keys (`repo`, `repo_id`, `category`, `category_id`, `mapping`) interpolated from environment variables (`GISCUS_REPO`, `GISCUS_REPO_ID`, `GISCUS_CATEGORY`, `GISCUS_CATEGORY_ID`) — no production IDs are hardcoded (Constraint "Config placement", US2 AS-5, FR-4).
  - Check: `bash scripts/verify/m012-p03-mkdocs-giscus-config.sh`

- Giscus `mapping` is set to `pathname` and the tradeoffs for rename/move are documented in `wiki/README.md` under a "Giscus mapping" section that names the strategy and cites the remap script as the recovery path (AD-5 / SC-7 / US5).
  - Check: `bash scripts/verify/m012-p03-mapping-documented.sh`

- The build fails loudly with a clear diagnostic when any required Giscus env var is unset at build time — either via `mkdocs build` exiting non-zero with a resolvable error message, or via an explicit pre-build gate (`scripts/diagnostics/wiki-giscus-config-check.sh`) that exits non-zero before mkdocs runs (US2 AS-5 / SC-9).
  - Check: `bash scripts/verify/m012-p03-config-loud-fail.sh`

- `scripts/diagnostics/wiki-giscus-smoke.sh` walks every `*.html` file under a built-site directory and asserts each page contains a `<script src="https://giscus.app/client.js"` tag; emits `PASS: <count> pages have Giscus` or `FAIL: <path>` on any miss; Bash 3.2 compliant; single-invocation script-file shape (SC-2 / Boundary Map Produces).
  - Check: `bash scripts/verify/m012-p03-smoke-contract.sh`

- `scripts/diagnostics/wiki-giscus-remap.sh` accepts `<old-path> <new-path>` argument pairs, supports `--dry-run` and `--help` flags, is idempotent (rerunning after a successful remap emits `NOOP: <path>` rather than double-renaming), requires `gh` on PATH for non-dry-run mode, and relies on the Giscus Discussion whose title equals the original pathname (pathname mapping contract). Bash 3.2 compliant. Usage is documented in `wiki/README.md` (Boundary Map Produces / US5).
  - Check: `bash scripts/verify/m012-p03-remap-contract.sh`

- Every `.sh` file created by P03 (`scripts/diagnostics/wiki-giscus-*.sh`, `scripts/verify/m012-p03-*.sh`) is Bash 3.2 compatible — no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `>(…)`, no `&>` in non-comment code (Constitution VIII, SC-11, MEM001).
  - Check: `bash scripts/verify/m012-p03-bash32-compat.sh`

- `wiki/` removes cleanly — `git rm -r wiki/` (on a scratch branch) plus removal of `scripts/wiki/` and `scripts/diagnostics/wiki-giscus-*.sh` plus removal of `scripts/verify/m012-p03-*.sh` does not break the orchestrator (no other file under the repo sources or imports the Giscus partials, smoke, or remap scripts — SC-10, Constitution VI).
  - Check: `bash scripts/verify/m012-p03-wiki-removable.sh`

- `bash scripts/verify/m012-p03-phase-suite.sh` orchestrates all eight P03 gates and exits 0 only when every gate exits 0.
  - Check: `bash scripts/verify/m012-p03-phase-suite.sh`

### Artifacts

- `wiki/overrides/partials/comments.html` (min 25 lines, contains "giscus.app/client.js")
- `wiki/mkdocs.yml` (min 60 lines, contains "custom_dir") — P01 base + P03 extension; the P03 addition introduces `theme.custom_dir: overrides` and an `extra.giscus` block with env-interpolated values
- `wiki/README.md` (min 60 lines, contains "Giscus mapping") — extended from P01/P02 with the Giscus mapping tradeoff section + remap usage
- `scripts/diagnostics/wiki-giscus-config-check.sh` (min 40 lines, contains "GISCUS_REPO_ID") — pre-build gate; exits non-zero if any of the five required env vars is empty/unset
- `scripts/diagnostics/wiki-giscus-smoke.sh` (min 50 lines, contains "giscus.app/client.js") — walks built HTML site and asserts Giscus tag on every page
- `scripts/diagnostics/wiki-giscus-remap.sh` (min 80 lines, contains "pathname") — idempotent Giscus Discussion title remapper driven by `gh api`
- `scripts/verify/m012-p03-comments-partial.sh` (min 25 lines, contains "comments.html")
- `scripts/verify/m012-p03-mkdocs-giscus-config.sh` (min 30 lines, contains "custom_dir")
- `scripts/verify/m012-p03-mapping-documented.sh` (min 20 lines, contains "pathname")
- `scripts/verify/m012-p03-config-loud-fail.sh` (min 40 lines, contains "GISCUS_REPO_ID")
- `scripts/verify/m012-p03-smoke-contract.sh` (min 40 lines, contains "wiki-giscus-smoke.sh")
- `scripts/verify/m012-p03-remap-contract.sh` (min 40 lines, contains "wiki-giscus-remap.sh")
- `scripts/verify/m012-p03-bash32-compat.sh` (min 40 lines, contains "declare -A")
- `scripts/verify/m012-p03-wiki-removable.sh` (min 30 lines, contains "wiki-giscus")
- `scripts/verify/m012-p03-phase-suite.sh` (min 40 lines, contains "m012-p03")

### Key Links

- `wiki/mkdocs.yml` → `overrides` (Material `theme.custom_dir: overrides` wiring — the partial is served from `wiki/overrides/partials/comments.html`)
- `wiki/overrides/partials/comments.html` → `giscus.app/client.js` (the Giscus loader script the partial injects)
- `wiki/README.md` → `wiki-giscus-remap.sh` (documentation references the remap script by basename)
- `wiki/README.md` → `wiki-giscus-smoke.sh` (documentation references the smoke script by basename)
- `scripts/diagnostics/wiki-giscus-smoke.sh` → `giscus.app/client.js` (the string the smoke script greps for)
- `scripts/diagnostics/wiki-giscus-remap.sh` → `wiki-giscus-smoke.sh` (the remap script's README references the smoke script as its verification counterpart)
- `scripts/verify/m012-p03-phase-suite.sh` → `scripts/verify/m012-p03-comments-partial.sh` (orchestrated gate)
- `scripts/verify/m012-p03-phase-suite.sh` → `scripts/verify/m012-p03-mkdocs-giscus-config.sh` (orchestrated gate)
- `scripts/verify/m012-p03-phase-suite.sh` → `scripts/verify/m012-p03-mapping-documented.sh` (orchestrated gate)
- `scripts/verify/m012-p03-phase-suite.sh` → `scripts/verify/m012-p03-config-loud-fail.sh` (orchestrated gate)
- `scripts/verify/m012-p03-phase-suite.sh` → `scripts/verify/m012-p03-smoke-contract.sh` (orchestrated gate)
- `scripts/verify/m012-p03-phase-suite.sh` → `scripts/verify/m012-p03-remap-contract.sh` (orchestrated gate)
- `scripts/verify/m012-p03-phase-suite.sh` → `scripts/verify/m012-p03-bash32-compat.sh` (orchestrated gate)
- `scripts/verify/m012-p03-phase-suite.sh` → `scripts/verify/m012-p03-wiki-removable.sh` (orchestrated gate)

## Tasks

### T01: Material comments-partial override + mkdocs.yml extra.giscus block

See `.orchestrator/milestones/M012/phases/P03/tasks/T01-PLAN.md`.

### T02: wiki-giscus-config-check.sh — loud-fail pre-build gate for missing Giscus env vars

See `.orchestrator/milestones/M012/phases/P03/tasks/T02-PLAN.md`.

### T03: wiki-giscus-smoke.sh — built-site HTML walker asserting Giscus script tag on every page

See `.orchestrator/milestones/M012/phases/P03/tasks/T03-PLAN.md`.

### T04: wiki-giscus-remap.sh — idempotent Discussion-title remap + wiki/README.md mapping docs

See `.orchestrator/milestones/M012/phases/P03/tasks/T04-PLAN.md`.

### T05: Phase verification suite — eight gates + phase-suite orchestrator

See `.orchestrator/milestones/M012/phases/P03/tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04 ──► T05
```

Strict linear chain.

- T01 extends `wiki/mkdocs.yml` with `theme.custom_dir: overrides` + `extra.giscus` env-interpolated block and ships the theme override partial so the build actually emits Giscus script tags — downstream smoke + config-check gates have something to verify against.
- T02 ships the pre-build config-check diagnostic that T01's README updates will cite; it is written after T01 so it can reference the exact env var names T01 chose.
- T03 ships the smoke-test that reads the output of a T01-driven `mkdocs build`; it depends on T01 for the tag to find and on T02's config-check contract so the two scripts compose cleanly in the P04 deploy pipeline.
- T04 ships the remap script + `wiki/README.md` mapping section that references T03's smoke script and T01's mapping choice.
- T05 ships the eight M012/P03 verification gates + phase-suite orchestrator, each gate targeting one of T01–T04's outputs.

## Files Likely Touched

- `wiki/overrides/` (create — directory; Material theme override root)
- `wiki/overrides/partials/` (create — directory)
- `wiki/overrides/partials/comments.html` (create — Giscus partial)
- `wiki/mkdocs.yml` (modify — add `theme.custom_dir: overrides` and `extra.giscus` block; the P01-owned `# >>> M012-P01 nav` marker-bounded block remains untouched)
- `wiki/README.md` (modify — append "Giscus mapping" + "Remapping threads after consolidation" sections)
- `scripts/diagnostics/wiki-giscus-config-check.sh` (create)
- `scripts/diagnostics/wiki-giscus-smoke.sh` (create)
- `scripts/diagnostics/wiki-giscus-remap.sh` (create)
- `scripts/verify/m012-p03-comments-partial.sh` (create)
- `scripts/verify/m012-p03-mkdocs-giscus-config.sh` (create)
- `scripts/verify/m012-p03-mapping-documented.sh` (create)
- `scripts/verify/m012-p03-config-loud-fail.sh` (create)
- `scripts/verify/m012-p03-smoke-contract.sh` (create)
- `scripts/verify/m012-p03-remap-contract.sh` (create)
- `scripts/verify/m012-p03-bash32-compat.sh` (create)
- `scripts/verify/m012-p03-wiki-removable.sh` (create)
- `scripts/verify/m012-p03-phase-suite.sh` (create)
