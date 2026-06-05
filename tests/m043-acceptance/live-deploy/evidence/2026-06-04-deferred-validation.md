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
signed_by: "Brett Kellgren"
---

# M043 Live-Deploy Evidence — Deferred-Validation Acknowledgment

<!--
  This is the signed deferred-validation note that forward-points the US-4
  live pass so M043 closes at shippable scope (the SC-9 "or" closing
  artifact). It does NOT claim the live deploy happened — the SC-9 triad
  fields stay "no" and the two P00 API confirmations stay "unconfirmed".
  Gate: bash tests/m043-acceptance/live-deploy/validate-evidence.sh <this-file>
-->

## Deferred-Validation Acknowledgment

M043 closes at **shippable scope (US-1..US-3)**. All three build phases are
verify-pass against recorded-API fixtures:

- **P01** — the `wiki.deploy_target` switch, the Cloudflare deploy workflow
  (`templates/wiki-cloudflare-deploy.yml.tmpl` → emitted
  `.github/workflows/wiki-cloudflare.yml`), and the FR-3a pre-deploy Access
  health check.
- **P02** — the idempotent Cloudflare provisioner
  (`scripts/wiki/cloudflare-access-setup.sh`: Pages project → Access app
  apex+wildcard → allow policy), with the FR-9 Zero-Trust-off vs.
  missing-scope diagnostics.
- **P03** — the private-Pages footgun warning, the FR-11 docs, and the
  giscus byte-stability check (giscus unchanged across deploy targets per
  FR-12).

The **US-4 live pass** requires a real Cloudflare account with **Zero Trust
enabled** — a one-time dashboard step that cannot be API-triggered — and is
therefore a **human-recruitment task per spec FR-13 / SC-9**, not something
the build phases can self-verify. No such account was available at close
time.

The live pass is **forward-pointed** to
`tests/m043-acceptance/live-deploy/protocol.md`. When a Cloudflare-equipped
tester runs that protocol, their filled evidence note lands beside this one
under `evidence/<DATE>.md`, `validate-evidence.sh` confirms the
completed-pass path (triad all `yes`), and this acknowledgment is retained
as the historical close rationale.

The two `[unconfirmed-P04]` API assumptions carried from P00 remain
**doc-derived** until the live pass confirms or corrects them:

- **#Q-5 (Edit-scope-grants-read)** — whether `Access: Apps and Policies —
  Edit` grants the read the FR-3a probe needs. Inside AD-1's sanctioned
  set: if Edit does not grant read, the probe falls back to
  `unauthenticated-redirect-fallback` (`302 → cloudflareaccess.com`).
- **#Q-6 (error-envelope discriminators)** — whether the Zero-Trust-off
  (HTTP 400 / code 12130) and missing-scope (HTTP 403 / code 9109)
  envelopes stay distinguishable. Inside FR-9's sanctioned set: if they
  collapse, P02's diagnostic-emit path is a one-line change to a combined
  diagnostic.

Because both assumptions sit inside their respective sanctioned fallback
sets, **neither blocks shippable-scope closure**.

This acknowledgment is signed by the operator who authorized closing M043
at shippable scope (`signed_by: "Brett Kellgren"` in the frontmatter), per
sanctioned house deferred-validation precedent (M032 SC-5 / M033 / M036
P03).
