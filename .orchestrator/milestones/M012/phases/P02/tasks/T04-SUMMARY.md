---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P02"
milestone: "M012"
provides:
  - "wiki/README.md operator documentation: Link resolution policy (in-scope/out-of-scope/flag-and-enumerate), Running the link checker (--site/--root/--strict/--help flag reference + exit codes + output shape), Pre-deploy integration (P04) contract (link-checker + Giscus smoke hooks + mkdocs build --strict alignment)"
requires:
  - "from:M012/P01 what:wiki/README.md operator preamble (install/preview/regenerate/scope sections), from:M012/P02/T01 what:wiki/mkdocs.yml rewrite_relative_urls true, from:M012/P02/T02 what:wiki/docs/knowledge/**/MEM*.md stub tree shape, from:M012/P02/T03 what:scripts/diagnostics/wiki-link-check.sh with --site/--root/--strict/--help API and BROKEN/OUT-OF-SCOPE/PASS/FAIL output shape"
affects:
  - "M012/P02/T05 (policy-docs gate asserts on literal heading lines + content mentions), M012/P04 (deploy pipeline consumes the documented pre-build hook contract)"
key_files:
  - "wiki/README.md"
key_decisions:
  - "AD-1 granular-MEM cite preferred over consolidated anchor (D011 criterion a),AD-3 SSOT cite-by-path not body-copy,AD-19 no executable wiring in T04,Constitution XIV no speculative complexity,Constitution XV surgical precision single file touched"
patterns_established:
  - "documentation-only P02 to P04 handoff via prose contract (README enumerates hooks and chaining behavior; P04 owns the wrapper); flag-and-enumerate policy for out-of-scope targets (checker emits OUT-OF-SCOPE informational lines but does not fail the build); mkdocs build --strict and wiki-link-check.sh as complementary gates (source+nav vs rendered-HTML); honest future-enhancement framing (repo-root to github.com rewrite explicitly out of scope)"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P02/tasks/T04-PLAN.md,wiki/README.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-21T02:17:31Z"
---

T04 appends three sections to wiki/README.md — Link resolution (policy: in-scope .orchestrator/**.md + knowledge/**/MEM*.md + same-page anchors + KNOWLEDGE.md#mem-NNNN; out-of-scope http/https/mailto/tel/ftp + repo paths like scripts/** tests/** commands/** templates/** references/** docs/** packaging/** + repo-root files README.md CHANGELOG.md; handling: flag-and-enumerate, no build failure, not rewritten), Running the link checker (typical local workflow with mkdocs build then wiki-link-check.sh --site wiki/site, expected PASS and FAIL output shapes, exit codes 0/1/2, flags --site --root --strict --help, interpreting OUT-OF-SCOPE volume), Pre-deploy integration P04 (documents P02 to P04 handoff: link-checker + Giscus smoke as two separate pre-build hooks; explicitly states T04 documents the contract only and wires no hooks — P04 owns the pipeline; mkdocs build --strict alignment explaining how source+nav strict-build and rendered-HTML link-check complement each other). Constraints honored: markdown-only, additive to P01 preamble, exact heading strings, honest scope notes on the future GitHub-URL rewrite, no canonical content duplicated (cite by AD/D path only), surgical precision — one file touched. All seven task-level verification checks PASS (three heading counts each exactly 1; wiki-link-check.sh and mkdocs build --strict each mentioned; line count 195 ≥ 80 floor; P01 suite residual status is the known upstream nav-structure failure documented in the payload as T05-owned and not introduced by T04).
