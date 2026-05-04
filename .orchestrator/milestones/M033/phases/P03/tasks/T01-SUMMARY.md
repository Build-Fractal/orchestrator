---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "M033/P03"
milestone: "M033"
provides:
  - "scripts/verify/constitution-shape-lint.sh (FR-5 4-assertion lint),scripts/verify/standalone-gate.sh (FR-6 / Principle XVI dispatcher with constitution v1 subcommand and fenced SSOT surface block),templates/constitution-starters/web-saas.md+cli-tool.md+library.md (FR-4 v1 closed stack list),references/constitution-starter-format.md (US-2 AS-4 starter-format reference),4 T01 verifiers under tools/verify/m033-p03-*"
requires:
  - "P01 closed (start.sh present),P02 closed (jsonl-event-emitter.sh + start-state-markers.sh + grilling-shell.sh + dual-write-runtime-md.sh present)"
affects:
  - "T02,T03,T04,T05"
key_files:
  - "scripts/verify/constitution-shape-lint.sh,scripts/verify/standalone-gate.sh,templates/constitution-starters/web-saas.md,templates/constitution-starters/cli-tool.md,templates/constitution-starters/library.md,references/constitution-starter-format.md,tools/verify/m033-p03-constitution-shape-lint-shape.sh,tools/verify/m033-p03-standalone-gate-sh-shape.sh,tools/verify/m033-p03-constitution-starter-templates-shape.sh,tools/verify/m033-p03-constitution-starter-format-ref-shape.sh"
key_decisions:
  - "standalone-gate-elides-its-own-trigger-substring-in-format-reference-prose-to-prevent-self-trip;SKIP-tolerance-for-co-authored-but-not-yet-landed-surfaces-mirrors-M033-P01-skip-gate-pattern;subcommand-dispatched-gate-(constitution-v1)-keeps-future-extension-contract-stable;closed-v1-stack-list-with-#Q-2-demand-driven-expansion-criterion"
patterns_established:
  - "fenced-SSOT-block-for-closed-surface-file-set-with-awk-block-extraction;positive-and-negative-mktemp-d-functional-smoke-tests-for-shape-lint-shape-verifiers;self-reference-elision-pattern-for-docs-that-document-content-detection-gates"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P03/tasks/T01-standalone-gate-and-starters-PLAN.md"
duration: "45"
verification_result: "pass"
completed_at: "2026-05-04T11:43:28Z"
---

T01 lands the four verifier-and-template surfaces P03 needs to gate constitution authoring before T02 ships the consumer. The FR-5 lint asserts the structural invariants (## Constitution Check header, >=6 Roman-numeral Principle sub-headers, non-empty bodies, zero `{{` placeholder leaks); the FR-6 standalone gate is Principle XVI's first content-authoring compliance test, scanning the M033-shipped constitution-authoring surface (closed in a fenced SSOT block) for any case-insensitive trigger substring. Three FR-4 stack starters (web-saas, cli-tool, library) ship with frontmatter (schema_version 1.0 + type constitution-starter + matching stack), 6 baseline principles mirroring the orchestrator's canonical baseline, 2 stack-specific principles, and the closed placeholder vocabulary (project_type, primary_constraint, target_user). The format reference documents the contract, the closed v1 stack list, and the #Q-2 demand-driven expansion criterion. One mid-task adjustment: the format reference originally documented the gate by quoting the literal trigger substring, which then tripped the gate against itself; the docs prose was edited to elide the literal substring while preserving the explanation. All four T01 verifiers exit 0 (12+17+33+10 = 72 PASS / 0 FAIL); the standalone gate against the partial M033 working tree returns pass=5 skip=2 fail=0 (the two not-yet-landed T02 surfaces skipped pending T02).
