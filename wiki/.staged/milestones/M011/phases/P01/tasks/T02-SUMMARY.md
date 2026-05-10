---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M011"
provides:
  - "rebuild-index.sh nested directory scanning for spec/* categories, SPEC- basename acceptance"
requires:
  - "T01: knowledge/spec/ directory tree, create-entry.sh SPEC- ID support"
affects:
  - "ingest-spec.sh (P02), knowledge.db graph queries"
key_files:
  - "scripts/knowledge/rebuild-index.sh, scripts/knowledge/create-entry.sh"
key_decisions:
  - "Two-pass glob approach for nested scanning; content_hash field added to create-entry.sh heredoc for fm_field compatibility"
patterns_established:
  - "MEM*|SPEC-* basename filter pattern; two-depth glob scan for knowledge/*/*.md and knowledge/*/*/*.md"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P01/tasks/T02-PLAN.md"
duration: "0"
verification_result: "pass"
completed_at: "2026-04-16T15:27:36Z"
---

Extended rebuild-index.sh to discover entries in nested knowledge/spec/*/ directories. Added a second glob pattern (knowledge/*/*/*.md) to the scan loop, extended the basename filter to accept SPEC-* alongside MEM*, and updated the header comment. Also added missing content_hash field to create-entry.sh heredoc so fm_field extraction does not fail under set -euo pipefail when the field is absent.
