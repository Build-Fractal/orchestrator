---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M008"
provides:
  - "intensity-gate.sh — central stage-level gate with 7x3 matrix (stages × Quick/Standard/Full)"
requires:
  - "from:P01/T04 what:intensity-metadata.md schema"
affects:
  - "P03/T04,P03/T05"
key_files:
  - "scripts/engine/intensity-gate.sh"
key_decisions:
  - "centralized stage×intensity matrix in one script to avoid drift across 5 command docs"
patterns_established:
  - "central lookup table for stage-level behavior scaling — single source of truth for intensity-aware pipeline"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P03/tasks/T01-PLAN.md"
duration: "5m"
verification_result: "pass"
completed_at: "2026-04-14T15:53:44Z"
---

Created intensity-gate.sh implementing the stage-level substep gate. Reads --stage and --intensity (or --intensity-metadata file), looks up the 7×3 matrix, outputs execute_substeps= and skip_substeps= key=value pairs. Centralization avoids drift across 5 downstream command docs (T04 references this gate).
