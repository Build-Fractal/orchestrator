---
schema_version: "1.0"
type: phase-summary
id: "P04"
parent: "M005"
milestone: "M005"
provides:
  - "templates/instruction-schema.md with 5 required and 2 optional section groups; scripts/diagnostics/check-instructions.sh conformance checker; 4 verification scripts, run-doctor.sh wired to run check-instructions.sh conformance check, dispatch-prompt.md and task-plan.md updated with conforming section headings"
requires:
  - "from:P04/T01 what:scripts/diagnostics/check-instructions.sh, from:P04/T01 what:templates/instruction-schema.md"
affects:
  - "P04, P04, P04"
key_files:
  - "templates/instruction-schema.md, scripts/diagnostics/check-instructions.sh, scripts/diagnostics/run-doctor.sh, templates/dispatch-prompt.md, templates/task-plan.md, scripts/verify/p04-template-migration.sh"
key_decisions:
  - "AD-4, AD-4, AD-4"
patterns_established:
  - "instruction schema conformance checking, DOCTOR: structured output protocol, progressive migration of instruction files to schema"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P04/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P04/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P04/tasks/T03-SUMMARY.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-13T00:50:50Z"
observability_surfaces:
  - "none"
---

Phase P04 establishes the agent instruction schema. templates/instruction-schema.md declares 5 required section groups (Context, Task, Constraints, Verification, Output Format) and 2 optional groups (Prior Art, Related Knowledge) with heading aliases for flexible conformance. scripts/diagnostics/check-instructions.sh performs static conformance checking against required headings. run-doctor.sh wired to include instruction conformance in the diagnostic sequence. Both dispatch-prompt.md and task-plan.md already conform to the schema. All 4 phase truths verified passing.
