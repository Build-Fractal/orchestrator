---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P00"
milestone: "M043"
name: "Conduct the Cloudflare API characterization spike + author the findings note + capture fixture seeds"
depends_on: []
---

## Prerequisites

None on disk (P00 is dependency-free; consumes nothing from upstream phases).

**External prerequisite — Cloudflare credentials (pick a mode before starting).** This task is a spike against the live Cloudflare API. Two sanctioned execution modes; you MUST pick one and record it verbatim in the findings note's `## Evidence Provenance` section:

- **Mode A — live (preferred).** A Cloudflare account id + scoped API token are available in the environment (`CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`; token scopes `Access: Apps and Policies — Edit`, `Pages — Edit`, `Account Settings — Read`). You make real API calls and tag findings `live-confirmed`.
- **Mode B — doc-derived fallback (sanctioned, provisional).** No live credentials. You characterize the API from Cloudflare's published documentation via WebFetch, commit the Decisions on the documented evidence, tag findings `doc-derived`, build the fixture seeds from the documented schemas (labeled synthetic-from-docs), and attach a `P04` live-confirmation forward-pointer to every `doc-derived` finding.

Either mode yields a closeable phase. If neither credentials nor network/doc access is available, STOP and report the blocker — do not fabricate findings.

## Description

M043 adds Cloudflare Pages + Access as a wiki-deploy target. Two external-API unknowns block the downstream build phases and were deliberately deferred to this spike (they passed the discuss-stage corpus-exhaustion gate as `kept` because they are answerable only from external Cloudflare reality, not the orchestrator corpus):

1. **#Q-5-sub (Edit-scope-grants-read)** — The FR-3a pre-deploy health check (the load-bearing CON-6 second enforcement site) must confirm, before every CI `wrangler pages deploy`, that the Access app + allow policy for `<name>.pages.dev` still exist. AD-1 (`M043-CONTEXT.md`) chose to *reuse the existing `Access: Apps and Policies — Edit` token* for this — **but only if Edit grants enough read access to query app/policy existence.** Your job: determine whether it does.
   - If **yes** → FR-3a probe Decision = `authenticated-edit-token` (an authenticated GET against the Access apps/policies list endpoint, filtered to `<name>.pages.dev`, using the already-present Edit-scope token). No new operator token scope.
   - If **no** → fall back to the AD-1 fallback: FR-3a probe Decision = `unauthenticated-redirect-fallback` (assert `302 → cloudflareaccess.com` on `https://<name>.pages.dev` with a `Cache-Control: no-cache` / retry-window mitigation for the CDN edge-cache false-positive). The `authenticated-new-read-scope` option (add a dedicated `Access: Apps and Policies — Read` scope) is the spec's #Q-5 option (a) and is recorded as the rejected third option (AD-1 rejected it for operator-provisioning friction + 403-on-every-CI-run risk) — but if you discover Edit does NOT grant read AND the redirect probe is unworkable, you may surface it as a re-litigation flag rather than silently choosing it.

2. **#Q-6 (api-error-envelope)** — FR-9 requires the provisioner to emit an *actionable* diagnostic distinguishing "Cloudflare Zero Trust not enabled on this account" (a one-time dashboard step that cannot be API-triggered) from "token is missing a required scope." Per Principle II the spec must not assert these are distinguishable without evidence. Your job: characterize the two API error envelopes (HTTP status, top-level error `code`, error `message`/body field) and decide:
   - If **mechanically distinguishable** → FR-9 Decision = `distinguishable` (two diagnostics; SC-5 stands as written — two-fixture assertion).
   - If **NOT mechanically distinguishable** → FR-9 Decision = `indistinguishable` (one combined diagnostic naming both conditions; record an SC-5-revision note so P02 builds the single-combined-diagnostic shape and the milestone's SC-5 is satisfied by it).

You also capture the request/response payloads that seed P02's recorded-API fixtures (P02 promotes them into `tests/fixtures/m043-cloudflare/`; P00 owns only the raw seeds under the P00 dir).

This task produces the findings note + the seed payloads. T02 authors the structural verifiers that gate the note's shape.

## Steps

1. **Pick and record the execution mode.** Confirm whether `CLOUDFLARE_ACCOUNT_ID` + `CLOUDFLARE_API_TOKEN` are set (Mode A) or not (Mode B). You will record the chosen mode in the findings note `## Evidence Provenance` section in step 7.

2. **Create the seed directory.** Ensure `.orchestrator/milestones/M043/phases/P00/fixture-seeds/` exists (the Write tool will create it on first file write; no `mkdir` needed).

3. **Characterize #Q-5-sub (Edit-scope-grants-read).**
   - **Mode A:** Using the Edit-scope token, issue a read (GET/list) against the Cloudflare Access applications endpoint for the account (`GET /accounts/{account_id}/access/apps`) and an Access policies read. Observe whether the Edit-scope token returns the resource list (200 + body) or a 403/authz error. Capture the HTTP status + a representative body.
   - **Mode B:** WebFetch the Cloudflare API token-permissions documentation and the Access apps/policies API reference. Determine from Cloudflare's documented permission model whether the `Access: Apps and Policies — Edit` permission group includes read access to the apps/policies list endpoints (Cloudflare's model generally makes Edit a superset of Read; confirm this is documented for this specific permission group, do not assume).
   - **Commit the FR-3a probe Decision** (one of the three closed-set values) with a one-paragraph justification and the provenance tag.

4. **Characterize #Q-6 (api-error-envelope).**
   - **Mode A:** Reproduce both error conditions and capture the raw response envelopes:
     - *Zero-Trust-not-enabled:* attempt the Access-app create (`POST /accounts/{account_id}/access/apps`) on an account where Zero Trust has not been enabled, OR on the live account capture the specific error Cloudflare returns when the Access product is not provisioned. Record HTTP status + body (`success`, `errors[].code`, `errors[].message`).
     - *Missing-scope:* issue an Access-app create (or read) with a token deliberately lacking the `Access: Apps and Policies — Edit` scope (e.g. a Pages-only token). Record HTTP status + body.
   - **Mode B:** WebFetch the Cloudflare Access API error reference + Zero-Trust provisioning docs + token-scope (authorization-error) docs. Reconstruct the two documented error envelopes as faithfully as the docs allow; mark any field you could not confirm from docs as `[unconfirmed — P04]`.
   - **Decide distinguishability** by comparing the two envelopes field-by-field (status, `code`, `message` shape). **Commit the FR-9 Decision** (`distinguishable` or `indistinguishable`) with the comparison evidence and provenance tag. If `indistinguishable`, write the SC-5-revision note.

5. **Capture the fixture seeds.** Write each as a small JSON file under `fixture-seeds/`. In Mode A these are the real captured payloads; in Mode B they are documented-schema reconstructions clearly labeled synthetic-from-docs in the README.
   - `pages-project-create-request.json` — the `POST /accounts/{account_id}/pages/projects` request body for project `<name>` (use a placeholder `<name>` / `<account_id>`; do NOT bake a real account id or token into any seed).
   - `access-app-create-request.json` — the `POST /accounts/{account_id}/access/apps` request body for a self-hosted app whose `self_hosted_domains` array contains BOTH the apex `<name>.pages.dev` and the wildcard `*.<name>.pages.dev`. (This is the SC-3 apex+wildcard assertion's seed.)
   - `access-policy-create-request.json` — the allow-policy create body keyed on `<allowed_email_domains>` (decision `allow`, an `include` rule matching the email domain(s)).
   - `zero-trust-not-enabled-response.json` — the captured/documented error envelope for the Zero-Trust-not-enabled condition (HTTP status as a top-level field, plus the Cloudflare `{success, errors, messages, result}` body).
   - `missing-scope-response.json` — the captured/documented error envelope for the missing-scope condition.
   - **Scrub secrets:** every seed uses placeholder tokens / account ids (`<account_id>`, `<name>`, `<allowed_email_domains>`). No real credential or account identifier may appear in any committed seed (these land in git history).

6. **Write the seed README.** `fixture-seeds/README.md` documents, per seed file: its source endpoint, its provenance (`live-confirmed` vs `doc-derived`), and the note that **P02 promotes these seeds into `tests/fixtures/m043-cloudflare/`** as the recorded-API fixtures for SC-3/SC-4/SC-5/SC-10. State the placeholder convention (`<account_id>`/`<name>`).

7. **Author the findings note** at `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` with this section structure (the headings are load-bearing — T02's verifier greps for them; keep them verbatim):

   ```markdown
   ---
   schema_version: "1.0"
   type: spike-findings
   milestone: "M043"
   phase: "P00"
   created_at: "<iso-date>"
   execution_mode: "live | doc-derived"
   ---

   # M043 P00 — Cloudflare API Characterization Findings

   ## #Q-5-sub — Does Access "Apps and Policies — Edit" grant read access?

   <evidence: the GET result (Mode A) or the documented permission-model statement (Mode B)>

   ### FR-3a Probe Decision

   - Decision: `authenticated-edit-token` | `authenticated-new-read-scope` | `unauthenticated-redirect-fallback`
   - Provenance: `live-confirmed` | `doc-derived`
   - <one-paragraph justification; if doc-derived, a P04 live-confirmation forward-pointer>
   - Token-scope implication for FR-11 docs + the Assumptions table: <what scopes the operator must provision>

   ## #Q-6 — Zero-Trust-not-enabled vs. token-missing-scope error envelope

   <the two captured/documented envelopes, side by side: HTTP status, errors[].code, errors[].message>

   ### FR-9 Diagnostic Decision

   - Decision: `distinguishable` | `indistinguishable`
   - Provenance: `live-confirmed` | `doc-derived`
   - <comparison evidence>
   - <if indistinguishable: the SC-5-revision note — "P02 emits one combined diagnostic; SC-5 satisfied by the combined-diagnostic shape">
   - <if doc-derived: a P04 live-confirmation forward-pointer>

   ## Fixture-Seed Inventory

   <table mapping each fixture-seeds/*.json file → its source endpoint → its provenance; note P02 promotes them to tests/fixtures/m043-cloudflare/>

   ## Evidence Provenance

   - Execution mode: <Mode A live | Mode B doc-derived>
   - <per-finding live-confirmed/doc-derived summary; every doc-derived finding names its P04 forward-pointer>
   ```

   Replace `<iso-date>` with today's date as a literal string (do not call a date function inside any verifier; the date is authored prose here).

8. **Self-verify** with the inline checks in `## Verification` below.

## Must-Haves

This task addresses the phase must-haves:
- Findings note resolves #Q-5-sub with an FR-3a probe Decision (closed-set) + provenance.
- Findings note resolves #Q-6 with an FR-9 Decision (distinguishable/indistinguishable) + provenance.
- Per-finding provenance recorded; doc-derived findings forward-point to P04.
- Apex+wildcard create payload + Zero-Trust-not-enabled + missing-scope responses captured as seeds.

(The phase-suite Truth is addressed by T02.)

## Verification

<!-- Single-command shape-checks only — no compound chains, no $(...)-with-pipe,
     no subshells. These are stub-tolerant inline checks (plan-time discipline
     rule 2): T01 does NOT depend on T02's not-yet-written verifiers. -->

`test -f .orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md`

`grep -q "FR-3a Probe Decision" .orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md`

`grep -Eq "authenticated-edit-token|authenticated-new-read-scope|unauthenticated-redirect-fallback" .orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md`

`grep -q "FR-9 Diagnostic Decision" .orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md`

`grep -Eq "distinguishable|indistinguishable" .orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md`

`grep -q "Evidence Provenance" .orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md`

`test -f .orchestrator/milestones/M043/phases/P00/fixture-seeds/access-app-create-request.json`

`grep -q "self_hosted_domains" .orchestrator/milestones/M043/phases/P00/fixture-seeds/access-app-create-request.json`

`test -f .orchestrator/milestones/M043/phases/P00/fixture-seeds/zero-trust-not-enabled-response.json`

`test -f .orchestrator/milestones/M043/phases/P00/fixture-seeds/missing-scope-response.json`

`test -f .orchestrator/milestones/M043/phases/P00/fixture-seeds/README.md`

## Inputs

### From Previous Tasks

None (T01 is the head of the phase).

### From Disk (Pre-existing)

- `specs/043-wiki-cloudflare-access-deploy-target/spec.md` — the binding `#Q-5` (line ~181) and `#Q-6` (line ~182) open questions, FR-3a (line ~110), FR-9 (line ~116), SC-5 (line ~128), and the Assumptions token-scope table (line ~163) you must keep consistent with your Decision.
- `.orchestrator/milestones/M043/M043-CONTEXT.md` — AD-1 (the probe decision tree + the rejected new-scope option) and AD-4 (sequencing). Your Decision must land inside AD-1's sanctioned option set.
- `.orchestrator/milestones/M043/M043-HANDOFF.md` — the resumer briefing, including the credentials gotcha (#1) and the corpus-gate `kept` rationale.

## Constraints

- **No secrets in seeds.** Every fixture seed uses placeholders (`<account_id>`, `<name>`, `<allowed_email_domains>`); no real Cloudflare account id or token may be committed (the seeds land in git history).
- **Principle II — no claim beyond its evidence.** Tag every finding `live-confirmed` or `doc-derived`; attach a P04 forward-pointer to every `doc-derived` finding. Do not assert the two error envelopes are distinguishable without the side-by-side evidence.
- **Stay inside AD-1.** The FR-3a Decision must be one of AD-1's sanctioned values; if your evidence forces the rejected `authenticated-new-read-scope` option, surface it as an explicit re-litigation flag in the findings note rather than silently adopting it.
- **Bash shape-guard (AP-009/AP-008).** Run any probe commands as single commands; do not chain `&&`/`;` > 2 or use inline-HEREDOC-with-expansion. Author the findings note + seeds with the Write tool, not shell heredocs.
- **Do not modify the spec.** Your job is to record the Decision in the findings note; the spec's SC-5 revision (if `indistinguishable`) is consumed by P02, not applied to the spec here.

## Expected Output

A `cloudflare-api-findings.md` with both Decisions committed and provenance-tagged, plus six files under `fixture-seeds/` (five JSON seeds + README). The inline `## Verification` checks all exit 0. (Expected verifier output for the T02 phase-suite — `SUMMARY: m043-p00-phase-suite.sh pass=2 fail=0` — is documented in T02's plan, not asserted here.)
