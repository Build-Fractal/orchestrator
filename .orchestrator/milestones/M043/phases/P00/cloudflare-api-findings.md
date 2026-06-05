---
schema_version: "1.0"
type: spike-findings
milestone: "M043"
phase: "P00"
created_at: "2026-06-04"
execution_mode: "doc-derived"
---

# M043 P00 — Cloudflare API Characterization Findings

**Source / resolves:** the open questions `#Q-5` (FR-3a probe mechanism) and `#Q-6`
(FR-9 error envelope) in `specs/043-wiki-cloudflare-access-deploy-target/spec.md`,
under the AD-1 decision tree in `M043-CONTEXT.md`. Consumed by P01 (FR-3a probe
shape + FR-11 token-scope table) and P02 (FR-9 diagnostics + fixture promotion).

**Execution mode: Mode B (doc-derived).** No live Cloudflare credentials were
available at spike time (`CLOUDFLARE_ACCOUNT_ID` / `CLOUDFLARE_API_TOKEN` unset).
Both Decisions below are committed on Cloudflare's published API documentation
(via WebFetch/WebSearch over `developers.cloudflare.com` + corroborating
community-forum evidence) and are tagged `doc-derived` with a P04
live-confirmation forward-pointer, per Principle II (no claim asserted beyond its
evidence).

**Ground-truth cross-check (`live-confirmed-from-pbj-central`).** The downstream
project `pbj-central-mono-repo` runs a WORKING Cloudflare Pages deploy half
(`.github/workflows/wiki-deploy.yml`, read 2026-06-04). It confirms, from a real
green CI run:

- The deploy invocation shape:
  `npx --yes wrangler@4 pages deploy <dir> --project-name=<name> --branch=main --commit-dirty=true`
  (the workflow uses `wiki/site` / `pbj-wiki`).
- The use of `npx` over `cloudflare/wrangler-action` — the workflow comment states
  the action auto-detects `bun` from the app repo and fails on a clean runner
  (`Unable to locate executable file: bun`). This is **CON-2 confirmed live**.
- The two repo secrets: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.
- The build-pipeline order: checkout → setup-python 3.12 (pip cache on
  `wiki/requirements.txt`) → `pip install -r wiki/requirements.txt` →
  wiki-stubs-fresh check → materialize `wiki/.staged/` (decorator-or-verbatim
  fallback) → `mkdocs build -f wiki/mkdocs.yml` → deploy. CON-1 build-pipeline
  carry-over confirmed live.

**The concrete "before" that FR-3a defends against (`live-confirmed-from-pbj-central`).**
pbj-central's working workflow has **NO pre-deploy Access health-check step** — it
deploys straight after `mkdocs build`. Its Access app + policy + Zero Trust were
provisioned in the Cloudflare **dashboard**, not in the repo, so the repo holds NO
captured API payloads, NO provisioning script, and NO error envelopes. This is
exactly the steady-state exposure window FR-3a closes: a post-provisioning Zero
Trust lapse / Access-app deletion / policy misconfiguration would let pbj-central
ship an ungated wiki on a green run. Because the dashboard path captured nothing,
**#Q-5-sub, #Q-6, and every provisioning fixture seed are `doc-derived`** (pbj
gives the deploy-step shape, not the provisioning API surface).

## #Q-5-sub — Does Access "Apps and Policies — Edit" grant read access?

**Question.** The FR-3a pre-deploy health check (the load-bearing CON-6
every-CI-deploy enforcement site, AD-1) must confirm, before every
`wrangler pages deploy`, that the Access app + allow policy for `<name>.pages.dev`
still exist. AD-1 chose to reuse the existing `Access: Apps and Policies — Edit`
token for this — **but only if Edit grants enough read access to GET/list the
Access apps + policies.**

**Evidence (doc-derived).**

- The permission group **does** expose two distinct options
  (`developers.cloudflare.com/fundamentals/api/reference/permissions/`):
  - *Access: Apps and Policies Read* — "Grants read access to Cloudflare Access
    applications and policies"
  - *Access: Apps and Policies Edit* — "Grants write access to Cloudflare Access
    applications and policies"
- Cloudflare's documented permission model treats **Edit as full CRUDL**
  (create, read, update, delete, list) while **Read is read + list where
  appropriate** — i.e. Edit is a superset of Read. (Corroborated across the
  permissions reference + Cloudflare community guidance;
  `community.cloudflare.com` threads referencing the `Edit` group for full Access
  app/policy management.)
- The read endpoint exists and returns the standard envelope:
  **`GET /accounts/{account_id}/access/apps`** →
  `{ success, errors[], messages[], result[] }` with `result[]` carrying the
  self-hosted app objects (confirmed from the Access applications *list* API
  reference).
- **Caveat (Principle II):** the authoritative per-permission-group reference page
  does NOT explicitly print the sentence "Edit is a superset of Read" for *this
  specific* group. The CRUDL-superset relationship is Cloudflare's general,
  community-corroborated model, not a quoted per-group guarantee. This is the one
  residual risk that the AD-1 fallback exists to catch.

### FR-3a Probe Decision

- Decision: `authenticated-edit-token`
- Provenance: `doc-derived`
- Justification: Cloudflare's documented permission model makes `Edit` a full
  CRUDL superset of `Read`, and the `GET /accounts/{account_id}/access/apps` list
  endpoint returns the app objects under the standard envelope. The FR-3a probe is
  therefore an authenticated `GET` (apps list, filtered to the apex
  `<name>.pages.dev` + wildcard `*.<name>.pages.dev`, then the per-app policies
  list) using the `CLOUDFLARE_API_TOKEN` already in repo secrets — **no new
  operator token scope**. This keeps AD-1's primary option and avoids the
  rejected new-Read-scope's operator-provisioning friction + 403-on-every-CI-run
  risk. **P04 live-confirmation forward-pointer:** the friendly-tester live-deploy
  pass MUST issue a real `GET /accounts/{id}/access/apps` with an Edit-only
  (no-Read) token and confirm it returns `200` + the app list (not `403`). If P04
  finds Edit does NOT grant read, fall back to AD-1's
  `unauthenticated-redirect-fallback` (assert `302 → cloudflareaccess.com` on
  `https://<name>.pages.dev`, with a `Cache-Control: no-cache` / retry-window
  mitigation for CDN edge-cache false positives) — no spec re-litigation needed,
  as both are inside AD-1's sanctioned set.
- Token-scope implication for FR-11 docs + the Assumptions table: with this
  Decision, the documented token scopes remain **`Access: Apps and Policies —
  Edit` + `Pages — Edit` + `Account Settings — Read`** with **NO additional
  `Access: Apps and Policies — Read` scope**. FR-11's scope table and the
  Assumptions "health-check scope (gate MIT-3)" note must state that the FR-3a
  authenticated probe reuses the Edit scope and requires no extra scope. (If P04
  forces the redirect fallback, the table is unchanged — the fallback needs no
  scope either.)

## #Q-6 — Zero-Trust-not-enabled vs. token-missing-scope error envelope

**Question.** FR-9 requires the provisioner to emit an *actionable* diagnostic
distinguishing "Cloudflare Zero Trust not enabled on this account" (a one-time
dashboard step that cannot be API-triggered) from "token is missing a required
scope." Per Principle II the spec must not assert these are distinguishable
without evidence.

**Evidence — the two documented envelopes, side by side (doc-derived).** Both use
Cloudflare's standard body envelope `{ success:false, errors:[{code,message}],
messages:[], result:null }`; the discriminators are HTTP status + the
`errors[].code` namespace.

| Field | Zero-Trust-not-enabled | Token-missing-scope |
| --- | --- | --- |
| HTTP status | `4xx` invalid-request — `[unconfirmed — P04]`, community reports the `access.api.error.*` path (e.g. `400`) | `403` (authz) — documented for authorization failures |
| `errors[].code` | `access.api.error.*` namespace, e.g. `12130` (`access.api.error.invalid_request`) — `[unconfirmed — P04]` for the exact not-onboarded code | `9109` ("Unauthorized to access requested resource") or `10000` ("Authentication error") — documented authz codes; exact code `[unconfirmed — P04]` |
| `errors[].message` | account-not-onboarded / Zero-Trust-not-enabled text — `[unconfirmed — P04]` | "Unauthorized to access requested resource" / "Authentication error" — documented |
| `success` | `false` | `false` |

Evidence basis: the `9109`/`10000` authz codes are the documented Cloudflare
authentication/authorization errors for an under-scoped or invalid token (HTTP
403). The Zero-Trust/Access-not-provisioned condition surfaces through a
**different** error namespace (`access.api.error.*`, e.g. `12130`) at a different
HTTP status (4xx invalid-request, not 403 authz). The two envelopes therefore
differ on BOTH the HTTP status axis AND the `errors[].code` namespace axis.

### FR-9 Diagnostic Decision

- Decision: `distinguishable`
- Provenance: `doc-derived`
- Comparison evidence: the missing-scope condition is an **authorization** failure
  (HTTP `403`, code `9109`/`10000`), while the Zero-Trust-not-enabled condition is
  an **invalid-request / not-provisioned** failure in the `access.api.error.*`
  namespace at a non-403 4xx status. They diverge on HTTP status AND error-code
  namespace, so the provisioner can mechanically branch on `(_http_status,
  errors[0].code)` to emit the correct diagnostic. **SC-5 stands as written** — the
  two-fixture assertion (one Zero-Trust-not-enabled fixture, one missing-scope
  fixture, two distinct diagnostics) is satisfiable; **no SC-5 revision is
  required.**
- P04 live-confirmation forward-pointer: because the exact codes/status for the
  Zero-Trust-not-enabled envelope and the precise missing-scope code are
  `[unconfirmed — P04]`, the friendly-tester live-deploy pass MUST capture both
  real envelopes (POST an Access-app create on an un-onboarded account; POST with
  a Pages-only token) and confirm they remain distinguishable on the
  `(HTTP status, errors[].code)` discriminator. **Contingency for P02 (recorded so
  P02 inherits the risk, not just P04):** if the live capture shows the two
  conditions collapse to one envelope (same status + same code), the Decision
  flips to `indistinguishable` and P02 must emit a SINGLE combined diagnostic
  naming both conditions; SC-5 would then be satisfied by that combined-diagnostic
  shape. P02 should build the diagnostic-emit path so this collapse is a one-line
  change, not a redesign.

## Fixture-Seed Inventory

All seeds live under `fixture-seeds/`. **P02 promotes them into
`tests/fixtures/m043-cloudflare/`** as the recorded-API fixtures for
SC-3/SC-4/SC-5/SC-10. All are `doc-derived` (Mode B); each carries a per-file
`p04_forward_pointer` in its `_seed_meta`.

| Seed file | Source endpoint | Provenance |
| --- | --- | --- |
| `pages-project-create-request.json` | `POST /accounts/<account_id>/pages/projects` | doc-derived → P04 |
| `access-app-create-request.json` | `POST /accounts/<account_id>/access/apps` (`self_hosted_domains` = apex `<name>.pages.dev` AND wildcard `*.<name>.pages.dev`) | doc-derived → P04 |
| `access-policy-create-request.json` | `POST /accounts/<account_id>/access/apps/<app_uid>/policies` (allow, email-domain include) | doc-derived → P04 |
| `zero-trust-not-enabled-response.json` | error envelope: Access-app create with Zero Trust not enabled | doc-derived → P04 |
| `missing-scope-response.json` | error envelope: Access-app create with token missing `Access: Apps and Policies — Edit` | doc-derived → P04 |

(`fixture-seeds/README.md` documents per-seed source/provenance + the
placeholder convention + the P02 promotion note.)

## Evidence Provenance

- Execution mode: **Mode B (doc-derived).** No live Cloudflare credentials at
  spike time; both Decisions committed on Cloudflare published documentation +
  corroborating community evidence, cross-checked against the working
  `pbj-central-mono-repo` deploy half for the deploy-step / build-pipeline shape.

Per-finding provenance summary:

- **Deploy-step shape, CON-2 (npx-not-action), CON-1 build-pipeline, two repo
  secrets, FR-3a "before" exposure window** — `live-confirmed-from-pbj-central`
  (read from `pbj-central-mono-repo/.github/workflows/wiki-deploy.yml`,
  2026-06-04, a real green CI run).
- **#Q-5-sub FR-3a Probe Decision (`authenticated-edit-token`)** — `doc-derived`.
  P04 forward-pointer: live `GET /accounts/{id}/access/apps` with an Edit-only
  token must return `200` + app list; else fall back to AD-1
  `unauthenticated-redirect-fallback`.
- **#Q-6 FR-9 Diagnostic Decision (`distinguishable`)** — `doc-derived`. P04
  forward-pointer: live capture of both error envelopes must confirm they remain
  distinguishable on `(HTTP status, errors[].code)`; contingency to
  `indistinguishable` + combined diagnostic recorded for P02.
- **All five fixture seeds** — `doc-derived` (synthetic-from-docs). P04
  forward-pointer: each seed's `_seed_meta.p04_forward_pointer`; error-response
  seeds carry `[unconfirmed-P04]` markers on every field not confirmable from
  docs.

Re-litigation flags: **none.** Both Decisions land inside AD-1 / SC-5 as written;
the FR-3a Decision is AD-1's primary (`authenticated-edit-token`), with AD-1's own
fallback (`unauthenticated-redirect-fallback`) reserved as the P04 contingency, so
the rejected `authenticated-new-read-scope` option is NOT adopted and no spec
re-litigation is requested.
