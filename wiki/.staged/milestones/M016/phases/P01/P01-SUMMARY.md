---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M016"
milestone: "M016"
provides:
  - "write-summary.sh with optional completed_at defaulting to now, AP-004 antipattern entry, 5 verify scripts, auto.md write-summary example cleaned of command substitution, guidance note present, verify script passing, AP-004 anti-pattern catalog entry for Class A harness prompt triggers"
requires:
  - "from:P01/T01 what:write-summary.sh optional completed_at and now sentinel, from:P01/T01 what:write-summary.sh optional completed_at"
affects:
  - "P03, P03, P03"
key_files:
  - "scripts/knowledge/write-summary.sh, ANTIPATTERNS.md, scripts/verify/m016-p01-completed-at-optional.sh, scripts/verify/m016-p01-completed-at-now-sentinel.sh, scripts/verify/m016-p01-completed-at-explicit.sh, scripts/verify/m016-p01-auto-md-no-subst.sh, scripts/verify/m016-p01-antipatterns-ap004.sh, commands/auto.md, scripts/verify/m016-p01-auto-md-no-subst.sh, ANTIPATTERNS.md"
key_decisions:
  - "none"
patterns_established:
  - "completed_at optional with now sentinel pattern for eliminating command-substitution safety prompts, prose descriptions of phase-transition output fields left unchanged per constraint, anti-pattern catalog as linter source of truth"
drill_down_paths:
  - ".orchestrator/milestones/M016/phases/P01/tasks/T01-SUMMARY.md, .orchestrator/milestones/M016/phases/P01/tasks/T02-SUMMARY.md, .orchestrator/milestones/M016/phases/P01/tasks/T03-SUMMARY.md"
duration: "22m"
verification_result: "pass"
completed_at: "2026-04-16T03:14:13Z"
observability_surfaces:
  - "none"
---

Made --completed_at optional in write-summary.sh with now sentinel, eliminating the #1 source of Claude Code safety prompts during autonomous execution. Subagents no longer need $(date ...) command substitution when writing task summaries. Updated commands/auto.md examples to omit --completed_at and added guidance note. Created AP-004 antipattern catalog entry documenting three Class A harness prompt trigger classes (command substitution, brace expansion, compound bash chains) with evidence from M008/[M015](../../../../milestones/M015/index.md) and remedy table. All 5 must-have verification scripts pass. Pattern established: completed_at optional with now sentinel for eliminating command-substitution safety prompts.
