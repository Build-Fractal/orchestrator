---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M043"
goal: "Idempotent Cloudflare provisioner (US-2): cloudflare-access-setup.sh provisions Pages project → Access app (apex+wildcard) → allow policy in that order, is a no-op on re-run, and fails loudly with an actionable diagnostic when Zero Trust is off or the token is under-scoped."
demo_sentence: "bash scripts/wiki/cloudflare-access-setup.sh against the recorded clean-account fixture creates resources in Pages-project → Access-app → policy order with both apex and wildcard self_hosted_domains; a second run against the all-present fixture issues zero creates and exits 0; the zero-trust-not-enabled and missing-scope fixtures each exit non-zero with a distinct, actionable diagnostic."
risk: "high"
depends_on: ["P00"]
---

## Must-Haves

### Truths

<!-- Project-owned, slug-bearing verifiers under tools/verify/. Each is
     authored by the task named in parentheses (Plan-Time Discipline rule 2:
     verifiers either pre-exist or are co-authored in the task whose
     deliverable they check). All are single-script-file shape (AD-19). -->

- The recorded-API fixtures exist as four scenario directories (clean-account, all-present, zero-trust-not-enabled, missing-scope), each holding well-formed JSON response files keyed by endpoint, and the clean-account Access-app create body carries BOTH the apex and wildcard `self_hosted_domains`. (T01)
  - Check: `bash tools/verify/m043-p02-fixtures-shape.sh`
- `scripts/wiki/cloudflare-access-setup.sh` exists, is Bash 3.2 compliant (no `declare -A`, no process substitution), routes all HTTP through a single `cf_api` transport seam, and declares the provisioning order Pages-project → Access-app → policy. (T02)
  - Check: `bash tools/verify/m043-p02-provisioner-shape.sh`
- Against the clean-account fixture the provisioner creates resources in the order Pages-project → Access-app → allow-policy, and the captured Access-app create payload's `self_hosted_domains` contains both `<name>.pages.dev` and `*.<name>.pages.dev` (SC-3, FR-6/FR-8). (T03)
  - Check: `bash tools/verify/m043-p02-create-order.sh`
- A second invocation against the all-present fixture issues zero create requests and exits 0 (SC-4, FR-7). (T03)
  - Check: `bash tools/verify/m043-p02-idempotency.sh`
- Against the zero-trust-not-enabled fixture the provisioner exits non-zero and prints the dashboard-enablement instruction; against the missing-scope fixture it exits non-zero and prints the scope-specific diagnostic naming the missing Access permission (SC-5, FR-9). (T03)
  - Check: `bash tools/verify/m043-p02-diagnostics.sh`

### Artifacts

- scripts/wiki/cloudflare-access-setup.sh (min 180 lines, contains "cf_api")
- tests/fixtures/m043-cloudflare/clean-account/access-app-create.response.json (min 5 lines, contains "self_hosted_domains")
- tests/fixtures/m043-cloudflare/all-present/access-policies-list.response.json (min 3 lines, contains "allow")
- tests/fixtures/m043-cloudflare/zero-trust-not-enabled/access-apps-list.response.json (min 3 lines, contains "_http_status")
- tests/fixtures/m043-cloudflare/missing-scope/access-apps-list.response.json (min 3 lines, contains "9109")
- tests/fixtures/m043-cloudflare/README.md (min 30 lines, contains "fixture-replay")
- tools/verify/m043-p02-fixtures-shape.sh (min 30 lines, contains "self_hosted_domains")
- tools/verify/m043-p02-provisioner-shape.sh (min 20 lines, contains "declare -A")
- tools/verify/m043-p02-create-order.sh (min 30 lines, contains "access-app-create")
- tools/verify/m043-p02-idempotency.sh (min 20 lines, contains "create")
- tools/verify/m043-p02-diagnostics.sh (min 30 lines, contains "missing-scope")
- tools/verify/m043-p02-phase-suite.sh (min 15 lines, contains "SUMMARY")

### Key Links

- tools/verify/m043-p02-create-order.sh → scripts/wiki/cloudflare-access-setup.sh (the create-order verifier invokes the provisioner)
- tools/verify/m043-p02-fixtures-shape.sh → tests/fixtures/m043-cloudflare (the fixtures-shape verifier asserts on the fixture tree)
- tools/verify/m043-p02-phase-suite.sh → tools/verify/m043-p02-diagnostics.sh (the aggregator runs the diagnostics gate)

## Tasks

### T01: Promote P00 seeds into recorded-API fixtures + define the fixture-replay contract

Promote the five P00 doc-derived seeds into `tests/fixtures/m043-cloudflare/`,
arranged into four scenario directories with endpoint-keyed response files, and
write the `README.md` that defines the fixture-replay contract the provisioner
(T02) implements against. Author the `m043-p02-fixtures-shape.sh` verifier. This
task establishes the seam: the provisioner's `cf_api` transport function reads
`<ENDPOINT_KEY>.response.json` files and records requests into a capture dir, so
the whole provisioner is testable without a live Cloudflare account. See
`tasks/T01-fixtures-and-contract-PLAN.md`.

### T02: The idempotent provisioner script

Author `scripts/wiki/cloudflare-access-setup.sh` — the `cf_api` transport seam
(real curl vs. fixture replay), flag/config/env input resolution (including the
`--project-dir` form `wiki-init.sh` invokes), and the provisioning logic:
Pages-project → Access-app (apex+wildcard) → allow-policy in order (FR-6/FR-8),
idempotent skip on already-present resources (FR-7), and the FR-9 diagnostic
branch (Zero-Trust-not-enabled vs. missing-scope vs. combined-fallback). Co-author
the static `m043-p02-provisioner-shape.sh` verifier. See
`tasks/T02-provisioner-PLAN.md`.

### T03: Behavioral verifiers + phase-suite aggregator

Author the three behavioral verifiers that drive the provisioner against the T01
fixtures — `m043-p02-create-order.sh` (SC-3), `m043-p02-idempotency.sh` (SC-4),
`m043-p02-diagnostics.sh` (SC-5) — plus `m043-p02-phase-suite.sh` aggregating all
five P02 gates. See `tasks/T03-verifiers-and-suite-PLAN.md`.

## Task Dependencies

```
T01 → T02 → T03
```

T01 defines the fixtures + replay contract (the seam). T02 builds the provisioner
to that contract. T03 authors the behavioral verifiers that exercise T02's
provisioner against T01's fixtures. Strictly linear — each task consumes the
prior task's on-disk output.

## Files Likely Touched

- scripts/wiki/cloudflare-access-setup.sh (create)
- tests/fixtures/m043-cloudflare/README.md (create)
- tests/fixtures/m043-cloudflare/clean-account/pages-project-get.response.json (create)
- tests/fixtures/m043-cloudflare/clean-account/pages-project-create.response.json (create)
- tests/fixtures/m043-cloudflare/clean-account/access-apps-list.response.json (create)
- tests/fixtures/m043-cloudflare/clean-account/access-app-create.response.json (create)
- tests/fixtures/m043-cloudflare/clean-account/access-policies-list.response.json (create)
- tests/fixtures/m043-cloudflare/clean-account/access-policy-create.response.json (create)
- tests/fixtures/m043-cloudflare/all-present/pages-project-get.response.json (create)
- tests/fixtures/m043-cloudflare/all-present/access-apps-list.response.json (create)
- tests/fixtures/m043-cloudflare/all-present/access-policies-list.response.json (create)
- tests/fixtures/m043-cloudflare/zero-trust-not-enabled/pages-project-get.response.json (create)
- tests/fixtures/m043-cloudflare/zero-trust-not-enabled/pages-project-create.response.json (create)
- tests/fixtures/m043-cloudflare/zero-trust-not-enabled/access-apps-list.response.json (create)
- tests/fixtures/m043-cloudflare/missing-scope/pages-project-get.response.json (create)
- tests/fixtures/m043-cloudflare/missing-scope/pages-project-create.response.json (create)
- tests/fixtures/m043-cloudflare/missing-scope/access-apps-list.response.json (create)
- tools/verify/m043-p02-fixtures-shape.sh (create)
- tools/verify/m043-p02-provisioner-shape.sh (create)
- tools/verify/m043-p02-create-order.sh (create)
- tools/verify/m043-p02-idempotency.sh (create)
- tools/verify/m043-p02-diagnostics.sh (create)
- tools/verify/m043-p02-phase-suite.sh (create)
