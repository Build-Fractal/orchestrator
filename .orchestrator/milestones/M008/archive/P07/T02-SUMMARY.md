---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P07"
milestone: "M008"
provides:
  - "project-instruction.md template with custom markers + commands/init.md command doc"
requires:
  - "none (independent task)"
affects:
  - "P07/T03,P07/T04,P07/T05"
key_files:
  - "templates/project-instruction.md,commands/init.md"
key_decisions:
  - "HTML comment markers (<!-- BEGIN CUSTOM -->/<!-- END CUSTOM -->) delimit user-edited sections for reinit preservation"
patterns_established:
  - "user-edit preservation via comment-delimited blocks enables safe regeneration during reinit"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P07/tasks/T02-PLAN.md"
duration: "5m"
verification_result: "pass"
completed_at: "2026-04-14T18:14:11Z"
---

Created templates/project-instruction.md with {{placeholder}} syntax per MEM013 and HTML comment markers for user-editable sections. Created commands/init.md describing orchestrator:init command workflow (detect -> probe -> generate -> verify). Both files enable T03's init-project.sh and T04's reinit-handler.sh.
