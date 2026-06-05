---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M043"
provides:
  - "scripts/wiki/cloudflare-access-setup.sh idempotent Cloudflare provisioner (FR-6..FR-9) + m043-p02-provisioner-shape.sh static verifier"
requires:
  - "from:T01 what:cf_api fixture-replay contract, 6 endpoint keys, _http_status envelope field, M043_CF_FIXTURE_DIR/M043_CF_CAPTURE_DIR env vars"
affects:
  - "T03"
key_files:
  - "scripts/wiki/cloudflare-access-setup.sh,tools/verify/m043-p02-provisioner-shape.sh"
key_decisions:
  - "single cf_api transport seam always called directly (never in $()) to preserve CF_HTTP_STATUS + CF_LAST_BODY_FILE globals under Bash 3.2; create order Pages project -> Access self-hosted app (apex+wildcard self_hosted_domains) -> allow policy; FR-9 emit_provision_diagnostic distinguishes missing-scope (403/9109/10000 -> exit 5) from zero-trust-not-enabled (access.api.error.* code namespace or message match -> exit 4) per P00 #Q-6, kept isolated for one-line P04 collapse contingency"
patterns_established:
  - "provisioner builds against T01's endpoint-keyed fixture-replay tree; --project-dir DIR awk-parses wiki.cloudflare.project_name + allowed_email_domains from <DIR>/.orchestrator/config.yml to satisfy wiki-init.sh's bash CF_SETUP --project-dir contract"
drill_down_paths:
  - ".orchestrator/milestones/M043/phases/P02/tasks/T02-provisioner-PLAN.md"
duration: "script-authoring"
verification_result: "pass"
completed_at: "2026-06-04T00:00:00Z"
---

Authored scripts/wiki/cloudflare-access-setup.sh verbatim per plan: an idempotent Cloudflare provisioner routing all HTTP through one cf_api transport seam with M043_CF_FIXTURE_DIR fixture-replay mode (reads _http_status string field, copies response body to CF_LAST_BODY_FILE) and M043_CF_CAPTURE_DIR capture (requests.log + <KEY>.request.json). Provisions in order: Pages project (create-if-absent) -> Access self-hosted app gating apex (NAME.pages.dev) + wildcard (*.NAME.pages.dev) self_hosted_domains -> allow policy keyed on email domains, each step idempotent via match-shapes mirroring the FR-3a health check. FR-9 emit_provision_diagnostic distinguishes missing-scope (exit 5) from zero-trust-not-enabled (exit 4), branches kept isolated per the P00 #Q-6 collapse contingency. --project-dir DIR awk-parses wiki.cloudflare.* from config.yml (satisfies wiki-init.sh ~line 1155). CON-5 Bash 3.2: no associative arrays, no process substitution. Co-authored tools/verify/m043-p02-provisioner-shape.sh verbatim per plan.

Verifiers: SUMMARY: m043-p02-provisioner-shape.sh fail=0 (exit 0); SUMMARY: m043-p02-fixtures-shape.sh fail=0 (exit 0). End-to-end smoke run against tests/fixtures/m043-cloudflare/clean-account exited 0 with final "OK: cloudflare-access-setup complete" line; /tmp/m043-t02-smoke/requests.log shows the expected six calls ending with the three creates in order (pages-project-create, access-app-create, access-policy-create).

Deviation: one comment line in the provisioner originally read "no `declare -A`, no process substitution" (verbatim from plan). The verbatim shape verifier's CON-5 gate greps the literal string `declare -A`, so that comment tripped a false-positive FAIL. The two verbatim sources collide on faithful transcription. Resolved by rewording the script comment to "no associative arrays, no process substitution" (semantics-preserving) rather than weakening the verifier's CON-5 grep, which remains the canonical project-owned gate. No logic changed.
