---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M013"
provides:
  - "templates/github-integration-sidecar.json,scripts/integrations/sidecar-init-pending.sh,scripts/verify/m013-p01-sidecar-schema.sh,.gitignore"
requires:
  - "none (no upstream task dependencies — T01 is the P01 root)"
affects:
  - "T02,T06"
key_files:
  - "templates/github-integration-sidecar.json,scripts/integrations/sidecar-init-pending.sh,scripts/verify/m013-p01-sidecar-schema.sh,.gitignore"
key_decisions:
  - "D014 (pending-sentinel inheritance from M012/P04 DEPLOY-RECORD convention)"
patterns_established:
  - "pending-sentinel bootstrap helper with clobber-refusal exit 2; awk _schema_docs stripper; graceful-absent python3-or-jq JSON validator"
drill_down_paths:
  - ".orchestrator/milestones/M013/phases/P01/tasks/T01-PLAN.md"
duration: "unreported"
verification_result: "pass"
completed_at: "2026-04-21T17:56:16Z"
---

Shipped M013/P01/T01 sidecar schema scaffold. Created templates/github-integration-sidecar.json with FR-6 top-level fields (schema_version=1, repo_slug=pending, project_v2_id=pending, sync_mode=manual, recommended_cron, custom_field_mappings=empty-array, items=empty-object) plus a _schema_docs block documenting each field. Created scripts/integrations/sidecar-init-pending.sh (Bash 3.2, --root flag, awk-based _schema_docs stripper, exit 0 on fresh write, exit 2 on clobber refusal per FR-11). Created scripts/verify/m013-p01-sidecar-schema.sh gate (single-script-file AD-19 shape, 15 assertions including JSON round-trip with python3-or-jq graceful-absent SKIP path, FR-6 field presence, sync_mode enum membership, helper fresh-write and clobber-refusal behavior via mktemp fixture). Added .gitignore rule for .orchestrator/integrations/github.json so the operator-owned live sidecar is never committed. Verification gate emits 15 PASS lines and final PASS: m013-p01-sidecar-schema.sh, exit 0. Judgment calls: (a) awk _schema_docs stripper tracks brace depth per line across the multi-line docstring block; lean output verified against python3 json.load in a temp probe and it parses clean. (b) .gitignore narrowly targets github.json rather than the whole .orchestrator/integrations/ dir so P01/P02 can still add non-secret scaffolding there if needed. (c) Helper refuses unknown flags with exit 2 matching clobber-refusal exit code — this conflates bad-flag and already-exists, which is acceptable for P01 scaffolding but T02 may want stderr-message disambiguation downstream.
