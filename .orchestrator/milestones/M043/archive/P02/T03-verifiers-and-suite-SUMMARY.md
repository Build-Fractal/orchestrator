---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M043"
provides:
  - "three behavioral verifiers (m043-p02-create-order.sh SC-3, m043-p02-idempotency.sh SC-4, m043-p02-diagnostics.sh SC-5) + m043-p02-phase-suite.sh aggregator over all five P02 gates"
requires:
  - "from:T01 what:tests/fixtures/m043-cloudflare/ four-scenario fixture tree + m043-p02-fixtures-shape.sh gate"
  - "from:T02 what:scripts/wiki/cloudflare-access-setup.sh provisioner with M043_CF_FIXTURE_DIR/M043_CF_CAPTURE_DIR replay+capture seam + m043-p02-provisioner-shape.sh gate"
affects:
  - "phase P02 closure (phase-suite is the aggregate gate)"
key_files:
  - "tools/verify/m043-p02-create-order.sh,tools/verify/m043-p02-idempotency.sh,tools/verify/m043-p02-diagnostics.sh,tools/verify/m043-p02-phase-suite.sh"
key_decisions:
  - "behavioral verifiers invoke provisioner with --project-name '<name>' to align computed DOMAIN=<name>.pages.dev with placeholder-pure fixtures (load-bearing for idempotency match); phase-suite aggregates the two shape gates (T01,T02) + three behavioral gates (T03) and excludes itself (no recursion)"
patterns_established:
  - "Tier-3 behavioral verifier shape: mktemp -d capture dir, run provisioner in fixture-replay mode, assert on requests.log create-order + captured *.request.json bodies + stderr diagnostics, rm -rf cleanup for deterministic re-runs; phase-suite run_gate aggregator mirrors P01 SUMMARY: ... pass=N fail=N line"
drill_down_paths:
  - ".orchestrator/milestones/M043/phases/P02/tasks/T03-verifiers-and-suite-PLAN.md"
duration: "verifier-authoring"
verification_result: "pass"
completed_at: "2026-06-04T00:00:00Z"
---

Authored the three P02 behavioral verifiers verbatim per plan plus the phase-suite aggregator. m043-p02-create-order.sh (SC-3) drives the provisioner against the clean-account fixture and asserts pages-project -> access-app -> policy create order with apex+wildcard self_hosted_domains in the captured access-app-create body. m043-p02-idempotency.sh (SC-4) drives the all-present fixture and asserts exit 0 with zero -create requests. m043-p02-diagnostics.sh (SC-5) drives the zero-trust-not-enabled (rc=4) and missing-scope (rc=5) fixtures and asserts non-zero exits with distinct, mutually-exclusive actionable diagnostics. m043-p02-phase-suite.sh aggregates all five P02 gates (fixtures-shape, provisioner-shape, create-order, idempotency, diagnostics) via run_gate, excluding itself. All four files transcribed verbatim — no assertion changes. Verification: each behavioral verifier ends SUMMARY: <name> fail=0 (exit 0); the aggregator prints SUMMARY: m043-p02-phase-suite.sh pass=5 fail=0 (exit 0). No deviations or discrepancies — every gate passed first run.
