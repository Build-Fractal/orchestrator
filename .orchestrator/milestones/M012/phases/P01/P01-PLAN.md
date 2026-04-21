---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M012"
goal: "Scaffold the dogfood wiki: a self-contained wiki/ directory with MkDocs Material + mkdocs-include-markdown-plugin configured to render every in-scope .orchestrator/**.md artifact from its canonical path (zero copies, zero symlinks — AD-3), behind a navigable sidebar (Constitution / Decisions / Knowledge / Milestone Summary / Milestones expandable / Archive labeled), with a documented exclusion policy enforced by Bash 3.2 helper scripts."
demo_sentence: "From the repo root, a developer runs bash scripts/wiki/wiki-serve.sh and MkDocs boots a localhost preview that lists Constitution, Decisions, Knowledge, Milestone Summary, every milestone's CONTEXT/EVALUATION/ROADMAP/SUMMARY plus phases and tasks, and an Archive section — each page rendering content from .orchestrator/ via the include plugin (confirmed by bash scripts/verify/m012-p01-ssot.sh finding zero copied .md files under wiki/docs/), with .orchestrator/scratch/, .orchestrator/tmp/, .orchestrator/config/ and all non-markdown files excluded (confirmed by bash scripts/verify/m012-p01-exclusion-policy.sh), and bash scripts/verify/m012-p01-phase-suite.sh exiting 0."
risk: "low"
depends_on: []
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M012/P01 verification logic lives inside
     scripts/verify/m012-p01-*.sh files; the Check commands here invoke them. -->

### Truths

- `wiki/` is a self-contained directory holding the full wiki toolchain — removing it does not break the orchestrator (SC-10, Constitution VI).
  - Check: `bash scripts/verify/m012-p01-wiki-self-contained.sh`

- `wiki/requirements.txt` pins exact versions for MkDocs, Material theme, and `mkdocs-include-markdown-plugin` (or the selected include-plugin equivalent) so deploys are reproducible (M012-CONTEXT constraint "MkDocs version pinned").
  - Check: `bash scripts/verify/m012-p01-requirements-pinned.sh`

- `wiki/mkdocs.yml` loads the include plugin and declares a Material theme with navigation enabled; every in-scope `.orchestrator/**.md` artifact has a corresponding stub under `wiki/docs/` that includes the canonical path via the plugin — never by copy (AD-3, SC-1).
  - Check: `bash scripts/verify/m012-p01-include-plugin.sh`

- No `.orchestrator/**.md` file is duplicated under `wiki/docs/` — every `.md` file in `wiki/docs/` is either the placeholder `index.md`, a thin include stub (fewer than 25 lines), or an auto-generated section index; no canonical artifact body lives in two places (AD-3, Constitution VI).
  - Check: `bash scripts/verify/m012-p01-ssot.sh`

- Exclusion policy is enforced: no stub renders content from `.orchestrator/scratch/`, `.orchestrator/tmp/`, `.orchestrator/config/`, or any non-markdown file (FR-8, spec Boundary Map).
  - Check: `bash scripts/verify/m012-p01-exclusion-policy.sh`

- Navigation includes (in order) Constitution, Decisions, Knowledge, Milestone Summary, a Milestones section with one expandable entry per in-scope `.orchestrator/milestones/M###/` directory, and an "Archive" labeled section listing every in-scope `.orchestrator/archive/**` milestone (US1 AS-1, AD-4, AD-6).
  - Check: `bash scripts/verify/m012-p01-nav-structure.sh`

- `bash scripts/wiki/wiki-serve.sh` boots `mkdocs serve` against `wiki/mkdocs.yml` from the repo root (no manual `cd`, no chained shell) and returns the underlying mkdocs exit code; a probe-mode invocation validates the configuration without binding a port so auto-mode can run it headless (US1 implicit; FR-7; SC-8; AD-19).
  - Check: `bash scripts/verify/m012-p01-serve-smoke.sh`

- `wiki/docs/index.md` is a one-screen placeholder home page (body short, clearly labeled "placeholder, finalized in P04") so P04 has a known slot to replace (Boundary Map; AD phase sequencing).
  - Check: `bash scripts/verify/m012-p01-index-placeholder.sh`

- Every P01-touched and P01-created `.sh` file is bash 3.2 compatible — no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>` (Constitution VIII, SC-11, MEM001).
  - Check: `bash scripts/verify/m012-p01-bash32-compat.sh`

- `bash scripts/verify/m012-p01-phase-suite.sh` orchestrates all nine P01 gates and exits 0 on green.
  - Check: `bash scripts/verify/m012-p01-phase-suite.sh`

### Artifacts

- `wiki/requirements.txt` (min 4 lines, contains "mkdocs-material")
- `wiki/mkdocs.yml` (min 40 lines, contains "include-markdown")
- `wiki/docs/index.md` (min 10 lines, contains "placeholder")
- `wiki/docs/README.md` (min 18 lines, contains "auto-generated") — documents that stubs under `wiki/docs/` are produced by the generator and must not be hand-edited
- `wiki/README.md` (min 30 lines, contains "mkdocs serve") — operator notes: install, preview, generator
- `scripts/wiki/wiki-scan-sources.sh` (min 60 lines, contains ".orchestrator") — lists every in-scope `.orchestrator/**.md` path; honors exclusion policy
- `scripts/wiki/wiki-generate-stubs.sh` (min 80 lines, contains "include-markdown") — emits one stub per in-scope artifact under `wiki/docs/` and generates the nav-fragment file
- `scripts/wiki/wiki-generate-nav.sh` (min 60 lines, contains "Constitution") — assembles the nav list (Constitution, Decisions, Knowledge, Milestone Summary, Milestones, Archive) and writes it into `wiki/mkdocs.yml`
- `scripts/wiki/wiki-serve.sh` (min 20 lines, contains "mkdocs serve") — single-script launcher; supports `--probe` for headless config validation
- `scripts/verify/m012-p01-wiki-self-contained.sh` (min 20 lines, contains "wiki/")
- `scripts/verify/m012-p01-requirements-pinned.sh` (min 20 lines, contains "==")
- `scripts/verify/m012-p01-include-plugin.sh` (min 30 lines, contains "include-markdown")
- `scripts/verify/m012-p01-ssot.sh` (min 30 lines, contains "include-markdown")
- `scripts/verify/m012-p01-exclusion-policy.sh` (min 30 lines, contains "scratch")
- `scripts/verify/m012-p01-nav-structure.sh` (min 40 lines, contains "Archive")
- `scripts/verify/m012-p01-serve-smoke.sh` (min 30 lines, contains "mkdocs")
- `scripts/verify/m012-p01-index-placeholder.sh` (min 15 lines, contains "placeholder")
- `scripts/verify/m012-p01-bash32-compat.sh` (min 40 lines, contains "declare -A")
- `scripts/verify/m012-p01-phase-suite.sh` (min 40 lines, contains "m012-p01")

### Key Links

- `wiki/mkdocs.yml` → `include-markdown` (plugins block registers the plugin by its MkDocs plugin name; PyPI package is `mkdocs-include-markdown-plugin`)
- `scripts/wiki/wiki-generate-stubs.sh` → `scripts/wiki/wiki-scan-sources.sh` (stubs generator consumes scan output)
- `scripts/wiki/wiki-generate-nav.sh` → `scripts/wiki/wiki-scan-sources.sh` (nav generator consumes same scan output)
- `scripts/wiki/wiki-serve.sh` → `wiki/mkdocs.yml` (launcher targets this config)
- `scripts/verify/m012-p01-phase-suite.sh` → `scripts/verify/m012-p01-wiki-self-contained.sh` (orchestrated gate)
- `scripts/verify/m012-p01-phase-suite.sh` → `scripts/verify/m012-p01-requirements-pinned.sh` (orchestrated gate)
- `scripts/verify/m012-p01-phase-suite.sh` → `scripts/verify/m012-p01-include-plugin.sh` (orchestrated gate)
- `scripts/verify/m012-p01-phase-suite.sh` → `scripts/verify/m012-p01-ssot.sh` (orchestrated gate)
- `scripts/verify/m012-p01-phase-suite.sh` → `scripts/verify/m012-p01-exclusion-policy.sh` (orchestrated gate)
- `scripts/verify/m012-p01-phase-suite.sh` → `scripts/verify/m012-p01-nav-structure.sh` (orchestrated gate)
- `scripts/verify/m012-p01-phase-suite.sh` → `scripts/verify/m012-p01-serve-smoke.sh` (orchestrated gate)
- `scripts/verify/m012-p01-phase-suite.sh` → `scripts/verify/m012-p01-index-placeholder.sh` (orchestrated gate)
- `scripts/verify/m012-p01-phase-suite.sh` → `scripts/verify/m012-p01-bash32-compat.sh` (orchestrated gate)

## Tasks

### T01: wiki/ skeleton — requirements.txt, mkdocs.yml base, index placeholder, wiki-serve.sh

See `.orchestrator/milestones/M012/phases/P01/tasks/T01-PLAN.md`.

### T02: wiki-scan-sources.sh — in-scope artifact enumerator with exclusion policy

See `.orchestrator/milestones/M012/phases/P01/tasks/T02-PLAN.md`.

### T03: wiki-generate-stubs.sh — include-plugin stubs for every in-scope .orchestrator/**.md

See `.orchestrator/milestones/M012/phases/P01/tasks/T03-PLAN.md`.

### T04: wiki-generate-nav.sh — Constitution / Decisions / Knowledge / Milestone Summary / Milestones / Archive nav assembly

See `.orchestrator/milestones/M012/phases/P01/tasks/T04-PLAN.md`.

### T05: Phase verification suite — nine gates + phase-suite orchestrator

See `.orchestrator/milestones/M012/phases/P01/tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04 ──► T05
```

Strict linear chain. T01 creates the `wiki/` skeleton so downstream scripts have a target directory. T02 ships the single source of truth for "what is in scope" (scan output) that both T03 (stub generator) and T04 (nav generator) consume. T03 produces the stubs T04's nav references. T05 wires the nine verification gates and the phase-suite orchestrator that drives them.

## Files Likely Touched

- `wiki/` (create — directory)
- `wiki/requirements.txt` (create)
- `wiki/mkdocs.yml` (create in T01; extended by T04 with nav block)
- `wiki/docs/index.md` (create — placeholder)
- `wiki/docs/README.md` (create — authoring note)
- `wiki/README.md` (create — operator notes)
- `wiki/.gitignore` (create — ignore generated `site/` output)
- `scripts/wiki/wiki-scan-sources.sh` (create)
- `scripts/wiki/wiki-generate-stubs.sh` (create)
- `scripts/wiki/wiki-generate-nav.sh` (create)
- `scripts/wiki/wiki-serve.sh` (create)
- `scripts/verify/m012-p01-wiki-self-contained.sh` (create)
- `scripts/verify/m012-p01-requirements-pinned.sh` (create)
- `scripts/verify/m012-p01-include-plugin.sh` (create)
- `scripts/verify/m012-p01-ssot.sh` (create)
- `scripts/verify/m012-p01-exclusion-policy.sh` (create)
- `scripts/verify/m012-p01-nav-structure.sh` (create)
- `scripts/verify/m012-p01-serve-smoke.sh` (create)
- `scripts/verify/m012-p01-index-placeholder.sh` (create)
- `scripts/verify/m012-p01-bash32-compat.sh` (create)
- `scripts/verify/m012-p01-phase-suite.sh` (create)
- `wiki/docs/**/*.md` (create — thin include stubs, one per in-scope `.orchestrator/**.md`; generated by T03)
