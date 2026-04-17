---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M011"
provides:
  - "Content hash population in spec chunks, first-ingest idempotency, rebuild-index validation"
requires:
  - "T02: full classifier implementations in ingest-spec.sh"
affects:
  - "P03 re-ingest change detection (compares content hashes), P04 dispatch payload integrity"
key_files:
  - "scripts/knowledge/ingest-spec.sh"
key_decisions:
  - "AD-4: SHA-256 content hash via hash.sh, sed_i patching after create, normalize_for_hash strips whitespace"
patterns_established:
  - "Post-creation hash patching pattern, SKIPPED output for idempotent re-runs"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P02/tasks/T03-PLAN.md"
duration: "0"
verification_result: "pass"
completed_at: "2026-04-16T19:56:34Z"
---

Wired content hash computation into the ingest-spec.sh chunk creation flow. After create-entry.sh creates a new detail file, the content_hash field is patched in place via sed_i with the SHA-256 hash of the normalized chunk body. Added normalize_for_hash helper that strips trailing whitespace per line and leading/trailing blank lines for stable hashing across re-ingests. Resolved INGEST_PROJECT_ROOT once at script top via get_project_root(). Verified first-ingest idempotency: second run on unchanged spec produces only SKIPPED lines, no new CREATED lines. Created three verification scripts covering content hash format, idempotency, and rebuild-index integration. All 11 P02 verification scripts pass.
