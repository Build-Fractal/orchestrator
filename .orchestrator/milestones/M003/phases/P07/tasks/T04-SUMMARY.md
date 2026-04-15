---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P07"
milestone: "M003"
provides:
  - "commands/migrate.md documents AD-13/AD-14/AD-15 with script cross-references"
requires:
  - "from:M003/P07/T01 what:resolver-wiring; from:M003/P07/T03 what:rebuild-index-wiring"
affects:
  - "M003/P07/T05"
key_files:
  - "commands/migrate.md"
key_decisions:
  - "AD-13,AD-14,AD-15"
patterns_established:
  - "progressive-disclosure ADR sections in command docs (short body + link to M###-CONTEXT.md)"
drill_down_paths:
  - ".specify/orchestrator/milestones/M003/phases/P07/tasks/T04-PAYLOAD.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-15T02:40:18Z"
---

Added three progressive-disclosure sections to commands/migrate.md (State Root Resolution / AD-13, Knowledge Graph Participation / AD-14, Command Naming / AD-15) plus a Referenced Scripts section listing migrate.sh, resolve-root.sh, rebuild-index.sh, and detect-overlap.sh. Each section is <=15 lines and points readers at .specify/orchestrator/milestones/M003/M003-CONTEXT.md for full rationale. File grew from 43 to ~95 lines (+52 lines, within +30..+50 budget plus the new Referenced Scripts header). Inline grep verification: AD-13 x3, AD-14 x4, AD-15 x2; OK_RESOLVE/OK_OVERLAP/OK_REBUILD all printed. Phase verify script scripts/verify/m003-p07-migrate-md-documents-ads.sh does not yet exist (T05 deliverable).
