---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P05"
milestone: "M005"
provides:
  - "references/provider-convention.md documenting provider shell interface"
requires:
  - "none"
affects:
  - "P05"
key_files:
  - "references/provider-convention.md"
key_decisions:
  - "AD-6"
patterns_established:
  - "provider shell convention with verdict and cost integration"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P05/tasks/T03-PLAN.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-13T01:18:02Z"
---

Created provider-convention.md reference document. Documents required arguments, env vars, output format, exit codes, verdict integration, cost reporting, content hash reporting, minimal example, and conformance checklist per AD-6.
