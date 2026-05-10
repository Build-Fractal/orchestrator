---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M002"
provides:
  - "scripts/knowledge/update-entry.sh (field modification + index sync), scripts/knowledge/supersede-entry.sh (supersession + index removal), scripts/knowledge/lib/detail-utils.sh (shared find/sed/fm helpers)"
requires:
  - "scripts/knowledge/lib/index-utils.sh (T01), scripts/knowledge/create-entry.sh (T02 — used in tests)"
affects:
  - "T04 (archive-entry.sh, promote-entry.sh — will source detail-utils.sh)"
key_files:
  - "scripts/knowledge/update-entry.sh, scripts/knowledge/supersede-entry.sh, scripts/knowledge/lib/detail-utils.sh"
key_decisions:
  - "Created shared detail-utils.sh library with find_detail_file, sed_i, fm_field helpers rather than inlining in each script; superseded entries stay on disk (not archived) for audit trail; old hash.sh dependency removed from both scripts"
patterns_established:
  - "detail-utils.sh as shared helper library for all CRUD scripts; portable sed_i for BSD/GNU compatibility; category-agnostic find_detail_file scanning knowledge/*/"
drill_down_paths:
  - "scripts/knowledge/update-entry.sh, scripts/knowledge/supersede-entry.sh, scripts/knowledge/lib/detail-utils.sh"
duration: "430"
verification_result: "pass"
completed_at: "2026-04-13T04:20:58Z"
---

Rewrote update-entry.sh and created supersede-entry.sh. update-entry.sh supports --confidence, --last-verified (with 'now'), --hit-count, and --increment-hits with atomic index sync after each change. supersede-entry.sh sets superseded_by on old entry, supersedes on new entry, removes old from index, and is idempotent. Extracted shared helpers (find_detail_file, sed_i, fm_field) into new detail-utils.sh library with double-sourcing guard. All Bash 3.2 compatible, no hash.sh dependency.
