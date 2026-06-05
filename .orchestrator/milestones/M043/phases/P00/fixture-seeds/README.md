# M043 P00 — Cloudflare API Fixture Seeds

These are the raw request/response **seeds** captured by the P00 Cloudflare API
characterization spike (T01). They back the findings in
[`../cloudflare-api-findings.md`](../cloudflare-api-findings.md).

**P02 promotes these seeds into `tests/fixtures/m043-cloudflare/`** as the
recorded-API fixtures that drive SC-3 (create-order + apex/wildcard), SC-4
(idempotent second run), SC-5 (Zero-Trust / missing-scope diagnostics), and
SC-10 (pre-deploy health-check ordering). P00 owns ONLY these raw seeds under the
P00 dir; it does not write into `tests/fixtures/`.

## Provenance

Every seed in this directory is **`doc-derived`** (execution Mode B — no live
Cloudflare credentials were available at spike time). Each was reconstructed from
Cloudflare's published API documentation and, where docs were silent, from
corroborating Cloudflare community-forum reports. The error-response seeds carry
`[unconfirmed-P04]` markers on every field that could not be confirmed from a
live API call. **P04 (the friendly-tester live-deploy pass) must capture the real
payloads and replace the doc-derived seeds**, per the per-file
`p04_forward_pointer` in each seed's `_seed_meta` block. This mirrors the
M033 / M041 deferred-validation house precedent (spec SC-9).

## Placeholder convention (no secrets in git)

No real Cloudflare account id, API token, project name, or email domain appears
in any seed (these files land in git history). Every value that is operator- or
account-specific is a literal placeholder, substituted at runtime by
`cloudflare-access-setup.sh`:

- `<account_id>` — the Cloudflare account id (from `CLOUDFLARE_ACCOUNT_ID`).
- `<name>` — the Pages project name (drives `<name>.pages.dev`).
- `<allowed_email_domains>` — the operator-supplied allow-list of email domains.
- `<app_uid>` — the Access-app uid returned by the app-create call.

## Seed inventory

| File | Source endpoint | Provenance |
| --- | --- | --- |
| `pages-project-create-request.json` | `POST /accounts/<account_id>/pages/projects` | doc-derived → P04 |
| `access-app-create-request.json` | `POST /accounts/<account_id>/access/apps` (self-hosted; `self_hosted_domains` = apex **and** wildcard) | doc-derived → P04 |
| `access-policy-create-request.json` | `POST /accounts/<account_id>/access/apps/<app_uid>/policies` (allow, email-domain include) | doc-derived → P04 |
| `zero-trust-not-enabled-response.json` | error envelope: Access-app create when Zero Trust is not enabled | doc-derived → P04 |
| `missing-scope-response.json` | error envelope: Access-app create when the token lacks `Access: Apps and Policies — Edit` | doc-derived → P04 |

## Notes

- `access-app-create-request.json`'s `self_hosted_domains` array intentionally
  carries BOTH `<name>.pages.dev` (apex) AND `*.<name>.pages.dev` (wildcard) —
  this is the seed for the SC-3 apex+wildcard assertion (FR-6/FR-8).
- The two error-response seeds are the seed for the FR-9 / SC-5 diagnostic
  distinguishability decision; the findings note records them as `distinguishable`
  by HTTP status + `errors[].code` namespace, pending the P04 live confirmation.
- All response seeds use Cloudflare's standard `{success, errors, messages, result}`
  envelope with an added top-level `_http_status` field (the HTTP status is not
  part of the JSON body; it is carried here so P02's fixtures can assert on it).
