---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M011"
provides:
  - "scripts/knowledge/ingest-spec.sh skeleton with section splitter and classification router"
requires:
  - "P01: create-entry.sh SPEC- ID support, rebuild-index.sh nested scanning, knowledge/spec/ tree"
affects:
  - "T02 classifier implementation, T03 hash/idempotency wiring"
key_files:
  - "scripts/knowledge/ingest-spec.sh"
key_decisions:
  - "H2-heading section split, dispatch_section router pattern, stub classifiers for T02"
patterns_established:
  - "Section-level markdown parsing with while-read loop, classify_* function naming"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P02/tasks/T01-PLAN.md"
duration: "0"
verification_result: "pass"
completed_at: "2026-04-16T16:51:51Z"
---

Created ingest-spec.sh with argument parsing (--spec-path, --slug, --scope-tags), H2-heading section splitter using while-read loop, dispatch_section classification router with case-based matching, and four stub classifier functions (stories, requirements, constraints, non-goals). Verified against 016-autonomous-hardening spec: correctly routes User Scenarios (4577 chars), Non-Goals (409 chars), and Constraints (351 chars) while skipping Problem Statement and Success Criteria. Passes Bash 3.2 syntax check.
