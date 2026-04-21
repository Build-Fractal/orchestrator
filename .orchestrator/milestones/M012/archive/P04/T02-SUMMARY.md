---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M012"
provides:
  - "wiki/README.md extended from 276 lines to 420 lines with two appended sections (## First-deploy checklist — 8 ordered steps naming Discussions prerequisite, Wiki Comments discussions category, four GISCUS_* env vars, gh-pages branch source, wiki-deploy.sh invocation, DEPLOY-RECORD.md recording, deployed-URL smoke test; ## Running the deploy wrapper — pipeline/flags/output-lines/exit-codes/failure-triage reference for scripts/wiki/wiki-deploy.sh). No other README sections modified"
requires:
  - "from:M012/P04/T01 what:wiki/docs/index.md points home-page readers at wiki/README.md — T02's ## Running the deploy wrapper is the section that pointer lands on; from:M012/P01/P02/P03 what:existing wiki/README.md sections (Install / Preview / Regenerate / Scope / Link resolution / Running the link checker / Pre-deploy integration / Giscus mapping / Remapping threads after consolidation) are preserved byte-identical"
affects:
  - "M012/P04/T03 (scripts/wiki/wiki-deploy.sh — T02 specifies the wrapper contract: 4 gates, --dry-run/--help/--root/--skip-smoke flags, GATE/BUILD/DEPLOY output lines, exit codes 0/1/2); M012/P04/T04 (DEPLOY-RECORD.md — checklist step 7 names the artifact path); M012/P04/T05 (m012-p04-readme-first-deploy.sh gate will assert T02's must-haves)"
key_files:
  - "wiki/README.md"
key_decisions:
  - "AD-3 SSOT (README names file paths and commands; zero .orchestrator/ body-copy); Constitution XV (T02 touches exactly one file with two appended sections at EOF); Constitution XIV (every referenced command either exists at P03 close — config-check/link-check/smoke/remap — or ships in T03 — wiki-deploy.sh — no future-flag documentation); append-at-EOF pattern for extending multi-author operator guides (P02/P03 sections remain byte-identical; new sections go below the last existing heading)"
patterns_established:
  - "operator guide extension by EOF append preserving prior section byte-identity (diff of pre-existing lines 1-276 is empty; 144 appended lines contain only the two new section headings and their bodies); heading-as-section-boundary pattern for README (no marker comments — unlike P01/P03 mkdocs.yml edits that used '# >>> M012-P04 ... # <<<' markers, README section boundaries are '## Heading' lines, so each top-level heading owns the region between itself and the next ## heading or EOF)"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P04/tasks/T02-PLAN.md,wiki/README.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-21T03:41:42Z"
---

Appended two sections to wiki/README.md after the existing ## Remapping threads after consolidation block (which ended at line 276). Section 1 (## First-deploy checklist, 74 lines) is the strictly-ordered once-per-deployment procedure: enable Discussions feature, create Wiki Comments discussions category, export the four GISCUS_REPO/GISCUS_REPO_ID/GISCUS_CATEGORY/GISCUS_CATEGORY_ID env vars, configure Pages with gh-pages branch source, ensure gh on PATH (for future remap consolidations, not the deploy itself), run bash scripts/wiki/wiki-deploy.sh, record deploy URL + SHA into DEPLOY-RECORD.md, smoke-test the deployed URL for the four orientation sections / per-page Giscus thread / cross-section search hits / US2 comment-persistence. Section 2 (## Running the deploy wrapper, 70 lines) is the recurring-use contract for scripts/wiki/wiki-deploy.sh: Pipeline names the four gate invocations in order (wiki-giscus-config-check.sh, mkdocs build, wiki-link-check.sh --site wiki/site, wiki-giscus-smoke.sh --site wiki/site) and the final mkdocs gh-deploy --force push; Flags documents --dry-run / --help / --root <dir> / --skip-smoke; Output lines enumerates the GATE / BUILD / DEPLOY / DRY-RUN / OK / FAIL line shapes; Exit codes enumerates 0 / 1 / 2; Failure triage maps each gate FAIL to a concrete fix (re-export GISCUS_*, regenerate stubs+nav, inspect BROKEN: lines, check overrides/partials/comments.html).

All T02 must-haves PASS: wiki/README.md line count 420 (>=300); exactly one '## First-deploy checklist' heading at line 278; exactly one '## Running the deploy wrapper' heading at line 356; 9 occurrences of GISCUS_ (>=8 required — 5 in P03's Giscus mapping section + 4 in T02's checklist step 3); literals GISCUS_REPO (5), GISCUS_REPO_ID (2), GISCUS_CATEGORY (6), GISCUS_CATEGORY_ID (2), gh-pages (5), mkdocs gh-deploy (6), Discussions (5), discussions category (1), wiki-deploy.sh (2) all present; P02/P03 sections byte-identical (edit was a pure append after line 276). The m012-p04-index-ssot.sh gate still passes (37 paragraphs / 0 hits — README edits do not affect index SSOT scope).

Scope decisions: the T02-PLAN Verification section lists 'bash scripts/verify/m012-p04-readme-first-deploy.sh' as a Check, but T05-PLAN owns creation of every m012-p04-*.sh except the P04 index-ssot gate already shipped in T01. Per Constitution XV and the dispatch payload's explicit guidance that downstream task gates 'may legitimately be missing', this task surfaces the missing gate instead of pre-creating it. Verification via check-must-haves.sh confirms the T02-owned artifact assertions PASS (wiki/README.md contains 'First-deploy checklist'; key-links wiki/README.md → wiki-deploy.sh / First-deploy checklist / gh-pages all PASS); all other FAILs in that run point at T03/T04/T05 deliverables and are the expected incremental phase state.

Out of scope and deferred: T03 scripts/wiki/wiki-deploy.sh (the wrapper itself); T04 DEPLOY-RECORD.md (the recording artifact); T05 ten m012-p04-*.sh gate scripts + phase-suite orchestrator (including m012-p04-readme-first-deploy.sh which will assert exactly the must-haves this summary documents).
