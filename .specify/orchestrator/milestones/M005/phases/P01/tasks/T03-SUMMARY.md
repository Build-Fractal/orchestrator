---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M005"
provides:
  - "update-entry.sh --body flag with content_hash recomputation, --recompute-hash flag"
requires:
  - "from:P01/T01 what:scripts/lib/hash.sh"
affects:
  - "P01"
key_files:
  - "scripts/knowledge/update-entry.sh"
key_decisions:
  - "AD-1"
patterns_established:
  - "body replacement with temp-file approach, hash recomputation on content change"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P01/tasks/T03-PLAN.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-12T23:59:07Z"
---

Updated update-entry.sh with --body flag for body replacement and --recompute-hash flag. When body changes, content_hash is recomputed from new content. Hash.sh sourced for compute_content_hash and compute_file_body_hash functions.
