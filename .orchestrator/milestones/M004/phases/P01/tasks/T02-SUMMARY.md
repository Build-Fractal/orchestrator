---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M004"
provides:
  - "ANTIPATTERNS.md append-only register with 3 entries (AP-001 through AP-003) referencing M001-M003 incidents"
requires:
  - "from:T01 what:Constitution v2.0.0 with principles VIII-XIII for principle references"
affects:
  - "All future phases — antipatterns serve as permanent warnings for recurring structural failures"
key_files:
  - "ANTIPATTERNS.md"
key_decisions:
  - "AD-11: Antipatterns are permanent with no staleness decay"
patterns_established:
  - "Antipattern entry format: AP-NNN with Observed In, Principle Violated, Description, Evidence, Remedy sections; Append-only register pattern"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P01/tasks/T02-PLAN.md"
duration: "73s"
verification_result: "pass"
completed_at: "2026-04-10T20:08:39Z"
---

Created ANTIPATTERNS.md at orchestrator root with 3 entries from real M001-M003 audit incidents. AP-001: Platform-specific Bash syntax (process substitution < <(...) breaking on Bash 3.2, observed in M002/M003, violates Principle IX). AP-002: Platform-divergent sed in-place editing (sed -i.bak creating junk files on macOS, observed in M001, violates Principle IX). AP-003: Missing double-sourcing guards on 7 library files (observed in M002, violates Principle VIII/NFR-203). Each entry includes milestone reference, violated principle, evidence with specific file paths, and concrete remedy. 82 lines, all 5 verification checks pass.
