---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M012"
provides:
  - "wiki/docs/index.md finalized home page (65 lines, 4 required section headings — What this site is / How to navigate / Where to comment / Audience scope — + Deploy & preview pointer, 5 stub-route links: constitution.md, decisions.md, knowledge/index.md, milestone-summary.md, milestones/index.md); scripts/verify/m012-p04-index-ssot.sh (79-line SSOT guard that forbids any >=40-char paragraph on the home page from appearing verbatim in canonical .orchestrator/**.md artifacts — excludes T*-PLAN.md and T*-PAYLOAD.md which quote the home page as the task spec itself)"
requires:
  - "from:M012/P01/T04 what:wiki/mkdocs.yml nav wiring that routes constitution.md / decisions.md / knowledge/index.md / milestone-summary.md / milestones/index.md to their stubs so the relative links on index.md resolve at build time; from:M012/P01/T01 what:wiki/docs/index.md P01 placeholder scaffold (19 lines, 'placeholder' literal in body) that T01 overwrites; from:M012/P02 what:include-markdown rewrite_relative_urls:true so the relative link targets resolve to rendered routes; from:M012/P03 what:wiki/overrides/partials/comments.html so the home page collects a Giscus thread like every other rendered page"
affects:
  - "M012/P04/T02 (README first-deploy checklist will reference index.md), M012/P04/T05 (m012-p04-index-finalized.sh gate will assert on this file's 4 headings + 5 stub-route links + 40-120 line range + no-placeholder; m012-p04-phase-suite.sh orchestrates the SSOT gate shipped here)"
key_files:
  - "wiki/docs/index.md,scripts/verify/m012-p04-index-ssot.sh"
key_decisions:
  - "AD-3 SSOT (home page is a thin orientation layer — every substantive link routes to a canonical stub; zero body-copy from .orchestrator/),Constitution VI (home page is not a documentation dump — 65 lines orientation prose not artifact body),Constitution XIV (no 'coming soon' sections — shipped only M012 functionality),Constitution XV (T01 touches exactly one wiki file plus the one verify script it explicitly owns per the plan's 'ship this SSOT guard' step),task-plan-exclusion pattern for SSOT scan (T*-PLAN.md and T*-PAYLOAD.md are specifications that quote the expected output verbatim — excluding them from the scan is necessary to avoid self-referential false positives)"
patterns_established:
  - "SSOT guard with exclusion list for spec-quote files (grep -rF --include='*.md' --exclude='T*-PLAN.md' --exclude='T*-PAYLOAD.md' against .orchestrator/ — covers the case where a task plan legitimately quotes the expected artifact content as the task specification); candidate extraction via grep -v '^#' | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*<!--' | awk 'length >= 40' (strips headings, blanks, HTML comments before matching so only substantive prose is scanned)"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P04/tasks/T01-PLAN.md,wiki/docs/index.md,scripts/verify/m012-p04-index-ssot.sh"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-21T03:34:25Z"
---

Replaced P01's 19-line placeholder home page with the finalized 65-line orientation content exactly as specified in T01-PLAN.md — four required section headings (## What this site is / ## How to navigate / ## Where to comment / ## Audience scope) plus the Deploy & preview pointer to wiki/README.md, five stub-route links by filename (constitution.md, decisions.md, knowledge/index.md, milestone-summary.md, milestones/index.md), and zero absolute URLs under giscus.app or github.com (deploy-time details stay out of static content). The literal word 'placeholder' is absent. Line count is 65 (within the 40-120 must-have band).

Also shipped scripts/verify/m012-p04-index-ssot.sh — the home-page SSOT guard. It extracts candidate paragraph lines from wiki/docs/index.md (>=40 chars, non-heading, non-blank, non-HTML-comment), then recursively greps .orchestrator/ for verbatim matches with grep -rF. Crucially it excludes T*-PLAN.md and T*-PAYLOAD.md from the scan — those files legitimately quote the expected home-page prose as the task specification (the T01 plan literally contains the full expected content as a code block), and scanning them would produce guaranteed false positives on every candidate paragraph. The gate currently passes with 37 paragraphs scanned and zero body-copy hits against canonical .orchestrator/ artifacts (constitution, decisions, knowledge MEMs, milestone summaries, milestone/phase plans).

Verification status: m012-p04-index-ssot.sh PASS (37 paragraphs, 0 hits); check-must-haves.sh against the phase directory correctly FAILs on T02-T05 deliverables (README extension, wiki-deploy.sh, DEPLOY-RECORD.md, 10 other verify scripts) — those are downstream tasks and will pass as each task lands, this is the expected incremental phase state. T01-specific must-haves from T01-PLAN.md all PASS: file exists / 40-120 lines / contains the 3 required heading strings / contains the 4 required link targets / no 'placeholder' literal / zero paragraph duplicates in canonical .orchestrator artifacts. The m012-p04-index-finalized.sh gate referenced in T01-PLAN.md's Verification section is T05's deliverable per T05-PLAN.md Step 1 — T01-PLAN.md Step 3 explicitly forbids creating other files in this task, so manual verification against its future assertions confirmed: 4 headings present, 4 link tokens present (constitution, decisions, knowledge, milestones), 65-line count in [40,120], no 'placeholder'.

Out of scope and deferred: T02 wiki/README.md first-deploy checklist extension; T03 scripts/wiki/wiki-deploy.sh chained deploy wrapper; T04 DEPLOY-RECORD.md; T05 the remaining ten m012-p04-*.sh gates + phase-suite orchestrator.
