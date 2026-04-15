---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01"
milestone: "M005"
provides:
  - "rebuild-index.sh with hash-aware change detection and self-healing hash drift"
requires:
  - "from:P01/T01 what:scripts/lib/hash.sh"
affects:
  - "P01"
key_files:
  - "scripts/knowledge/rebuild-index.sh"
key_decisions:
  - "AD-1"
patterns_established:
  - "hash comparison for change detection, self-healing hash drift"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P01/tasks/T04-PLAN.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-13T00:01:54Z"
---

Updated rebuild-index.sh to compare stored content_hash against freshly computed body hash. Reports changed/unchanged/no-hash counts. Self-heals hash drift by updating stored hash when mismatch detected.
