---
schema_version: "1.0"
type: feature-spec
feature_slug: "043-wiki-cloudflare-access-deploy-target"
created_at: "2026-06-04"
status: "Draft"
milestone: "M043"
---

# Feature Specification: 043-wiki-cloudflare-access-deploy-target

**Feature Branch**: `043-wiki-cloudflare-access-deploy-target`
**Created**: 2026-06-04
**Status**: Draft
**Last Revised**: 2026-06-04 (Standard advisory conversus gate PASS, 0 surviving disputes; 5 P0 synthesis amendments applied — FR-3a pre-deploy health check, CON-6 two-site rewrite, SC-6 conditional, FR-1 cross-ref + CON-7 domain-list caveat, #Q-5/#Q-6 probe/error-envelope)
**Milestone**: M043
**Input**: User description: "Add Cloudflare Pages + Cloudflare Access as a first-class wiki-deploy target (recommended for private wikis), alongside the existing GitHub Pages path. Introduces a wiki.deploy_target: github-pages | cloudflare-access config switch consumed by wiki-init.sh and wiki-deploy.sh; a wiki-cloudflare-deploy.yml workflow template that deploys via npx wrangler (not cloudflare/wrangler-action); an idempotent cloudflare-access-setup.sh that provisions a Pages project + Access self-hosted app/policy (apex+wildcard, before-deploy ordering); installation.md docs for the Enterprise-only-private-Pages footgun and the lapsed-entitlement build-green/deploy-422 failure mode; and an orchestrator:status/doctor warning when deploy_target is github-pages on a private repo on a non-Enterprise plan."

## Problem Statement

The orchestrator wiki ships an mkdocs site whose only deploy target is GitHub Pages, hardwired across three surfaces: `scripts/lifecycle/wiki-init.sh` (the `emit_pages_workflow` FR-19 scaffold plus the four-step `--deploy` GitHub-Pages config sequence), `scripts/wiki/wiki-deploy.sh` (gate chain → `git push` → `pages.yml`), and `.github/workflows/pages.yml` (`actions/deploy-pages@v4`). That single target carries a confidentiality-and-availability footgun that bit a live downstream project (`pbj-central-mono-repo`, validated 2026-06-04): a *private*, access-controlled GitHub Pages site is a GitHub Enterprise Cloud–only feature, so on Free/Pro/Team the same wiki that surfaces confidential `.orchestrator/` content (spec, decisions, GTM, SME discussions, milestones) is published with no access control.

Three concrete pain-points follow from this gap. First, **silent exposure**: a team that enables Pages on a private repo without realizing the published site is world-readable leaks the entire `.orchestrator/` corpus to anyone with the URL. Second, **silent deploy failure**: when an org's Enterprise entitlement lapses (a trial reverting to Team is the observed case), `actions/deploy-pages` begins returning HTTP 422 on every push (`"Page is disabled because current plan does not support private GitHub Pages"`) while the *build* job stays green — the run list looks healthy, the live wiki silently freezes for days, and the root cause reads as a content/config issue when it is actually a plan entitlement. Third, **no plan-independent path**: an operator who simply wants a gated private wiki has no orchestrator-supported option short of buying Enterprise Cloud.

The minimum surface that fixes all three is a second, plan-independent deploy target — Cloudflare Pages fronted by Cloudflare Access — selected by a `wiki.deploy_target` config switch, plus a structural warning that fires on the dangerous configuration tuple so the silent failure modes become loud. Cloudflare Pages + Access is free, gives a stable private URL gated by SSO / one-time-PIN, is independent of the GitHub plan and repo visibility, and — critically — leaves the entire mkdocs build pipeline (stub-freshness check, `wiki/.staged/` materialization, `mkdocs build`) unchanged; only the deploy step differs.

This feature explicitly does not attempt a migration tool, a general multi-cloud deploy abstraction, an IdP integration beyond Cloudflare's built-in one-time-PIN, or a secrets-management system. It adds exactly one new target alongside the existing one, a setup script to provision it safely, the documentation that records the footgun, and the warning that defends against it.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

The smallest coherent subset that closes the dogfood loop is **User Story 1 (target switch + Cloudflare deploy workflow)** plus **User Story 2 (idempotent provisioner)**. Together they let an operator set `wiki.deploy_target: cloudflare-access`, run `wiki-init.sh --deploy`, and reach a gated live wiki without hand-rolling any Cloudflare API calls — the exact thing `pbj-central` had to do by hand. User Story 3 (docs + safety warning) and User Story 4 (live-deploy/friendly-tester pass) are defended on top of this slice: the warning hardens the *default* (github-pages) path against the footgun, and the live pass proves the provisioned target end-to-end. The github-pages path must remain byte-identical to its pre-M043 behavior throughout, so existing wikis are never silently altered.

### User Story 1 — Operator selects the Cloudflare target and gets the right workflow (Priority: P1)

An operator with a private-repo wiki sets `wiki.deploy_target: cloudflare-access` in `.orchestrator/config.yml` and runs `orchestrator:wiki-init --deploy`. The orchestrator emits a Cloudflare deploy workflow (`wiki-cloudflare.yml`) instead of `pages.yml`, skips the GitHub-Pages repo-config steps, and the existing mkdocs build pipeline carries over unchanged. The operator gets a plan-independent gated deploy with the same local pre-deploy gates they already trust.

**Why this priority**: Without the target switch and a working Cloudflare workflow there is no new capability at all — every other story decorates or validates this one. It is also the part that directly replaces the manual workflow `pbj-central` hand-authored.

**Independent Test**: In a fixture repo with `wiki.deploy_target: cloudflare-access`, run `wiki-init.sh` against a stub git remote and assert the emitted workflow is the Cloudflare template (deploy via `npx --yes wrangler@4`, no `cloudflare/wrangler-action`) and that `pages.yml` is not emitted. Flip the value to `github-pages` and assert the output is byte-identical to the pre-M043 behavior.

**Acceptance Scenarios**:

1. **Given** a project with `wiki.deploy_target: cloudflare-access`, **When** `wiki-init.sh` runs its workflow-emit step, **Then** `.github/workflows/wiki-cloudflare.yml` is written, `pages.yml` is not, and the GitHub-Pages `--deploy` config steps are skipped.
2. **Given** a project with `wiki.deploy_target: github-pages` (or the key absent), **When** `wiki-init.sh` runs, **Then** the emitted workflow and `--deploy` behavior are byte-identical to the pre-M043 baseline.
3. **Given** an emitted `wiki-cloudflare.yml`, **When** a template lint inspects it, **Then** the deploy step uses `npx --yes wrangler@4 pages deploy` and contains no reference to `cloudflare/wrangler-action`.
4. **Given** `wiki.deploy_target: cloudflare-access`, **When** `wiki-deploy.sh` finishes its local gates, **Then** it prints the Cloudflare workflow URL (not the `pages.yml` URL) and states the gates are identical across targets.

### User Story 2 — Operator provisions Cloudflare resources idempotently and safely (Priority: P1)

An operator runs `cloudflare-access-setup.sh` with an API token, account id, project name, and allowed email domains. The script creates the Pages project, then the Access self-hosted app (covering apex `<name>.pages.dev` and wildcard `*.<name>.pages.dev`), then the allow policy — in that order, so the content is gated before any deploy can expose it. Re-running the script makes no duplicate resources. If Cloudflare Zero Trust has not been enabled on the account (a one-time dashboard step that cannot be API-triggered), the script fails with an actionable diagnostic rather than a raw API error.

**Why this priority**: Provisioning is the other half of the minimal slice — the workflow from US-1 cannot deploy to a project that does not exist, and the access-before-deploy ordering is the invariant that prevents an exposure window. Hand-rolling these API calls is exactly the friction this milestone removes.

**Independent Test**: Run the script against a stubbed Cloudflare API (recorded fixture) and assert (a) create-order is Pages-project → Access-app → policy; (b) the Access app's `self_hosted_domains` includes both apex and wildcard; (c) a second run issues no create calls for already-present resources; (d) a simulated "Zero Trust not enabled" API response yields the actionable diagnostic and a non-zero exit.

**Acceptance Scenarios**:

1. **Given** a token + account id + project name + one or more email domains, **When** `cloudflare-access-setup.sh` runs against a clean account, **Then** it creates the Pages project, the Access app (apex + wildcard), and an allow policy keyed on the supplied email domains, in that order.
2. **Given** an account where all three resources already exist, **When** the script runs again, **Then** it performs zero create mutations and exits 0 (idempotent).
3. **Given** an account without Zero Trust enabled, **When** the script attempts the Access-app create, **Then** it emits a diagnostic naming the one-time dashboard enablement step and exits non-zero before any deploy is possible.
4. **Given** a freshly created Pages project with the Access app/policy in place but no deployment yet, **When** the live URL is requested unauthenticated, **Then** the request is redirected to the Cloudflare Access login (no content is served).

### User Story 3 — Operator is warned about the GitHub-Pages footgun (Priority: P2)

An operator on the default `github-pages` target with a private repo on a non-Enterprise plan runs `orchestrator:status` (or `orchestrator:doctor`) and sees a warning that their published site is either public or will 422, with a pointer to the Cloudflare target and the installation docs. The `references/installation.md` doc states the Enterprise-only-private-Pages pitfall and the lapsed-entitlement (build-green / deploy-422) failure mode plainly.

**Why this priority**: The warning is the structural defense that turns both silent failure modes loud, but it depends on the alternative target existing to point at — so it ranks below the slice that creates that target. It is still load-bearing for the milestone's safety goal.

**Independent Test**: Drive the warning logic with a fixture matrix of (repo visibility × deploy_target × plan) and assert it fires on exactly the (private, github-pages, non-Enterprise) tuple and stays silent on every other combination.

**Acceptance Scenarios**:

1. **Given** a private repo with `deploy_target: github-pages` on a non-Enterprise plan, **When** `orchestrator:status` (or `doctor`) runs, **Then** a warning fires naming the public-exposure and 422-freeze risks and pointing to the Cloudflare target.
2. **Given** any of: a public repo, `deploy_target: cloudflare-access`, or an Enterprise plan, **When** `status`/`doctor` runs, **Then** the warning does not fire.
3. **Given** `references/installation.md` after this milestone, **When** an operator reads the wiki-deploy section, **Then** it documents the Enterprise-only-private-Pages pitfall, the lapsed-entitlement failure mode, the Cloudflare recipe, the required token scopes, and the Zero Trust prerequisite.

### User Story 4 — Maintainer validates the Cloudflare target end-to-end (Priority: P3)

A maintainer (or recruited tester) provisions a real Cloudflare account against a fresh project: enables Zero Trust, runs the setup script, performs a first deploy through the workflow, and verifies the live URL redirects unauthenticated requests to Cloudflare Access and that giscus comments still function. This mirrors the M033 / M041 friendly-tester convention and is a human-recruitment task, not an autonomous one.

**Why this priority**: End-to-end live validation is high-value confirmation but not a code deliverable; the milestone can close at shippable scope (US-1..US-3) with this pass forward-pointed, matching house precedent for friendly-tester passes.

**Independent Test**: A documented protocol the human tester executes; the artifact is a signed evidence note recording the verified `302 → cloudflareaccess.com` redirect on the live URL, a green CI run, and a working giscus comment.

**Acceptance Scenarios**:

1. **Given** a real Cloudflare account with Zero Trust enabled, **When** the tester runs the setup script then triggers the workflow, **Then** the live `<name>.pages.dev` URL redirects unauthenticated requests to Cloudflare Access and serves content to an allowed-domain user after login.
2. **Given** the deployed Cloudflare-hosted wiki, **When** an allowed-domain repo-collaborator opens a page, **Then** giscus loads and a comment posts to the repo's Discussions with no change to `overrides/partials/comments.html`.

---

## Edge Cases

- **Operator authored a workflow already.** If `.github/workflows/wiki-cloudflare.yml` (or `pages.yml`) is already present, `wiki-init.sh` preserves it (CON-3 no-clobber) and emits a reconciliation diagnostic rather than overwriting — same convention as the existing `emit_pages_workflow`.
- **`deploy_target` set to an unknown value.** An unrecognized enum value fails fast with a clear error listing the two valid values, rather than silently falling through to github-pages.
- **Partial provisioning interrupted.** If a prior run created the Pages project but not the Access app (e.g. it crashed at the Zero-Trust check), the next run detects the existing project, does not duplicate it, and proceeds to create the still-missing Access app/policy before any deploy — the access-before-deploy invariant holds across interrupted runs.
- **Token missing required scopes.** A token lacking Pages-Edit or Access-Apps-and-Policies-Edit yields a scope-specific diagnostic naming the missing permission, not a raw 403.
- **giscus viewer authenticated via Access but not a GitHub collaborator.** Such a viewer can read but cannot comment; this is documented as expected behavior, not a bug.
- **Plan detection unavailable.** If "is this org Enterprise?" cannot be determined reliably via `gh api`, the warning falls back to firing on (private repo + github-pages) regardless of plan, with an "ignore if you are on Enterprise Cloud" note — cheap and never wrong in the dangerous direction (#Q-3).

---

## Functional Requirements

- **FR-1 (deploy-target-config)**: `templates/orchestrator-config-default.yml` gains `wiki.deploy_target` (enum `github-pages | cloudflare-access`, default `github-pages`) plus a commented `wiki.cloudflare:` sub-block declaring `project_name`, the account-id source, and `allowed_email_domains`. Scalar operator-authored values under `wiki:` are preserved across `orchestrator:update` by the existing M037 `wiki:`-namespace config-merge primitive. **Caveat (gate MIT-5):** that merge primitive has a known list-element preservation gap (recorded in CLAUDE.md as the round-5 deferred post-launch follow-up); `allowed_email_domains` is a list, so until that gap closes, domain-list edits must be re-applied via `cloudflare-access-setup.sh` (see CON-7) rather than relied upon to survive a merge — silently emptying this field would lock all authorized users out of the wiki. (US-1)
- **FR-2 (workflow-emit-branch)**: `wiki-init.sh`'s workflow-emit step branches on `deploy_target` — `cloudflare-access` emits `.github/workflows/wiki-cloudflare.yml` from the new template; `github-pages` emits `pages.yml` exactly as before. CON-3 no-clobber is preserved for both. (US-1)
- **FR-3 (cloudflare-workflow-template)**: A new `templates/wiki-cloudflare-deploy.yml.tmpl` carries build steps identical to `pages.yml` (checkout, setup-python, pip install, stub-freshness check, `wiki/.staged/` materialization, `mkdocs build`) and deploys via `npx --yes wrangler@4 pages deploy wiki/site --project-name=<name> --branch=main --commit-dirty=true` with `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` from repo secrets. It must not reference `cloudflare/wrangler-action`. (US-1)
- **FR-3a (pre-deploy-access-health-check)** *(gate MIT-1 / RISK-2 — the load-bearing safety amendment)*: The emitted `wiki-cloudflare.yml` MUST include a step that runs **before** the `npx wrangler pages deploy` step and verifies the Cloudflare Access app and allow policy for `<name>.pages.dev` are present and active. On failure it exits non-zero with an actionable diagnostic naming the condition (Access app absent, policy absent, or entitlement lapsed) and the deploy does not run. This closes the steady-state exposure window: a post-provisioning Zero Trust lapse / Access-app deletion / policy misconfiguration must fail the deploy loudly rather than ship an ungated wiki on a green run (the `pbj-central` failure shape, applied to the Cloudflare path). The probe mechanism (authenticated API call vs. unauthenticated `302 → cloudflareaccess.com` redirect check) is resolved per #Q-5 before FR-3a is implementable. (US-1, US-2)
- **FR-4 (deploy-config-branch)**: `wiki-init.sh --deploy` branches on `deploy_target` — `cloudflare-access` invokes `cloudflare-access-setup.sh` in place of the four-step GitHub-Pages config sequence; `github-pages` runs the existing sequence unchanged. (US-1, US-2)
- **FR-5 (deploy-wrapper-target-aware)**: `scripts/wiki/wiki-deploy.sh` resolves `deploy_target` and prints the target-appropriate workflow URL in its post-gate report; the four pre-deploy gates run identically for both targets. (US-1)
- **FR-6 (access-setup-provisioner)**: A new `scripts/wiki/cloudflare-access-setup.sh` provisions, in order, a Pages project, an Access self-hosted app (`self_hosted_domains` covering apex `<name>.pages.dev` and wildcard `*.<name>.pages.dev`), and an allow policy keyed on the supplied email domains. It reads token + account id + project name + domains from flags and/or environment. Bash 3.2 compliant. (US-2)
- **FR-7 (provisioner-idempotent)**: Re-running `cloudflare-access-setup.sh` against an account with any subset of the three resources already present issues no duplicate-create mutations and exits 0. (US-2)
- **FR-8 (access-before-deploy-ordering)**: `cloudflare-access-setup.sh` creates and confirms the Access app + allow policy before any deployment is possible; the ordering invariant holds across interrupted/partial prior runs. (US-2)
- **FR-9 (zero-trust-prereq-diagnostic)**: When the account lacks Zero Trust enablement, the provisioner emits a diagnostic naming the one-time dashboard step and exits non-zero before exposing content; a token missing a required scope yields a scope-specific diagnostic. **Conditional (gate THREAT-2):** if the Cloudflare API returns mechanically indistinguishable responses for the two conditions (no-entitlement vs. wrong-scope), the provisioner emits a single combined diagnostic covering both, and SC-5 is satisfied by that combined-diagnostic shape. Plan-phase characterizes the actual API error envelope (#Q-6) before committing to one-vs-two diagnostics — the spec must not assert distinguishability it has no evidence for (Principle II). (US-2)
- **FR-10 (footgun-warning)**: `orchestrator:status` and `orchestrator:doctor` (via `run-doctor.sh`) emit a warning when `deploy_target: github-pages` AND the repo is private AND the plan is non-Enterprise (with the #Q-3 fallback when plan detection is unavailable). The warning names the public-exposure and 422-freeze risks and points to the Cloudflare target + docs. (US-3)
- **FR-11 (installation-docs)**: `references/installation.md` documents the Enterprise-only-private-Pages pitfall, the lapsed-entitlement (build-green / deploy-422) failure mode, the Cloudflare Pages + Access recipe, the required API-token scopes, and the Zero Trust operator prerequisite. **Symmetric coverage (gate THREAT-7):** it MUST also document the *Cloudflare* entitlement-lapse failure mode (trial → free downgrade, team growth past the 50-user free-tier limit, billing change) with its observable signals (Cloudflare dashboard state + the FR-3a pre-deploy health-check failure) — the Cloudflare path must not be held to a lower documentation standard than the GitHub Pages path it replaces. A note on custom domains and extending the Access app's `self_hosted_domains` (gate THREAT-11) is included. (US-3)
- **FR-12 (giscus-unaffected)**: Both targets leave `overrides/partials/comments.html` and the giscus smoke gate unchanged; the read-but-not-comment caveat for Access-authenticated non-collaborators is documented. (US-3, US-4)
- **FR-13 (live-validation-protocol)**: A documented friendly-tester / live-deploy protocol exists for US-4, mirroring the M033 / M041 convention; closing the milestone at shippable scope (US-1..US-3) forward-points this pass. (US-4)

## Success Criteria

- **SC-1**: With `wiki.deploy_target: cloudflare-access` in config, `bash scripts/lifecycle/wiki-init.sh` (against a stub remote) writes `.github/workflows/wiki-cloudflare.yml` and does not write `pages.yml`; with `github-pages`, the emitted output is byte-identical to the pre-M043 baseline (diff exit 0). (FR-1, FR-2, FR-3)
- **SC-2**: A template lint over `templates/wiki-cloudflare-deploy.yml.tmpl` and any emitted `wiki-cloudflare.yml` exits 0 only when the deploy step uses `npx --yes wrangler@4` and contains no `cloudflare/wrangler-action` substring. (FR-3)
- **SC-3**: `bash scripts/wiki/cloudflare-access-setup.sh` against the recorded-API fixture creates resources in the order Pages-project → Access-app → policy, and the Access app's `self_hosted_domains` contains both `<name>.pages.dev` and `*.<name>.pages.dev` (asserted from the captured request payloads). (FR-6, FR-8)
- **SC-4**: A second invocation of `cloudflare-access-setup.sh` against the all-present fixture issues zero create requests and exits 0. (FR-7)
- **SC-5**: The provisioner against a "Zero-Trust-not-enabled" fixture exits non-zero and prints a diagnostic containing the dashboard-enablement instruction; against a "missing-scope" fixture it prints the scope-specific diagnostic. (FR-9)
- **SC-6 (gate MIT-4 — conditional)**: The warning logic is verified per the #Q-3 implementation branch chosen at plan-phase: **(reliable-detection branch)** it fires on exactly the (private, github-pages, non-Enterprise) tuple and is silent on (private, github-pages, Enterprise) and all other combinations; **(fallback branch)** it fires on all (private, github-pages) tuples regardless of plan, with an "ignore if Enterprise Cloud" note in the warning text, and is silent on all other target/visibility combinations. The FR-10 fixture matrix exercises whichever branch (or both) the phase plan commits to. (FR-10)
- **SC-10 (gate MIT-1)**: The emitted `wiki-cloudflare.yml` places the FR-3a pre-deploy Access health-check step before the `npx wrangler pages deploy` step (asserted by ordering check on the emitted workflow), and a fixture where the Access app/policy is absent causes that step to exit non-zero before any deploy call is made. (FR-3a)
- **SC-7**: `references/installation.md` contains, post-milestone, sections covering the Enterprise-only pitfall, the build-green/deploy-422 mode, the Cloudflare recipe, token scopes, and the Zero Trust prerequisite (grep-asserted anchors). (FR-11)
- **SC-8**: The giscus smoke gate passes on a Cloudflare-target build with no change to `overrides/partials/comments.html` (diff exit 0 on the partial). (FR-12)
- **Note (gate accepted risk):** the recorded-API fixtures referenced by SC-3, SC-4, SC-5, and SC-10 are explicit phase-plan deliverables — M043's phase plan must include fixture-creation tasks, or these criteria cannot be mechanically verified at milestone close.
- **SC-9** (US-4, deferred-validation acknowledgment permitted): A live end-to-end deploy is verified — recorded `302 → cloudflareaccess.com` on the live URL, a green CI run, and a working giscus comment — or the pass is forward-pointed with a signed deferred-validation note. (FR-13)

## Non-Goals

- **No automated github-pages → cloudflare-access migration.** Operators flip the config and re-run `wiki-init.sh --deploy`; an automated cutover is a candidate follow-on if demand appears. (Migrating existing wikis silently is itself a footgun.)
- **No general multi-cloud deploy abstraction.** Exactly two targets (`github-pages`, `cloudflare-access`); Netlify/Vercel/S3 are out — adding a third target should not be cheaper than adding the second, and YAGNI applies until a third is demanded.
- **No bring-your-own-IdP integration.** Cloudflare's one-time-PIN is the documented default; operators can wire an IdP in the Cloudflare dashboard, but the orchestrator does not manage it.
- **No secrets-management system.** `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` live in operator-provisioned GitHub repo secrets; the orchestrator documents required scopes but never stores or rotates them.

## Constraints

- **CON-1 (build-pipeline-verbatim)**: The mkdocs build pipeline — stub-freshness check, `wiki/.staged/` materialization (decorator-or-verbatim fallback), `mkdocs build` — is carried over unchanged into the Cloudflare workflow. Only the deploy step differs between targets.
- **CON-2 (no-wrangler-action)**: The Cloudflare workflow deploys via `npx --yes wrangler@4`, never `cloudflare/wrangler-action`, because the action auto-detects the repo package manager (commonly `bun` in orchestrator app repos) and fails with `Unable to locate executable file: bun` on a clean runner. This is asserted by a template lint (SC-2), not left to convention. **Accepted risk (gate):** `@4` is a floating major-version pin (latest `4.x.y` per CI run, no lockfile) — standard `npx`-in-CI convention; revisit with a patch pin or lockfile only if a confirmed `wrangler@4` regression breaks `pages deploy`.
- **CON-3 (no-clobber-operator-workflows)**: Emitting either workflow honors the existing no-clobber convention — a pre-existing operator-authored workflow file is preserved with a reconciliation diagnostic, never overwritten.
- **CON-4 (github-pages-byte-stable)**: The `github-pages` path is byte-identical to its pre-M043 behavior. Existing wikis must observe no change unless the operator explicitly opts into the new target.
- **CON-5 (bash-3.2)**: New shell (`cloudflare-access-setup.sh`, config-branching) is Bash 3.2 / POSIX-sh compliant — no `declare -A`, no process substitution — matching the existing wiki-deploy tooling.
- **CON-6 (access-before-deploy, two enforcement sites — gate MIT-2/NEW-1)**: The exposure window is closed at **two distinct enforcement sites**, and this constraint names both so a future maintainer does not read it as a single runtime invariant:
  1. **Provisioning time** (`cloudflare-access-setup.sh`, FR-8): the Access app + allow policy are created and confirmed before the first deployment is possible; this ordering is structurally enforced by the script and holds across interrupted runs.
  2. **Every CI deploy** (emitted `wiki-cloudflare.yml`, FR-3a): a pre-deploy health-check step re-confirms the Access app + policy are present and active before each `wrangler pages deploy`; this guards against post-provisioning lapse and is enforced by the emitted workflow, not by documented step order.
  Removing either enforcement site reopens the exposure window. The provisioning-time guarantee does NOT cover steady-state deploys — that is FR-3a's job.
- **CON-7 (domain-list-reprovision)**: Until the M037 yaml-merge list-element preservation gap closes (CLAUDE.md round-5 deferred follow-up), changes to `wiki.cloudflare.allowed_email_domains` are applied by re-running `cloudflare-access-setup.sh` (which updates the Access policy), not by editing config and relying on `orchestrator:update` merge — a silently-emptied domain list is an access-control data-loss event. (gate MIT-5)

### Knowledge-Layer Boundary (M043 vs. M036/M020 knowledge milestones)

M043 writes no knowledge-tree entries. It touches only deploy tooling (`scripts/wiki/`, `scripts/lifecycle/wiki-init.sh`, `templates/`, `references/installation.md`, the status/doctor warning) and the project config schema. The reference-corpus and knowledge-graph write-sites (`knowledge/**`, KNOWLEDGE-INDEX.md) remain owned by M036/M020 and are not modified here. The wiki this feature deploys is a *view* onto knowledge produced elsewhere; M043 changes how that view is hosted, not what it contains.

## Assumptions

- The operator has (or can create) a free Cloudflare account and can perform the one-time Zero Trust dashboard enablement (not API-triggerable).
- The operator can create a scoped Cloudflare API token (`Account › Cloudflare Pages › Edit`, `Account › Access: Apps and Policies › Edit`, `Account › Account Settings › Read`) and store it plus the account id as GitHub repo secrets. **Health-check scope (gate MIT-3):** if the FR-3a pre-deploy health check uses an *authenticated* API probe, the token must additionally carry `Account › Access: Apps and Policies › Read` (unless plan-phase confirms the existing Edit scope grants sufficient read access); if it uses the unauthenticated redirect probe, no additional scope is required. The chosen probe (#Q-5) determines which applies, and FR-11's documented scope table must match — operators provision tokens from the docs before they ever read a phase plan, so a scope omission here surfaces as a 403 on every CI run.
- The project already has a working mkdocs wiki under `wiki/` (M032/M037 tooling installed); M043 changes only the deploy target, not wiki initialization.
- giscus (where used) is already configured against the repo's Discussions; M043 does not alter giscus setup.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle II (Evidence Before Claims)**: The feature originates from a live, end-to-end-validated downstream incident (`pbj-central`, 2026-06-04), not speculation; success criteria are mechanically verifiable (template lints, recorded-API fixtures, a warning fixture matrix), and the one criterion that requires a live account (SC-9) is explicitly gated as a friendly-tester pass with a signed-evidence artifact.
- **Principle VI (State On Disk Is Truth)**: The deploy target is a declared config value (`wiki.deploy_target`) read from disk by every consuming surface; behavior is a function of recorded state, not inferred context, and the provisioner's idempotency is defined against on-account resource state.
- **Principle VII (Knowledge Compounds)**: The footgun and its non-obvious failure mode are captured in `references/installation.md` and the source brief, so the lesson that cost `pbj-central` days is recorded once and reused by every future project rather than rediscovered.
- **Principle I (Context Minimization)**: The change is contained to the deploy step plus one setup script, one template, one config key, and one warning; it adds no new command surface and no runtime dependency beyond `npx wrangler` invoked inside CI.

## Open Questions (defer to planning)

- **#Q-1 (default-posture)**: Keep `github-pages` as the upgrade-safe config default (recommended — no silent behavior change on upgrade) while `init`/`wiki-init` *recommend* `cloudflare-access` on private repos and the FR-10 warning catches the dangerous tuple; or, more aggressively, default new private-repo inits to `cloudflare-access`. Resolve at plan-phase.
- **#Q-2 (token-account-sourcing)**: Repo secrets only (recommended for CI), or also support a managed-marker `.env` block analogous to the giscus loader in `wiki-deploy.sh` for local preview? Lean repo-secrets-only with `.env` documented as a local escape hatch.
- **#Q-3 (plan-detection)**: How reliably can "non-Enterprise" be detected via `gh api`? Plan-phase MUST explicitly commit to one of three implementation paths and name the corresponding SC-6 branch in the phase plan: **(a)** reliable detection only; **(b)** fallback only (fire on all (private, github-pages) with an "ignore if Enterprise Cloud" note); **(c)** both, with a runtime branch. The FR-10 fixture matrix must cover the chosen path. (gate MIT-4)
- **#Q-5 (health-check-probe-mechanism)** *(gate MIT-3, blocks FR-3a implementability)*: Choose the FR-3a pre-deploy probe — **(a)** authenticated API probe (requires the Access Read scope; specify endpoint + expected response), **(b)** unauthenticated redirect probe (assert `302 → cloudflareaccess.com` on `https://<name>.pages.dev`; no extra scope, but acknowledge + mitigate CDN edge-cache false positives, e.g. `Cache-Control: no-cache` / retry window), or **(c)** reuse the provisioner Edit-scope token after confirming in-spec that Edit grants sufficient read access. The choice updates the Assumptions token-scope table and FR-11. Resolve before FR-3a is implemented.
- **#Q-6 (api-error-envelope)** *(gate THREAT-2)*: Characterize the Cloudflare Access API responses for "Zero Trust not enabled" vs. "token missing scope" (HTTP status, error code/body field) before implementing FR-9. If indistinguishable, downgrade to the combined diagnostic and revise SC-5 accordingly. Research prerequisite, not invention.
- **#Q-4 (sequencing-vs-M041)**: `cloudflare-access-setup.sh` lands under `scripts/wiki/`. If M041 (framework-owned `scripts/wiki/` carve-out) ships first, the script auto-distributes via `orchestrator:update`; if M043 ships first, document the manual-`cp` bridge per the M041 proposal. Prefer M041-then-M043 if both are queued together.

## Dependencies

- **M032 (wiki distribution + init integration)** — owns `wiki-init.sh --deploy` and the `wiki:` config namespace this feature extends.
- **M037 (wiki team-feedback-ready)** — shipped `emit_pages_workflow` / FR-19 `pages.yml` scaffold and the `wiki-deploy.sh` gate chain this feature branches a target into.
- **External: Cloudflare** — Pages + Access (Zero Trust) APIs; `wrangler@4` via `npx` on the CI runner; an operator-provisioned scoped API token + account id.

## Downstream Consumers (informational, not binding)

- **M041 (`scripts/wiki/` framework-owned carve-out)** — if it ships, it will own auto-distribution of `cloudflare-access-setup.sh` and the new template via `orchestrator:update`.
- **Distribution workstream (`.orchestrator/proposals/distribution-surface.md`)** — the `pbj-central` incident is a publishable case study; the source brief is a candidate for `.orchestrator/distribution/case-studies/`.
- **post-launch-wiki-ux-and-adapters** — a future multi-host wiki UX story would consume the `deploy_target` switch established here.
