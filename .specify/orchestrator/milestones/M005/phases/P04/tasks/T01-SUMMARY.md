---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M005"
provides:
  - "templates/instruction-schema.md with 5 required and 2 optional section groups; scripts/diagnostics/check-instructions.sh conformance checker; 4 verification scripts"
requires:
  - "none"
affects:
  - "P04"
key_files:
  - "templates/instruction-schema.md, scripts/diagnostics/check-instructions.sh"
key_decisions:
  - "AD-4"
patterns_established:
  - "instruction schema conformance checking, DOCTOR: structured output protocol"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P04/tasks/T01-PLAN.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-13T00:42:07Z"
---

Created instruction schema template defining 5 required and 2 optional section groups with heading aliases. Created check-instructions.sh conformance checker that scans instruction files for required headings and reports DOCTOR:INSTRUCTIONS status. Created 4 phase verification scripts.
