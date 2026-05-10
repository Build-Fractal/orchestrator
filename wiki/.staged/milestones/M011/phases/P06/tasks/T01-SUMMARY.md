---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P06"
milestone: "M011"
provides:
  - "commands/ingest.md new user-facing command wrapping ingest-spec.sh, commands/evaluate.md cross-link to orchestrator:ingest (already present; no edit needed), four m011-p06-*.sh doc-shape verify scripts (structure, conventions, reingest-contract, evaluate-mentions-ingest)"
requires:
  - "P03 ingest-spec.sh, P05 commands/evaluate.md chunks-first branch, MEM012 command-file conventions"
affects:
  - "T02 e2e pipeline invokes ingest-spec.sh which is the subject of ingest.md, T03 preserved-references regression guards evaluate.md, end users discover ingest before running evaluate"
key_files:
  - "commands/ingest.md, commands/evaluate.md, scripts/verify/m011-p06-ingest-doc-structure.sh, scripts/verify/m011-p06-ingest-doc-conventions.sh, scripts/verify/m011-p06-ingest-doc-reingest-contract.sh, scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh"
key_decisions:
  - "evaluate.md already referenced orchestrator:ingest from P05 T01 work (line 42 Chunks-first path; line 196 Reference Files) so no edit to evaluate.md was required; verify scripts use grep -Fq -- to safely handle --flag-style tokens that BSD grep otherwise treats as grep options"
patterns_established:
  - "grep -Fq -- <tok> idiom for matching --flag tokens in doc-shape verify scripts; doc-shape verify scripts as a single-script Check: line per Must-Have (AD-19 / AP-004)"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P06/tasks/T01-PLAN.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-17T04:26:26Z"
---

T01 delivers the user-facing orchestrator:ingest command document and four doc-shape verify scripts codifying structure, MEM012 conventions, re-ingest semantics, and evaluate.md cross-linkage. commands/evaluate.md already contained the orchestrator:ingest reference from P05 T01 (Chunks-first path parenthetical and Reference Files bullet) so no edit to evaluate.md was required — the mention-check verify passes against the existing content. No production code changes. All four m011-p06-*.sh verify scripts PASS.
