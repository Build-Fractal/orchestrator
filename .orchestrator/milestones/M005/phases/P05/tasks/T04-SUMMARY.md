---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P05"
milestone: "M005"
provides:
  - "scripts/diagnostics/check-providers.sh validates providers against convention; run-doctor.sh wired"
requires:
  - "from:P05/T03 what:references/provider-convention.md"
affects:
  - "P05"
key_files:
  - "scripts/diagnostics/check-providers.sh, scripts/diagnostics/run-doctor.sh"
key_decisions:
  - "AD-6"
patterns_established:
  - "provider conformance checking via DOCTOR: protocol"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P05/tasks/T04-PLAN.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-13T01:21:11Z"
---

Created check-providers.sh that validates provider scripts against the documented convention. Checks required arguments, library sourcing, and output format. Emits DOCTOR:PROVIDERS structured output. Wired into run-doctor.sh diagnostic sequence.
