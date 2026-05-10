---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P05"
milestone: "M005"
provides:
  - "hooks.sh parses VERDICT lines from hook stdout and maps to block/warn/continue"
requires:
  - "from:P05/T01 what:scripts/lib/verdicts.sh"
affects:
  - "P05"
key_files:
  - "scripts/lib/hooks.sh"
key_decisions:
  - "AD-3"
patterns_established:
  - "verdict parsing in hook execution, severity-based multi-verdict resolution"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P05/tasks/T02-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-13T01:14:42Z"
---

Updated hooks.sh to capture hook stdout and parse VERDICT lines. Multiple verdicts resolve to most severe. BLOCK maps to failure, WARN logs and continues, PASS/NEEDS_REVIEW succeed with metadata. Backward compatible when no VERDICT line present.
