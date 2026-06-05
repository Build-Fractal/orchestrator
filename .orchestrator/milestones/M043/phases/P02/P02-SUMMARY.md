---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M043"
milestone: "M043"
provides:
  - "tests/fixtures/m043-cloudflare/ recorded-API fixture tree (4 scenarios) + fixture-replay contract README + m043-p02-fixtures-shape.sh verifier,scripts/wiki/cloudflare-access-setup.sh idempotent Cloudflare provisioner (FR-6..FR-9) + m043-p02-provisioner-shape.sh static verifier,three behavioral verifiers (m043-p02-create-order.sh SC-3,m043-p02-idempotency.sh SC-4,m043-p02-diagnostics.sh SC-5) + m043-p02-phase-suite.sh aggregator over all five P02 gates"
requires:
  - "P00"
affects:
  - "P03,P04"
key_files:
  - "tests/fixtures/m043-cloudflare/README.md,tests/fixtures/m043-cloudflare/clean-account/,tests/fixtures/m043-cloudflare/all-present/,tests/fixtures/m043-cloudflare/zero-trust-not-enabled/,tests/fixtures/m043-cloudflare/missing-scope/,tools/verify/m043-p02-fixtures-shape.sh,scripts/wiki/cloudflare-access-setup.sh,tools/verify/m043-p02-provisioner-shape.sh,tools/verify/m043-p02-create-order.sh,tools/verify/m043-p02-idempotency.sh,tools/verify/m043-p02-diagnostics.sh,tools/verify/m043-p02-phase-suite.sh"
key_decisions:
  - "cf_api <METHOD> <ENDPOINT_KEY> [BODY] seam with 6 stable endpoint keys; _http_status string envelope field carries HTTP status out-of-band; error fixtures surface on access-apps-list (first Access call); error discriminators (400,12130) vs (403,9109) per P00 #Q-6,single cf_api transport seam always called directly (never in $()) to preserve CF_HTTP_STATUS + CF_LAST_BODY_FILE globals under Bash 3.2; create order Pages project -> Access self-hosted app (apex+wildcard self_hosted_domains) -> allow policy; FR-9 emit_provision_diagnostic distinguishes missing-scope (403/9109/10000 -> exit 5) from zero-trust-not-enabled (access.api.error.* code namespace or message match -> exit 4) per P00 #Q-6,kept isolated for one-line P04 collapse contingency,behavioral verifiers invoke provisioner with --project-name '<name>' to align computed DOMAIN=<name>.pages.dev with placeholder-pure fixtures (load-bearing for idempotency match); phase-suite aggregates the two shape gates (T01,T02) + three behavioral gates (T03) and excludes itself (no recursion)"
patterns_established:
  - "endpoint-keyed <KEY>.response.json fixture-replay tree as the seam the provisioner (T02) builds against; placeholder-only fixtures (<name>/<allowed_email_domains>) keep secrets out of git,provisioner builds against T01's endpoint-keyed fixture-replay tree; --project-dir DIR awk-parses wiki.cloudflare.project_name + allowed_email_domains from <DIR>/.orchestrator/config.yml to satisfy wiki-init.sh's bash CF_SETUP --project-dir contract,Tier-3 behavioral verifier shape: mktemp -d capture dir,run provisioner in fixture-replay mode,assert on requests.log create-order + captured *.request.json bodies + stderr diagnostics,rm -rf cleanup for deterministic re-runs; phase-suite run_gate aggregator mirrors P01 SUMMARY: ... pass=N fail=N line"
drill_down_paths:
  - ".orchestrator/milestones/M043/phases/P02/tasks/T01-fixtures-and-contract-SUMMARY.md, .orchestrator/milestones/M043/phases/P02/tasks/T02-provisioner-SUMMARY.md, .orchestrator/milestones/M043/phases/P02/tasks/T03-verifiers-and-suite-SUMMARY.md"
duration: "0m"
verification_result: "pass"
completed_at: "2026-06-05T02:03:37Z"
observability_surfaces:
  - "tools/verify/m043-p02-phase-suite.sh (pass=5 fail=0)"
---

P02 delivers the idempotent Cloudflare provisioner — the second of the milestone's two CON-6 exposure-guard enforcement sites (P01 shipped the every-CI-deploy FR-3a health check; P02 ships the provisioning-time guarantee). Closed verify-pass at Full intensity under autonomous dispatch (3 tasks, T01→T03, strictly linear).

Shipped (3 tasks):
- T01 — promoted the five P00 doc-derived seeds into recorded-API fixtures under `tests/fixtures/m043-cloudflare/` (4 scenario dirs: clean-account, all-present, zero-trust-not-enabled, missing-scope) and authored the README defining the fixture-replay contract. This contract is the seam: `cf_api <METHOD> <ENDPOINT_KEY> [body]` replays `<ENDPOINT_KEY>.response.json` (envelope + a top-level `_http_status` field) and records requests to a capture dir, so the whole provisioner is verifiable with no live Cloudflare account. `tools/verify/m043-p02-fixtures-shape.sh` asserts the tree (49 checks).
- T02 — `scripts/wiki/cloudflare-access-setup.sh` (278 lines, Bash 3.2 / CON-5): the cf_api transport seam (real curl vs. fixture replay; called directly never in `$()` to avoid subshell global-loss), `--project-dir` config parse satisfying the existing wiki-init.sh `--deploy cloudflare-access` call, and the provisioning logic — Pages-project → Access-app (apex+wildcard `self_hosted_domains`) → allow-policy in order (FR-6/FR-8), idempotent skip on already-present resources (FR-7), FR-9 distinguishable diagnostics (Zero-Trust-off exit 4 vs. missing-scope exit 5) with the P00 contingency isolated for a one-line collapse-to-combined. `tools/verify/m043-p02-provisioner-shape.sh` enforces CON-5 + seam shape.
- T03 — three behavioral verifiers driving the provisioner against the fixtures: `m043-p02-create-order.sh` (SC-3 create-order + apex/wildcard from the captured payload), `m043-p02-idempotency.sh` (SC-4 zero creates on re-run), `m043-p02-diagnostics.sh` (SC-5 distinct zero-trust/missing-scope diagnostics + non-zero exits), plus `m043-p02-phase-suite.sh` aggregating all five P02 gates (pass=5 fail=0).

CON-6 (the load-bearing two-site exposure guard): the provisioning-time site is now in place and fail-closed — the FR-8 access-before-deploy invariant was verified live (a zero-trust run exits 4 with the `OK:` success line entirely absent; no completion signal when the Access gate cannot be confirmed). Combined with P01's every-CI-deploy health check, both sites ship.

Two defects caught and resolved during the run (both reported, neither absorbed):
1. T02 — the provisioner's own header comment contained the literal `declare -A`, tripping the shape verifier's CON-5 grep. Resolved by rewording the comment to "no associative arrays" (keeping the canonical gate intact), not weakening the verifier.
2. Phase plan (planner-authored) — an artifact must-have asserted `contains "allow"` against the all-present apps-list fixture, but `allow` lives in the sibling policies-list fixture. Pattern retargeted; the fixtures were always correct (T01's verifier + the behavioral suite were green throughout).

Verification: Tier 1 must-haves 44/0; boundary-map SKIP (prose-form Produces, as P01); Tier 2 framework SKIP (no configured commands) with the project phase-suite green (pass=5 fail=0); Tier 3 behavioral confirmed FR-6/7/8/9 + the access-before-deploy invariant via live fixture-replay runs; Tier 4 carries one deferred friendly-tester item (P04 live Cloudflare-API envelope confirmation). Report at phases/P02/P02-VERIFICATION.md (overall_result: pass).

Carried forward: fixtures are P00 doc-derived (Mode B); the `distinguishable` error-envelope decision and the Edit-scope-grants-read assumption carry `[unconfirmed-P04]` markers for the US-4 live pass. P03 (docs + the github-pages footgun warning) now has both its dependencies green — it consumes P01's `wiki.deploy_target` config key and P02's provisioner surface for the FR-11 docs.
