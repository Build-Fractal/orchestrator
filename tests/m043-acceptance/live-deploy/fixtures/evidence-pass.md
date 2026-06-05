---
schema_version: "1.0"
type: live-deploy-evidence
report_date: "2026-06-04"
redirect_verified: "yes"
ci_green: "yes"
giscus_working: "yes"
edit_scope_grants_read: "yes"
error_envelopes_match: "yes"
deferred_validation: "no"
signed_by: ""
---

# M043 Live-Deploy Evidence Note — Completed-Pass Fixture

This fixture is a well-shaped example of a **completed live pass**: the
SC-9 triad (`redirect_verified`, `ci_green`, `giscus_working`) is all
`"yes"`. `validate-evidence.sh` exits 0 on it via the completed-pass path.

## Capture 1 — 302 redirect gate

```
HTTP/2 302
location: https://example.cloudflareaccess.com/cdn-cgi/access/login/example.pages.dev
```

## Capture 2 — green CI run

- https://github.com/example/wiki/actions/runs/0000000000

## Capture 3 — giscus comment

- Posted as an allowed-domain user; comment persisted across reload.

## Capture 4 — #Q-5 Edit-scope-grants-read

- `GET /accounts/{id}/access/apps` with the Edit-only token returned
  `200` + the app list (AD-1 primary `authenticated-edit-token` confirmed).

## Capture 5 — #Q-6 error envelopes

- Zero-Trust-off: HTTP 400, code 12130. Missing-scope: HTTP 403, code 9109.
  Distinguishable on `(HTTP status, errors[].code)` as documented.
