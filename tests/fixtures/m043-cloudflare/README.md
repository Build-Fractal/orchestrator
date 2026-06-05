# M043 Cloudflare recorded-API fixtures

These recorded-API fixtures are promoted from the P00 doc-derived seeds at
`.orchestrator/milestones/M043/phases/P00/fixture-seeds/`. They let the P02
provisioner (`cloudflare-access-setup.sh`) be verified against canned Cloudflare
API responses without a live account. Together they drive **SC-3** (create-order
+ apex/wildcard `self_hosted_domains`), **SC-4** (idempotent second run — zero
creates when everything is already present), and **SC-5** (Zero-Trust-not-enabled
and missing-scope diagnostics).

## Fixture-replay contract

The provisioner routes ALL HTTP through one internal transport function, `cf_api`,
that has a **fixture-replay** mode. When `M043_CF_FIXTURE_DIR` is set, `cf_api`
returns canned responses from that directory and records each request into a
capture directory instead of calling the network.

Seam:

```
cf_api <METHOD> <ENDPOINT_KEY> [REQUEST_BODY_FILE]
```

`ENDPOINT_KEY` is a stable logical token chosen by the provisioner (NOT derived
from a URL). The six keys and the real Cloudflare endpoint each maps to:

| ENDPOINT_KEY | METHOD | Real endpoint |
| --- | --- | --- |
| `pages-project-get` | GET | `/accounts/{acct}/pages/projects/{name}` |
| `pages-project-create` | POST | `/accounts/{acct}/pages/projects` |
| `access-apps-list` | GET | `/accounts/{acct}/access/apps` |
| `access-app-create` | POST | `/accounts/{acct}/access/apps` |
| `access-policies-list` | GET | `/accounts/{acct}/access/apps/{uid}/policies` |
| `access-policy-create` | POST | `/accounts/{acct}/access/apps/{uid}/policies` |

**Response files.** In fixture mode, `cf_api` reads
`$M043_CF_FIXTURE_DIR/<ENDPOINT_KEY>.response.json`. Each response file is the
Cloudflare `{success, errors, messages, result}` envelope with an added top-level
`_http_status` string field. The HTTP status is not part of the JSON body; it is
carried here so the provisioner and the verifiers can branch on it. `cf_api`
strips `_http_status` into a global the caller reads and prints the remaining
envelope to stdout.

**Request capture.** When `M043_CF_CAPTURE_DIR` is set, `cf_api` appends one line
`<METHOD> <ENDPOINT_KEY>` to `$M043_CF_CAPTURE_DIR/requests.log` for every call
(order + idempotency assertions), and when `REQUEST_BODY_FILE` is given it copies
that body to `$M043_CF_CAPTURE_DIR/<ENDPOINT_KEY>.request.json` (payload
assertions, e.g. SC-3 apex+wildcard).

## Scenarios

- **clean-account** (SC-3): project absent → created; app absent → created; policy
  absent → created. Drives the full six-call create path.
  - `pages-project-get` → 404 (absent) → provisioner creates
  - `pages-project-create` → 200
  - `access-apps-list` → 200, `result: []` (app absent) → provisioner creates
  - `access-app-create` → 200, `result.id` = a fixture uid, `self_hosted_domains`
    carries BOTH apex and wildcard
  - `access-policies-list` → 200, `result: []` (policy absent) → provisioner creates
  - `access-policy-create` → 200, `result.decision: "allow"`
- **all-present** (SC-4): all three present → zero creates.
  - `pages-project-get` → 200 (exists) → skip
  - `access-apps-list` → 200, `result: [ {existing app, apex+wildcard} ]` → skip
  - `access-policies-list` → 200, `result: [ {allow policy} ]` → skip
- **zero-trust-not-enabled** (SC-5): Pages OK, first Access call errors.
  - `pages-project-get` → 404 → create
  - `pages-project-create` → 200
  - `access-apps-list` → `_http_status: "400"`, `errors[0].code: 12130`
    (`access.api.error.*` namespace) → provisioner emits the dashboard-enablement
    diagnostic, exits non-zero
- **missing-scope** (SC-5): Pages OK, first Access call 403.
  - `pages-project-get` → 404 → create
  - `pages-project-create` → 200
  - `access-apps-list` → `_http_status: "403"`, `errors[0].code: 9109` → provisioner
    emits the scope-specific diagnostic, exits non-zero

## Provenance

Every value is `doc-derived` (P00 Mode B) — none was captured from a live
Cloudflare account. The two error fixtures
(`zero-trust-not-enabled/access-apps-list.response.json` and
`missing-scope/access-apps-list.response.json`) carry `[unconfirmed-P04]` markers
in their messages: P04 (the friendly-tester live pass) must capture the real
envelopes and replace these.

The error envelopes are modelled on the `access-apps-list` (first Access) call
site even though the P00 seeds were captured as create-call envelopes. The same
envelope applies on a not-onboarded / under-scoped account, because the account
fails the same authorization / onboarding check on the first Access API call
regardless of method. This is the single, well-defined diagnostic check point the
provisioner branches on right after the first Access call; P04 confirms the exact
real shapes. The `(HTTP status, errors[].code)` discriminator pair —
`(400, 12130)` for Zero-Trust-not-enabled vs `(403, 9109)` for missing-scope —
encodes the `#Q-6` finding in
`.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` that the two
error envelopes are distinguishable.

## Placeholder convention

No real account id, API token, project name, or email domain appears in any
fixture (these files land in git). `<name>` is the runtime-substituted Pages
project name and `<allowed_email_domains>` is the runtime-substituted email-domain
allow value. Fixture uids are fixed literals (`app-uid-fixture-0001`,
`pol-uid-fixture-0001`) so the verifiers are deterministic.
