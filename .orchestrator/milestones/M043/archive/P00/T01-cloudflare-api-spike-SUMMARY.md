---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P00"
milestone: "M043"
provides:
  - "Cloudflare API characterization findings note (FR-3a probe Decision + FR-9 diagnostic Decision) + 5 doc-derived fixture seeds for P02"
requires:
  - "from:none what:none (head of phase)"
affects:
  - "P01,P02"
key_files:
  - ".orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md,.orchestrator/milestones/M043/phases/P00/fixture-seeds/"
key_decisions:
  - "FR-3a=authenticated-edit-token (doc-derived); FR-9=distinguishable (doc-derived); SC-5 unchanged"
patterns_established:
  - "Mode-B doc-derived spike with per-finding provenance tags + P04 live-confirmation forward-pointers"
drill_down_paths:
  - ".orchestrator/milestones/M043/phases/P00/tasks/T01-cloudflare-api-spike-PLAN.md"
duration: "56m"
verification_result: "pass"
completed_at: "2026-06-04T23:52:21Z"
---

Mode B (doc-derived) spike, cross-checked against the working pbj-central wiki-deploy.yml. FR-3a Probe Decision = authenticated-edit-token (Cloudflare Edit permission documented as a superset of Read; reuses the existing repo-secret token, no new scope — stays AD-1 primary; P04 must confirm an Edit-only token returns 200 not 403, else fall back to AD-1 unauthenticated-redirect-fallback). FR-9 Diagnostic Decision = distinguishable (missing-scope is 403 code 9109/10000; Zero-Trust-not-enabled is a non-403 4xx in the access.api.error.* namespace e.g. 12130 — branch on (http_status, errors[0].code)); SC-5 needs no revision, with a one-line collapse-to-combined contingency noted for P02 if P04 disproves. pbj-central confirmed live: CON-2 (npx --yes wrangler@4 over wrangler-action, bun-autodetect reason), CON-1 build pipeline, the two repo secrets, and that its working workflow has NO pre-deploy Access health check — the exact steady-state exposure window FR-3a closes. [unconfirmed — P04]: exact Zero-Trust-not-enabled status+code, missing-scope code (9109 vs 10000), and Edit-grants-read confirmation. No spec re-litigation; rejected authenticated-new-read-scope option not adopted.
