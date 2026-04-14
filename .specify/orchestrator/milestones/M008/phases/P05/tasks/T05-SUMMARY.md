---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P05"
milestone: "M008"
provides:
  - "native.sh — orchestrator native task format adapter (read/write/probe/validate)"
requires:
  - "none (independent task)"
affects:
  - "P05/T06,P05/T07"
key_files:
  - "scripts/dispatch/adapters/format/native.sh"
key_decisions:
  - "identity adapter for native format enables symmetric treatment of native vs foreign formats"
patterns_established:
  - "format adapter interface — read/write/probe — with round-trip integrity guarantee"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P05/tasks/T05-PLAN.md"
duration: "~8m"
verification_result: "pass"
completed_at: "2026-04-14T17:09:43Z"
---

Created native.sh format adapter implementing read/write/probe/validate for orchestrator's native task-plan format. Read is effectively identity (validates frontmatter + required sections, emits to stdout). Write accepts input on stdin and persists to target path. Enables symmetric handling of native + foreign formats (T06 speckit.sh) through uniform format-adapter interface.
