---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M002"
provides:
  - "scripts/knowledge/create-entry.sh (detail file creation + index update), scripts/knowledge/rebuild-index.sh (full index regeneration)"
requires:
  - "scripts/knowledge/lib/index-utils.sh (T01)"
affects:
  - "T03 (update-entry.sh), T04 (supersede/archive/promote), T05 (rebuild-index.sh integration)"
key_files:
  - "scripts/knowledge/create-entry.sh, scripts/knowledge/rebuild-index.sh"
key_decisions:
  - "Removed hash.sh dependency and content_hash field from M001 versions; create-entry.sh sources only index-utils.sh; rebuild-index.sh uses fm_field helper for frontmatter parsing; superseded entries excluded from index"
patterns_established:
  - "Detail file format: YAML frontmatter (12 fields) + markdown body with heading; fm_field() helper for frontmatter extraction; idempotent create (EXISTS message on duplicate); sorted deterministic index output"
drill_down_paths:
  - "scripts/knowledge/create-entry.sh, scripts/knowledge/rebuild-index.sh"
duration: "172"
verification_result: "pass"
completed_at: "2026-04-13T04:12:15Z"
---

Rewrote create-entry.sh and rebuild-index.sh to the new M002 spec. create-entry.sh creates individual detail files at knowledge/{category}/{id}.md with YAML frontmatter (12 metadata fields) and atomically updates KNOWLEDGE-INDEX.md via index-utils.sh. Idempotent — existing IDs return EXIT 0 with EXISTS message. rebuild-index.sh scans all non-archived detail files, skips superseded entries, and regenerates the index sorted by ID. Both scripts Bash 3.2 compatible with no hash.sh dependency.
