---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P02"
milestone: "M013"
provides:
  - "sub_issue_mode field extension to templates/github-integration-sidecar.json schema; github-status.sh required-fields + pending-sentinel list updates + SUB_ISSUE_MODE configured-output line (Edit C)"
requires:
  - "from:M013/P01/T01 what:templates/github-integration-sidecar.json baseline schema; from:M013/P01/T02 what:scripts/integrations/github-status.sh + commands/github-status.md baseline; from:M013/P01/T01 what:scripts/integrations/sidecar-init-pending.sh _schema_docs AWK stripper"
affects:
  - "M013/P02/T02 consumes sub_issue_mode writer via github-init.sh; M013/P02/T03 preflight emits SUBISSUE_MODE matching the sidecar field; M013/P02/T05 references/github-integration.md documents the field"
key_files:
  - "templates/github-integration-sidecar.json,scripts/integrations/github-status.sh,commands/github-status.md,scripts/verify/m013-p01-github-status.sh"
key_decisions:
  - "Edit C taken — SUB_ISSUE_MODE configured-output line added (consistent with P01 one-field-one-line contract); P01 gate m013-p01-github-status.sh updated additively (sed-replace for sub_issue_mode during configured-branch setup) per plan Step 6 arbitration path (a)"
patterns_established:
  - "schema-extension additive-only — new top-level field added between sync_mode and recommended_cron with matching _schema_docs entry; pending-sentinel field convention extends cleanly (new field defaults to 'pending' value, auto-included in PENDING_FIELDS csv until operator completes init via github-init.sh live run)"
drill_down_paths:
  - ".orchestrator/milestones/M013/phases/P02/tasks/T06-PLAN.md"
duration: "20"
verification_result: "pass"
completed_at: "2026-04-21T23:41:23Z"
---

T06 extended the sidecar schema additively with the sub_issue_mode field (enum: native|labeled-fallback|pending) to record GitHub sub-issue REST availability as determined by P02 init preflight. Three files modified:

1. templates/github-integration-sidecar.json — added _schema_docs entry for sub_issue_mode (alphabetically-adjacent to sync_mode) and the data-section field value 'pending' between custom_field_mappings and items (per plan Step 1). Template remains valid JSON (python3 round-trip passes).

2. scripts/integrations/github-status.sh — Edit A added sub_issue_mode to the required-fields schema-validation list; Edit B added it to the pending-sentinel detection list; Edit C added a SUB_ISSUE_MODE: <value> line to the configured-branch output (placed between SYNC_MODE and LAST_SYNC for one-field-one-line readability consistency with the P01 output contract). Header comment also updated to document the new output line. No behavioral changes beyond additive — exit codes, STATUS line format, and extract_field helper contract preserved.

3. commands/github-status.md — output example block additively updated to show the new SUB_ISSUE_MODE line and an example sub-issue representation gloss. P01 gate m013-p01-github-status-command.sh still passes (the gate asserts section presence + STATUS outcome coverage, not output-line counts).

4. scripts/integrations/sidecar-init-pending.sh — unchanged; the _schema_docs AWK stripper handles the extended template generically (verified via run-probe.sh staged probe: JSON valid, _schema_docs absent, sub_issue_mode='pending' after bootstrap).

P01 gate arbitration (plan Step 6): m013-p01-github-status.sh assertion 5 ('configured after completing pending fields') failed initially because the new sub_issue_mode field also defaults to 'pending' and therefore keeps the sidecar in pending-operator-complete state even after operator completes repo_slug + project_v2_id. Applied path (a): additive one-line sed step during the gate's configured-branch setup to replace sub_issue_mode 'pending' with 'labeled-fallback'. Three-line change, preserves the gate's behavioral contract (that sed-replacing pending sentinels reaches configured branch).

Verification:
- All 7 P02 verify gates PASS (github-common 13/13, github-init-fixture 5/5, github-init-preflight 7/7, auto-mode-pending 4/4, dry-run-manifest 5/5, github-init-command 6/6, reference-extensions all).
- All 3 P01 gates touching this surface PASS (sidecar-schema, github-status, github-status-command).
- P01 bash32-compat gate PASS (15/15 including the two modified .sh files).
- P01 phase-suite PASS (9/9 gates).
- JSON validity probe via scripts/util/run-probe.sh: bootstrap_rc=0, python assertion PASS, status_rc=0 with STATUS: pending-operator-complete and PENDING_FIELDS: repo_slug,project_v2_id,sub_issue_mode (sync_mode correctly NOT in pending list because its default 'manual' is non-pending — this matches the second acceptable outcome documented in plan Step 5).

Constraints satisfied: JSON validity preserved, _schema_docs stripper compatible, no behavioral changes beyond new field, Bash 3.2 compat (list additions only), Knowledge-Layer Boundary (no SPEC-* / knowledge-tree changes), AD-19 (single-script-file probe via run-probe.sh wrapper).

Operator-review items for T07 phase-suite assembly: none from T06 scope. The P01 gate update (m013-p01-github-status.sh sed additions) is additive-only and keeps P01 contract intent; T07 can include the updated P01 gate without reauth.
