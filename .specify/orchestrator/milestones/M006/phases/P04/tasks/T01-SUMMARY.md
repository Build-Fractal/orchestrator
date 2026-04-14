---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M006"
provides:
  - "docs/getting-started.md — user installation and first-project guide"
requires:
  - "P01-P03 reference docs"
affects:
  - "T02-T05 (docs directory created)"
key_files:
  - "docs/getting-started.md"
key_decisions:
  - "9 commands documented, 5-step workflow"
patterns_established:
  - "user audience label, relative cross-links to ../references/"
drill_down_paths:
  - "docs/getting-started.md"
duration: "216"
verification_result: "pass"
completed_at: "2026-04-13T05:00:00Z"
---

Created docs/getting-started.md (386 lines). Covers installation, first orchestrated project (5-step workflow), engine output interpretation, file structure, crash recovery, and diagnostics. All command names verified against extension.yml.
