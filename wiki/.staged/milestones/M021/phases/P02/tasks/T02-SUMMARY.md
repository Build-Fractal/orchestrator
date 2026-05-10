---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M021"
provides:
  - "ANTIPATTERNS.md AP-005..AP-009 entries with M011/P05-P07 evidence and P01-wrapper remedies"
requires:
  - "from:P01 what:scripts/util/with-env.sh; from:P01 what:scripts/util/read-range.sh; from:P01 what:scripts/util/run-probe.sh"
affects:
  - "P02,P03,P04"
key_files:
  - "ANTIPATTERNS.md"
key_decisions:
  - "AD-11,AD-19"
patterns_established:
  - "Append-only antipattern register grows to 9 entries; each Class B entry names exactly one P01 wrapper in Remedy; M011/P05-P07 screenshot citations grounded in AD-2/AD-9"
drill_down_paths:
  - "ANTIPATTERNS.md,.orchestrator/milestones/M021/phases/P02/tasks/T02-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-17T18:42:59Z"
---

Appended five new entries (AP-005 through AP-009) to ANTIPATTERNS.md, following the byte-for-byte structural convention of AP-001..AP-004 (heading, Observed In, Principle Violated, Related Constitution Constraint, Description, Evidence, Remedy). AP-005 (simple-expansion) remedies via scripts/util/with-env.sh. AP-006 (cmd-sub in redirect target) remedies via scripts/util/read-range.sh. AP-007 (quoted-brace) remedies via scripts/util/read-range.sh. AP-008 (heredoc-expansion) remedies via scripts/util/run-probe.sh. AP-009 (task-PAYLOAD compound chains) remedies via scripts/util/run-probe.sh + scripts/verify/run-suite.sh. Each entry cites M011/P05-P07 screenshots (2026-04-16/2026-04-17) and includes at least one concrete trigger-text evidence bullet. Structural must-haves verified: grep -c for AP headings returns 9, each new entry contains [M011](../../../../../milestones/M011/index.md), each names at least one scripts/util path, all six bold-field labels present in every new entry (54 matches across 9 entries). AP-001..AP-004 untouched. T03 linter gate (scripts/verify/m021-p02-linter-v2.sh) is authored by a later task in this phase; it will exercise the anchors mechanically at phase-verify time.
