---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M043"
provides:
  - "tests/fixtures/m043-cloudflare/ recorded-API fixture tree (4 scenarios) + fixture-replay contract README + m043-p02-fixtures-shape.sh verifier"
requires:
  - "from:P00 what:five doc-derived fixture-seeds + #Q-6 (status,code) distinguishability finding"
affects:
  - "T02"
key_files:
  - "tests/fixtures/m043-cloudflare/README.md,tests/fixtures/m043-cloudflare/clean-account/*.response.json,tests/fixtures/m043-cloudflare/all-present/*.response.json,tests/fixtures/m043-cloudflare/zero-trust-not-enabled/*.response.json,tests/fixtures/m043-cloudflare/missing-scope/*.response.json,tools/verify/m043-p02-fixtures-shape.sh"
key_decisions:
  - "cf_api <METHOD> <ENDPOINT_KEY> [BODY] seam with 6 stable endpoint keys; _http_status string envelope field carries HTTP status out-of-band; error fixtures surface on access-apps-list (first Access call); error discriminators (400,12130) vs (403,9109) per P00 #Q-6"
patterns_established:
  - "endpoint-keyed <KEY>.response.json fixture-replay tree as the seam the provisioner (T02) builds against; placeholder-only fixtures (<name>/<allowed_email_domains>) keep secrets out of git"
drill_down_paths:
  - ".orchestrator/milestones/M043/phases/P02/tasks/T01-fixtures-and-contract-PLAN.md"
duration: "fixture-authoring"
verification_result: "pass"
completed_at: "2026-06-04T00:00:00Z"
---

Promoted the five P00 doc-derived seeds into four scenario fixture dirs under tests/fixtures/m043-cloudflare/ (clean-account 6-call create path; all-present idempotency seed; zero-trust-not-enabled 400/code-12130; missing-scope 403/code-9109). Each response file is the Cloudflare {success,errors,messages,result} envelope plus a top-level _http_status string field. Authored README.md (>30 lines) defining the cf_api fixture-replay contract: 6 endpoint keys table, <ENDPOINT_KEY>.response.json naming, _http_status field, M043_CF_FIXTURE_DIR/M043_CF_CAPTURE_DIR env vars + requests.log/<KEY>.request.json capture, per-scenario call sequences, doc-derived/[unconfirmed-P04] provenance, and placeholder convention. Created tools/verify/m043-p02-fixtures-shape.sh verbatim per plan. Verifier output final line: SUMMARY: m043-p02-fixtures-shape.sh fail=0 (exit 0). No deviations from plan.
