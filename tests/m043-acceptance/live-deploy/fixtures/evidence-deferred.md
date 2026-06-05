---
schema_version: "1.0"
type: live-deploy-evidence
report_date: "2026-06-04"
redirect_verified: "no"
ci_green: "no"
giscus_working: "no"
edit_scope_grants_read: "unconfirmed"
error_envelopes_match: "unconfirmed"
deferred_validation: "yes"
signed_by: "maintainer-handle"
---

# M043 Live-Deploy Evidence Note — Signed-Deferred Fixture

This fixture is a well-shaped example of the **signed deferred-validation**
closing path: the SC-9 triad stays all `"no"`, `deferred_validation` is
`"yes"`, and `signed_by` is non-empty. `validate-evidence.sh` exits 0 on it
via the deferred path. It does NOT claim the live deploy happened.

## Deferred-Validation Acknowledgment

- Reason the live pass is deferred: no Cloudflare account with Zero Trust
  available at close time.
- Forward-pointer: `tests/m043-acceptance/live-deploy/protocol.md`.
- Signer: the maintainer who authorized closing at shippable scope (see
  `signed_by` in the frontmatter).
