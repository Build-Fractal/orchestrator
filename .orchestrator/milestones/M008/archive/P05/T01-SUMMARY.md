---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P05"
milestone: "M008"
provides:
  - "detect-runtime.sh — runtime auto-detection via env vars + filesystem signals"
requires:
  - "none (independent task)"
affects:
  - "P05/T02,P05/T03,P05/T04,P05/T07"
key_files:
  - "scripts/dispatch/detect-runtime.sh"
key_decisions:
  - "unknown fallback instead of error — detection never fails per FR-026 spirit"
patterns_established:
  - "signal-priority runtime detection — env vars dominate over filesystem; confidence reported alongside runtime"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P05/tasks/T01-PLAN.md"
duration: "~8min"
verification_result: "pass"
completed_at: "2026-04-14T16:55:43Z"
---

Created detect-runtime.sh probing CLAUDECODE/CURSOR_*/CODEX_* env vars and .claude/.cursor/.codex filesystem markers. Emits runtime + confidence key=value. Defaults to unknown (never errors) per graceful-detection principle.
