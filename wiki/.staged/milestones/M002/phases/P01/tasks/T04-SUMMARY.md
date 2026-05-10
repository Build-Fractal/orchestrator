---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01"
milestone: "M002"
provides:
  - "scripts/knowledge/archive-entry.sh (warm→cold storage), scripts/knowledge/promote-entry.sh (cold→warm with confidence reset)"
requires:
  - "scripts/knowledge/lib/index-utils.sh (T01), scripts/knowledge/lib/detail-utils.sh (T03), scripts/knowledge/create-entry.sh (T02 — tests)"
affects:
  - "T05 (integration test will exercise full CRUD lifecycle)"
key_files:
  - "scripts/knowledge/archive-entry.sh, scripts/knowledge/promote-entry.sh"
key_decisions:
  - "Both scripts now source detail-utils.sh instead of inlining helpers; promote resets confidence to 0.80 by default and clears superseded_by; archive cleans up empty category directories"
patterns_established:
  - "Idempotent lifecycle operations: ALREADY_ARCHIVED/NOT_ARCHIVED messages with exit 0; warm/cold storage distinction via find_warm_file vs is_archived"
drill_down_paths:
  - "scripts/knowledge/archive-entry.sh, scripts/knowledge/promote-entry.sh"
duration: "172"
verification_result: "pass"
completed_at: "2026-04-13T04:25:02Z"
---

Updated archive-entry.sh and promote-entry.sh to source shared detail-utils.sh library instead of inlining helpers. archive-entry.sh moves entries from knowledge/{category}/ to knowledge/archive/ and removes from index; cleans up empty category dirs. promote-entry.sh moves from archive back to warm storage, resets confidence (default 0.80), sets last_verified to today, clears superseded_by, and re-adds to index. Both idempotent with descriptive messages. All 16 verification checks passed.
