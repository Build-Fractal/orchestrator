# M043 Live-Deploy Validation Protocol

<!--
  Authoritative reference: M043 spec FR-13 / US-4 / SC-9.
  This protocol document is markdown-only — it runs no commands. It
  instructs a human (a recruited tester or a maintainer with a real
  Cloudflare account) on how to provision and deploy a Cloudflare-Access-
  gated orchestrator wiki end-to-end and capture the SC-9 evidence.

  Mechanical gate: the filled-out evidence note is fed to
  `validate-evidence.sh` in this same directory. SC-9 closes when EITHER:
    - the SC-9 triad is all-yes
        (redirect_verified + ci_green + giscus_working), OR
    - a signed deferred-validation note is present
        (deferred_validation: yes + signed_by: <non-empty>).
  A missing evidence note prints
  `live-deploy validation not run -- milestone close blocked` and exits 1.
-->

## Purpose

The M043 build phases verified the Cloudflare path **entirely against
recorded-API fixtures** — P00 ran in Mode B (doc-derived; no live
Cloudflare credentials at spike time), and P01/P02/P03 exercise the
provisioner and the emitted workflow against those captured fixtures
under `tests/fixtures/m043-cloudflare/`. Mechanical correctness is
proven; a real account is not.

A live pass is the only thing that confirms, against a real Cloudflare
account:

1. the live `https://<name>.pages.dev` URL actually returns a `302`
   redirect to `*.cloudflareaccess.com` for an unauthenticated request
   (the Access gate is closed — no wiki content is served);
2. a **green CI** run of the emitted `wiki-cloudflare.yml` workflow,
   including the FR-3a pre-deploy Access health check, then the
   `npx --yes wrangler@4 pages deploy` step;
3. a working **giscus** comment on the deployed wiki (giscus is unchanged
   across deploy targets per FR-12);
4. the `#Q-5` assumption (`Access: Apps and Policies — Edit` grants the
   read access the FR-3a probe needs); and
5. the `#Q-6` assumption (the Zero-Trust-not-enabled vs. missing-scope
   error envelopes are mechanically distinguishable).

Items 4 and 5 are carried from P00's `cloudflare-api-findings.md` as
`[unconfirmed-P04]` / `doc-derived`. They are inside AD-1's / FR-9's
sanctioned fallback sets, so neither blocks shippable-scope closure — but
the live pass exists to confirm or correct them.

Closing M043 at shippable scope (US-1..US-3) with this live pass
**forward-pointed under a signed deferred-validation note** is sanctioned
house precedent (it matches the deferred-validation acknowledgments used
to close M032, M033, and M036). The deferred note does not claim the live
deploy happened — it records that the live pass is forward-pointed to
this protocol and names the operator who authorized closing at shippable
scope.

## Tester Eligibility

A tester is eligible to run this pass iff they self-attest to BOTH of:

- (a) they have a real Cloudflare account they can **enable Zero Trust**
  on (or have access to one); and
- (b) they have a **private test repo** (or can create one) where the
  orchestrator wiki can be initialized and deployed.

Unlike the M033 friendly-tester pass, this pass is **not** about
cold-start UX. The gate here is "did the live deploy actually gate the
wiki" — a mechanical, account-dependent fact, not a first-impression
judgment. **Maintainers ARE eligible** to run this pass (the M033
exclusion of maintainers does not apply); the only scarce qualification
is access to a real Cloudflare account with Zero Trust.

## Pre-Conditions

Before the walkthrough, the tester provisions:

- A Cloudflare account with **Zero Trust enabled**. This is a one-time
  dashboard step that **cannot be API-triggered** (cite FR-9 / the P00
  `#Q-6` finding) — the account must be onboarded to Zero Trust in the
  Cloudflare dashboard first.
- A `CLOUDFLARE_API_TOKEN` scoped to exactly **`Access: Apps and
  Policies — Edit` + `Pages — Edit` + `Account Settings — Read`** — and
  **NO** extra `Access: Apps and Policies — Read` scope (the FR-3a probe
  deliberately reuses the Edit token per P00 `#Q-5`; the pass exists in
  part to confirm Edit alone grants the read the probe needs).
- A `CLOUDFLARE_ACCOUNT_ID`.
- Both `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` placed in the
  test repo's **GitHub Actions secrets**.
- A **private GitHub repo** with an orchestrator-managed wiki (run
  `orchestrator:wiki-init` first if the wiki is not yet present).

## Walkthrough

Run these steps verbatim from inside a checkout of the orchestrator repo,
against the private test repo. Record every observation into the evidence
note (copy `evidence-template.md` to `evidence/<today>.md`). Adapt exact
flag spellings to the live `--help` output of each script — do not invent
flags the scripts do not expose.

1. In the test repo's `.orchestrator/config.yml`, set
   `wiki.deploy_target: cloudflare-access` and fill the `wiki.cloudflare:`
   sub-block: `project_name`, the account-id source, and
   `allowed_email_domains` (the email domains permitted through the Access
   allow policy).

2. Provision Cloudflare:
   `bash scripts/wiki/cloudflare-access-setup.sh --project-dir <repo>`.
   This creates the Pages project → the Access app (covering both the
   apex `<name>.pages.dev` AND the wildcard `*.<name>.pages.dev`) → the
   allow policy. Expect the `OK: cloudflare-access-setup complete ...`
   success line. On a Zero-Trust-off account expect a **non-zero exit**
   with the FR-9 diagnostic — record the real HTTP status + error code
   for the `#Q-6` confirmation (Capture 5).

3. Re-run the exact same command and confirm it is a **no-op** (idempotent
   — zero creates; this is the SC-4 live confirmation).

4. Trigger the first deploy:
   `bash scripts/lifecycle/wiki-init.sh --project-dir <repo> --deploy`
   (with `deploy_target: cloudflare-access` resolved from config). This
   emits the `.github/workflows/wiki-cloudflare.yml` workflow and runs the
   provisioning step; push to `main` to trigger the workflow. Record the
   CI run URL.

5. Wait for the CI run to go **green CI**: the FR-3a pre-deploy Access
   health check must pass first, then `npx --yes wrangler@4 pages deploy`
   runs.

6. **Capture 1 — 302 gate**: from an unauthenticated client, run
   `curl -sI https://<name>.pages.dev` and confirm a `302` status with a
   `location:` header pointing at `*.cloudflareaccess.com`. Record the
   exact status line and `location:` header. No wiki content should be
   served to the unauthenticated request.

7. **Capture 2 — green CI**: record the green workflow-run URL.

8. **Capture 3 — giscus**: log in as an allowed-domain user, open a wiki
   page, post a giscus comment, and confirm it persists across a reload.

9. **Capture 4 — #Q-5 (Edit-scope-grants-read)**: with the **Edit-only**
   token (no Read scope), issue a real
   `GET /accounts/{id}/access/apps` (e.g. via `curl` with an
   `Authorization: Bearer <token>` header) and record whether it returns
   `200` + the app list or `403`. A `200` confirms the AD-1 primary
   `authenticated-edit-token` FR-3a probe. A `403` means the tester
   records the sanctioned fallback (`unauthenticated-redirect-fallback`:
   assert `302 → cloudflareaccess.com` on `https://<name>.pages.dev` with
   a `Cache-Control: no-cache` / retry-window CDN mitigation) — no spec
   re-litigation; both are inside AD-1's sanctioned set.

10. **Capture 5 — #Q-6 (error envelopes)**: record the real HTTP status +
    `errors[].code` body field for a Zero-Trust-off attempt (HTTP 400,
    code 12130 expected from the doc-derived fixtures) and, if
    reproducible, a token-missing-scope attempt (HTTP 403, code 9109
    expected). Confirm the two remain distinguishable on the
    `(HTTP status, errors[].code)` discriminator. If real behavior differs
    — e.g. the two conditions collapse to one envelope — record the
    divergence so P02's FR-9 discriminators (or the one-line
    collapse-to-combined-diagnostic contingency) can be reconciled.

## What to capture

Copy `evidence-template.md` to `evidence/<today's date>.md` and fill its
frontmatter scalars:

- `redirect_verified` — yes iff Capture 1 showed `302 → cloudflareaccess.com`.
- `ci_green` — yes iff Capture 2's workflow run went green.
- `giscus_working` — yes iff Capture 3's comment posted and persisted.
- `edit_scope_grants_read` — `yes` / `no` per Capture 4 (informational).
- `error_envelopes_match` — `yes` / `no` per Capture 5 (informational).

The first three are the **SC-9 triad**; set all three to `yes` for a
completed live pass. The last two are P00 forward-pointed confirmations —
informational, not gating.

If the live pass **cannot be completed** (no Cloudflare account available),
the maintainer instead files a **signed deferred-validation note**:
`deferred_validation: yes` + `signed_by: <maintainer handle>`. This is the
sanctioned SC-9 "or" closing path — it forward-points the live pass and
records who authorized closing at shippable scope. It does NOT claim the
live deploy happened.

## Reporting

The filled evidence note goes to
`tests/m043-acceptance/live-deploy/evidence/<DATE>.md`. The mechanical gate
is:

```bash
bash tests/m043-acceptance/live-deploy/validate-evidence.sh \
  tests/m043-acceptance/live-deploy/evidence/<DATE>.md
```

It exits 0 iff EITHER the SC-9 triad is all-yes OR a signed
deferred-validation note is present. A missing note prints
`live-deploy validation not run -- milestone close blocked` and exits 1
(fail-closed).

When a Cloudflare-equipped tester later completes this protocol, their
filled note lands beside any deferred note under `evidence/<DATE>.md`,
`validate-evidence.sh` confirms the completed-pass path, and the deferred
note is retained as the historical close rationale.
