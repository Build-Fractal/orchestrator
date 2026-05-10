---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M016"
provides:
  - "AP-004 anti-pattern catalog entry for Class A harness prompt triggers"
requires:
  - "from:P01/T01 what:write-summary.sh optional completed_at"
affects:
  - "P03"
key_files:
  - "ANTIPATTERNS.md"
key_decisions:
  - "none"
patterns_established:
  - "anti-pattern catalog as linter source of truth"
drill_down_paths:
  - ".orchestrator/milestones/M016/phases/P01/tasks/T03-PLAN.md"
duration: "2"
verification_result: "pass"
completed_at: "2026-04-16T03:13:02Z"
---

Verified AP-004 entry in ANTIPATTERNS.md. Entry documents three Class A Claude Code safety-prompt trigger classes (command substitution, brace expansion, compound bash chains) with real evidence from [M008](../../../../../milestones/M008/index.md) and [M015](../../../../../milestones/M015/index.md) autonomous runs. All five required sections present: Observed In, Principle Violated, Description, Evidence, Remedy. Verify script scripts/verify/m016-p01-antipatterns-ap004.sh passes with exit 0.
