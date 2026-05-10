---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M007"
provides:
  - "Updated rebuild-index.sh that populates knowledge.db alongside flat index; relates_to/supersedes edge parsing; scope_tag normalization"
requires:
  - "from:P01/T01 what:graph-db.sh library (get_db_path, db_init, db_insert_entry, db_insert_edge, db_insert_scope_tag)"
affects:
  - "P01/T03"
key_files:
  - "scripts/knowledge/rebuild-index.sh"
key_decisions:
  - "Insert all entries (including superseded) into SQLite before flat-index skip for provenance chain completeness"
patterns_established:
  - "All entries (including superseded) go into SQLite for provenance; flat index still skips superseded; relates_to parsed as directed edges"
drill_down_paths:
  - ".specify/orchestrator/milestones/M007/phases/P01/tasks/T02-PLAN.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-14T05:03:00Z"
---

Updated rebuild-index.sh to populate SQLite knowledge.db alongside the existing flat KNOWLEDGE-INDEX.md rebuild. All entries including superseded ones go into the DB for provenance chain queries. Edges parsed from relates_to arrays and supersedes fields. Scope tags normalized into separate table. Atomic rebuild via temp-file-then-mv pattern. All three verification scripts pass.
