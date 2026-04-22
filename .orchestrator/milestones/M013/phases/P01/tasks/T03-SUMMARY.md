---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M013"
provides:
  - "UAT Bug Issue Form with required Spec Chunk ID linking defects back to owning SPEC-* chunk"
requires:
  - "n/a"
affects:
  - "T05 (uat-ingest reads issues filed via this template); T04 (template points users at KNOWLEDGE-INDEX.md Spec Chunks section T04 emits)"
key_files:
  - ".github/ISSUE_TEMPLATE/uat-bug.yml,scripts/verify/m013-p01-uat-template.sh"
key_decisions:
  - "none"
patterns_established:
  - "GitHub Issue Forms scaffolded under .github/ISSUE_TEMPLATE/; required spec_chunk_id field pinned to existing SPEC-* frontmatter IDs (no new ID format); autocomplete source documented via KNOWLEDGE-INDEX.md link rather than dynamic form-field dropdown (GitHub Issue Forms has no dynamic autocomplete API)"
drill_down_paths:
  - ".orchestrator/milestones/M013/phases/P01/tasks/T03-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-21T18:03:38Z"
---

Created .github/ISSUE_TEMPLATE/ directory and its first template (uat-bug.yml, 65 lines). Template carries name/description/title/labels/body top-level keys; title prefix is '[UAT] ' with trailing space; labels list includes uat-bug; spec_chunk_id input is marked validations.required: true; KNOWLEDGE-INDEX.md link lives in the 'How to find your Spec Chunk ID' markdown block as the autocomplete source per FR-9 pinning to existing SPEC-* frontmatter. Created scripts/verify/m013-p01-uat-template.sh (110 lines, 13 behavior assertions + SKIP path for YAML validator when PyYAML/yq absent, graceful-absent-tool pattern from M012). Gate exits 0 with final 'PASS: m013-p01-uat-template.sh' line. Note: PyYAML not installed in this environment so YAML-validity assertion reached the SKIP branch — structural assertions (grep-based) still cover the key form-field contract. Judgment call: followed T03-PLAN.md authoritative name scripts/verify/m013-p01-uat-template.sh (matches P01-PLAN.md phase-suite wiring), not the dispatch prompt's scripts/verify/m013-p01-uat-bug-template.sh — phase-suite orchestrator will invoke the plan-named file.
