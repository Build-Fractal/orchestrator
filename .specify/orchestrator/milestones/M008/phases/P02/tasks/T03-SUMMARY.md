---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M008"
provides:
  - "local-agent.sh — Claude Code Agent tool backend adapter (probe + coordination boundary modes per MEM018)"
requires:
  - "from:P02/T01 what:dispatch-result.md schema"
affects:
  - "P02/T05"
key_files:
  - "scripts/dispatch/adapters/backend/local-agent.sh"
key_decisions:
  - "none"
patterns_established:
  - "coordination-boundary adapter — adapter emits dispatch instructions for orchestrator agent layer because Agent tool is in-process"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P02/tasks/T03-PLAN.md"
duration: "636s"
verification_result: "pass"
completed_at: "2026-04-14T15:30:08Z"
---

Created local-agent.sh adapter. --probe mode outputs available=true|false based on SPECKIT_AGENT_TOOL env var or runtime detection. Normal mode emits dispatch-result.md formatted output with coordination-boundary semantics (per MEM018) since Agent tool is in-process and cannot be invoked from a subprocess shell script. Satisfies FR-010 local backend requirement.
