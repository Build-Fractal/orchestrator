---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M043"
name: "Live-deploy protocol + recruitment kit"
depends_on: []
---

## Prerequisites

This task has no upstream task dependencies inside P04. It documents a
human-recruitment walkthrough of build surfaces shipped by P01 and P02. Those
surfaces already exist on disk (verify before authoring — Plan-Time Discipline
rule 1):

- `scripts/lifecycle/wiki-init.sh` exists (P01: emits `wiki-cloudflare.yml` when
  `wiki.deploy_target: cloudflare-access`; `--deploy cloudflare-access` invokes
  the provisioner).
- `scripts/wiki/cloudflare-access-setup.sh` exists (P02: idempotent provisioner —
  Pages project → Access app (apex+wildcard) → allow policy; `--project-dir DIR`
  parses `wiki.cloudflare.project_name` + `allowed_email_domains` from
  `<DIR>/.orchestrator/config.yml`).
- `templates/wiki-cloudflare-deploy.yml.tmpl` exists (P01: build steps identical
  to `pages.yml` + FR-3a pre-deploy Access health check + `npx --yes wrangler@4`
  deploy).

Confirm each with `[ -f <path> ]` before writing; FAIL this task if any is
missing.

## Description

Author the two human-facing documents that constitute the US-4 live /
friendly-tester pass, mirroring the M033 house convention
(`tests/m033-acceptance/friendly-tester-pass/protocol.md` +
`RECRUITMENT-KIT.md`):

1. **`tests/m043-acceptance/live-deploy/protocol.md`** — the authoritative
   recruitment + walkthrough script a recruited tester (or a maintainer with a
   real Cloudflare account) follows to provision and deploy a gated wiki
   end-to-end and capture the SC-9 evidence.
2. **`tests/m043-acceptance/live-deploy/RECRUITMENT-KIT.md`** — a one-page brief
   handed to the tester (eligibility checklist + the literal command sequence +
   what to capture).

These are **markdown-only** documents. They run no commands themselves; they
instruct a human. The mechanical gate is `validate-evidence.sh` (T02
deliverable), which the filled-out evidence note is fed to.

The protocol MUST capture the **five** live-validation items this milestone
forward-pointed:

- **The SC-9 triad** (spec FR-13 / SC-9):
  1. the live `https://<name>.pages.dev` URL redirects an unauthenticated request
     `302 → cloudflareaccess.com` (no content served);
  2. a green CI run of the emitted `wiki-cloudflare.yml` workflow;
  3. a working giscus comment on the deployed wiki (giscus is unchanged across
     targets per FR-12).
- **The two P00 forward-pointed API confirmations** (from
  `phases/P00/cloudflare-api-findings.md`, both currently `doc-derived` / Mode B):
  4. **#Q-5 (Edit-scope-grants-read)** — issue a real
     `GET /accounts/{id}/access/apps` with the **Edit-only (no Read scope)**
     `CLOUDFLARE_API_TOKEN` and confirm it returns `200` + the app list (not
     `403`). This confirms the AD-1 primary `authenticated-edit-token` FR-3a
     probe. If it returns `403`, the tester records the fallback
     (`unauthenticated-redirect-fallback`: assert `302 → cloudflareaccess.com`
     with a `Cache-Control: no-cache` / retry-window CDN mitigation) — no spec
     re-litigation, both are inside AD-1's sanctioned set.
  5. **#Q-6 (api-error-envelope)** — confirm the real Cloudflare error envelopes
     match the doc-derived fixtures: Zero-Trust-not-enabled (HTTP 400, code
     12130) vs. token-missing-scope (HTTP 403, code 9109). If real behavior
     differs, the tester records the divergence so P02's FR-9 discriminators (or
     the one-line collapse-to-combined contingency) can be reconciled.

## Steps

1. Create the directory `tests/m043-acceptance/live-deploy/` if it does not
   exist.

2. Write `tests/m043-acceptance/live-deploy/protocol.md` with these sections (use
   the M033 `protocol.md` as the structural model; adapt the content to the
   Cloudflare live deploy):

   - **Title + authoritative-reference comment** — an HTML comment naming the
     authoritative spec refs (`M043 spec FR-13 / US-4 / SC-9`), stating the doc
     is markdown-only (runs no commands), and that the filled evidence note is
     fed to `validate-evidence.sh`.

   - **## Purpose** — why a live pass matters: the build phases (P01/P02/P03)
     verified the Cloudflare path entirely against recorded-API fixtures (Mode B,
     doc-derived); only a real account confirms the live `302` gate, the green CI
     deploy, working giscus, and the two `[unconfirmed-P04]` API assumptions
     (#Q-5 Edit-scope-grants-read, #Q-6 error-envelope distinguishability).
     State that closing M043 at shippable scope (US-1..US-3) with this pass
     forward-pointed under a signed deferred-validation note is sanctioned house
     precedent (matches M032/M033/M036).

   - **## Tester Eligibility** — a tester is eligible iff they self-attest to all
     of: (a) has a real Cloudflare account they can enable Zero Trust on (or
     access to one); (b) has a private test repo (or can create one) where the
     orchestrator wiki can be initialized. Unlike M033 this pass is **not**
     about cold-start UX, so maintainers ARE eligible to run it (the gate is
     "did the live deploy actually gate", not "is the UX legible to an
     outsider"). State this distinction explicitly.

   - **## Pre-Conditions** — list what the tester provisions before the
     walkthrough: a Cloudflare account with **Zero Trust enabled** (a one-time
     dashboard step that cannot be API-triggered — cite FR-9 / the P00 #Q-6
     finding); a `CLOUDFLARE_API_TOKEN` with scopes **`Access: Apps and Policies
     — Edit` + `Pages — Edit` + `Account Settings — Read`** (NO extra Read
     scope — the FR-3a probe reuses the Edit token per P00 #Q-5-sub) and
     `CLOUDFLARE_ACCOUNT_ID`, both in the test repo's GitHub Actions secrets; a
     private GitHub repo with an orchestrator-managed wiki.

   - **## Walkthrough** — a literal, numbered step list. The tester runs these
     verbatim and records observations into the evidence note (T02's
     `evidence-template.md`). The steps (adapt exact flag spellings to the live
     `wiki-init.sh` / `cloudflare-access-setup.sh` help output — do not invent
     flags the scripts do not expose):
       1. In the test repo's `.orchestrator/config.yml`, set
          `wiki.deploy_target: cloudflare-access` and fill the
          `wiki.cloudflare:` sub-block (`project_name`, account-id source,
          `allowed_email_domains`).
       2. Run `bash scripts/wiki/cloudflare-access-setup.sh --project-dir <repo>`
          to provision Pages project → Access app (apex+wildcard) → allow policy.
          Expect an `OK:` success line; on a Zero-Trust-off account expect a
          non-zero exit with the FR-9 diagnostic (record the real HTTP status +
          error code for the #Q-6 confirmation).
       3. Re-run the same command and confirm it is a no-op (idempotent —
          zero creates; SC-4 live confirmation).
       4. Run `bash scripts/lifecycle/wiki-init.sh --deploy` (with
          `deploy_target: cloudflare-access` resolved) so the
          `wiki-cloudflare.yml` workflow is emitted and the first deploy is
          triggered; record the CI run URL printed by `wiki-deploy.sh`.
       5. Wait for the CI run to go green (the FR-3a pre-deploy Access health
          check must pass, then `npx --yes wrangler@4 pages deploy` runs).
       6. **Capture #1 (302 gate)**: `curl -sI https://<name>.pages.dev` from an
          unauthenticated client and confirm `302` with a `location:` header
          pointing at `*.cloudflareaccess.com`. Record the exact status line and
          location header.
       7. **Capture #2 (green CI)**: record the green workflow-run URL.
       8. **Capture #3 (giscus)**: log in as an allowed-domain user, open a wiki
          page, and post a giscus comment; confirm it persists.
       9. **Capture #4 (#Q-5)**: with the Edit-only token, run a real
          `GET /accounts/{id}/access/apps` (e.g. via `curl` with the
          `Authorization: Bearer` header) and record whether it returns `200` +
          app list or `403`.
      10. **Capture #5 (#Q-6)**: record the real HTTP status + error code body
          field for a Zero-Trust-off attempt and (if reproducible) a
          missing-scope attempt, to confirm or correct the doc-derived
          400/12130 vs 403/9109 discriminators.

   - **## What to capture** — point the tester at the evidence note
     (`evidence-template.md`, a T02 deliverable copied to
     `evidence/<DATE>.md`), enumerate the frontmatter fields they fill
     (`redirect_verified`, `ci_green`, `giscus_working`,
     `edit_scope_grants_read`, `error_envelopes_match`), and note that if the
     live pass cannot be completed the maintainer files a **signed
     deferred-validation note** instead (`deferred_validation: yes` +
     `signed_by:`), which is the sanctioned SC-9 "or" closing path.

   - **## Reporting** — the filled evidence note goes to
     `tests/m043-acceptance/live-deploy/evidence/<DATE>.md`; the mechanical gate
     is `bash tests/m043-acceptance/live-deploy/validate-evidence.sh
     <evidence-path>` which exits 0 iff EITHER the SC-9 triad is all-yes OR a
     signed deferred-validation note is present. A missing note prints
     `live-deploy validation not run — milestone close blocked` and exits 1.

   The protocol MUST literally contain the strings `cloudflareaccess.com`,
   `cloudflare-access-setup.sh`, `wiki-init.sh`, `#Q-5`, `#Q-6`, `302`,
   `giscus`, and `green CI` (the T03 `m043-p04-protocol-anchors.sh` verifier
   grep-asserts these anchors).

3. Write `tests/m043-acceptance/live-deploy/RECRUITMENT-KIT.md` — a one-page
   brief modeled on the M033 kit:
   - A short "thanks for helping" intro framing this as a ~30-minute live
     Cloudflare deploy validation.
   - An "Are you eligible?" checklist (has a Cloudflare account / can enable Zero
     Trust / has a private test repo).
   - "What you'll do" — the condensed command sequence (the same steps as the
     protocol walkthrough, abbreviated).
   - "What to capture" — the five capture items in plain language.
   - "How to file your report" — copy `evidence-template.md` to
     `evidence/<today>.md`, fill the frontmatter, run `validate-evidence.sh`.
   The kit MUST literally contain the string `Cloudflare`.

## Must-Haves

This task addresses the phase must-haves for the protocol + kit artifacts and the
two `protocol.md` Key Links:

- `tests/m043-acceptance/live-deploy/protocol.md` (min 90 lines, contains
  "cloudflareaccess.com")
- `tests/m043-acceptance/live-deploy/RECRUITMENT-KIT.md` (min 40 lines, contains
  "Cloudflare")
- Key Link: `protocol.md` → `scripts/wiki/cloudflare-access-setup.sh`
- Key Link: `protocol.md` → `scripts/lifecycle/wiki-init.sh`

## Verification

```bash
test -f tests/m043-acceptance/live-deploy/protocol.md
test -f tests/m043-acceptance/live-deploy/RECRUITMENT-KIT.md
grep -q "cloudflareaccess.com" tests/m043-acceptance/live-deploy/protocol.md
grep -q "cloudflare-access-setup.sh" tests/m043-acceptance/live-deploy/protocol.md
grep -q "wiki-init.sh" tests/m043-acceptance/live-deploy/protocol.md
grep -q "#Q-5" tests/m043-acceptance/live-deploy/protocol.md
grep -q "#Q-6" tests/m043-acceptance/live-deploy/protocol.md
grep -q "giscus" tests/m043-acceptance/live-deploy/protocol.md
grep -q "Cloudflare" tests/m043-acceptance/live-deploy/RECRUITMENT-KIT.md
```

## Inputs

### From Previous Tasks

None — T01 has no upstream task dependency inside P04.

### From Disk (Pre-existing)

- `tests/m033-acceptance/friendly-tester-pass/protocol.md` — the structural model
  to mirror (purpose / eligibility / pre-conditions / walkthrough / reporting).
- `tests/m033-acceptance/friendly-tester-pass/RECRUITMENT-KIT.md` — the
  one-page-brief model to mirror.
- `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` — the
  authoritative source for the #Q-5 probe decision (`authenticated-edit-token`,
  reuse Edit token, 403→redirect-fallback) and the #Q-6 error envelopes
  (400/12130 zero-trust-off vs 403/9109 missing-scope). Read the "FR-3a Probe
  Decision" and "#Q-6" sections before authoring the capture steps.
- `scripts/wiki/cloudflare-access-setup.sh` — read its `--help` / option parsing
  to use the real flag spellings (`--project-dir`) in the walkthrough.
- `scripts/lifecycle/wiki-init.sh` — read its `--deploy` branch to use the real
  invocation in the walkthrough.

## Constraints

- **Markdown-only.** These documents must not execute anything; they instruct a
  human. No embedded scripts beyond fenced illustrative command blocks.
- **No invented flags.** Use only flags the live `wiki-init.sh` /
  `cloudflare-access-setup.sh` actually expose (read the scripts; do not
  confabulate). Where the exact flag is uncertain, describe the action and
  reference the script's `--help`.
- **Evidence-grounded #Q-5/#Q-6 values.** The HTTP statuses + error codes
  (200/403, 400/12130, 403/9109) come verbatim from
  `phases/P00/cloudflare-api-findings.md` — do not alter them; the live pass
  exists to confirm or correct them.

## Expected Output

Two markdown files on disk:
`tests/m043-acceptance/live-deploy/protocol.md` (≥90 lines) and
`tests/m043-acceptance/live-deploy/RECRUITMENT-KIT.md` (≥40 lines). All nine
`## Verification` commands exit 0.

## Notes

Expected verifier output: each `## Verification` line exits 0 silently (the
`grep -q` / `test -f` forms print nothing on success). The phase-level
`bash tools/verify/m043-p04-protocol-anchors.sh` (a T03 deliverable, not run in
this task) will later re-assert these anchors plus `302` and `green CI` as the
mechanical Truth check.
