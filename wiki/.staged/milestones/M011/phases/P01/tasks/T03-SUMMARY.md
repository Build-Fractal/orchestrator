---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M011"
provides:
  - "next_entry_id() robustness against SPEC- prefixed files in nested directories"
requires:
  - "none"
affects:
  - "create-entry.sh auto-ID generation when spec chunks coexist with MEM entries"
key_files:
  - "scripts/knowledge/lib/index-utils.sh"
key_decisions:
  - "MEM*.md glob inherently excludes SPEC- files, nested glob added for robustness"
patterns_established:
  - "Comment-documented SPEC- exclusion rationale in next_entry_id()"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P01/tasks/T03-PLAN.md"
duration: "0"
verification_result: "pass"
completed_at: "2026-04-16T15:29:57Z"
---

Extended next_entry_id() detail file scan glob to include nested directories (knowledge/*/*/MEM*.md) for robustness when spec chunks coexist with MEM entries. Added clarifying comments documenting that MEM*.md glob inherently excludes SPEC- prefixed files and the index scan regex only matches MEM-prefixed lines. Also fixed PROJECT_ROOT_REAL reference in verification script. Verification passes.
