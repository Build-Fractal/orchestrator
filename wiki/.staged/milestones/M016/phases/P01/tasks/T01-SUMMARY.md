---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M016"
provides:
  - "write-summary.sh with optional completed_at defaulting to now, AP-004 antipattern entry, 5 verify scripts"
requires:
  - "none"
affects:
  - "P03"
key_files:
  - "scripts/knowledge/write-summary.sh, ANTIPATTERNS.md, scripts/verify/m016-p01-completed-at-optional.sh, scripts/verify/m016-p01-completed-at-now-sentinel.sh, scripts/verify/m016-p01-completed-at-explicit.sh, scripts/verify/m016-p01-auto-md-no-subst.sh, scripts/verify/m016-p01-antipatterns-ap004.sh"
key_decisions:
  - "none"
patterns_established:
  - "completed_at optional with now sentinel pattern for eliminating command-substitution safety prompts"
drill_down_paths:
  - ".orchestrator/milestones/M016/phases/P01/tasks/T01-PLAN.md"
duration: "15"
verification_result: "pass"
completed_at: "2026-04-16T03:08:51Z"
---

Made --completed_at optional in write-summary.sh. When omitted, defaults to current UTC timestamp via date -u. When passed as --completed_at=now, resolves to current UTC. Explicit ISO-8601 values pass through unchanged (backwards compatible). Removed completed_at from TASK_FIELDS, PHASE_FIELDS, and MILESTONE_FIELDS required lists. Added defaulting logic block after field validation. Updated usage header and example. Added AP-004 to ANTIPATTERNS.md documenting all three Class A harness safety-prompt trigger classes (command substitution, brace expansion, compound bash chains) with evidence from M008/[M015](../../../../../milestones/M015/index.md) and a remedy table. Created 5 verify scripts covering: omitted completed_at, now sentinel, explicit ISO, auto.md no-substitution, and AP-004 presence. All 5 pass.
