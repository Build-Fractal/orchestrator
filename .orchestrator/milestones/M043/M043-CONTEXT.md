---
schema_version: "1.0"
type: context-draft
milestone: "M043"
status: finalized
created_at: "2026-06-04"
finalized_at: "2026-06-04"
---

## Architectural Decisions

Resolved during the M043 pre-planning discussion (2026-06-04). These bind the
roadmap and plan-phase; they convert the spec's load-bearing open questions into
committed choices.

- **AD-1 — FR-3a health-check probe = reuse the Edit-scope token (#Q-5).** The
  emitted `wiki-cloudflare.yml` pre-deploy health check authenticates with the
  same `CLOUDFLARE_API_TOKEN` already in repo secrets (Access: Apps and Policies
  *Edit*, Pages *Edit*) to confirm the Access app + allow policy for
  `<name>.pages.dev` still exist before each `wrangler pages deploy`. No new
  operator token scope. **Plan-phase confirmation gate:** verify that the
  Cloudflare Edit scope grants sufficient read access to query app/policy
  existence (#Q-5 sub). If it does not, fall back to the **unauthenticated
  redirect probe** (assert `302 → cloudflareaccess.com` on `https://<name>.pages.dev`)
  with a `Cache-Control: no-cache` / retry-window mitigation for the CDN
  edge-cache false-positive. The authenticated-API-probe-with-new-scope option
  is rejected (operator-provisioning friction + 403-on-every-CI-run risk).

- **AD-2 — Footgun warning = fallback-only branch (#Q-3).** `orchestrator:status`
  / `doctor` fire the warning on every (private repo + `github-pages`) config
  regardless of detected GitHub plan, with an "ignore if you are on Enterprise
  Cloud" note in the warning text. No plan-detection logic in v1. This is never
  wrong in the dangerous direction (it cannot silently fail to warn), is cheapest
  to build, and removes the fragile `gh api` plan-probe entirely. SC-6 is
  satisfied by the fallback branch only; the reliable-detection and both-branch
  variants are dropped from M043 scope (promote later only if Enterprise users
  report warning noise). This simplifies SC-6 and the FR-10 fixture matrix to a
  single branch.

- **AD-3 — Default posture = keep `github-pages` default + recommend on private
  (#Q-1).** `wiki.deploy_target` defaults to `github-pages` (no silent behavior
  change for existing wikis on upgrade). `init` / `wiki-init` *recommend*
  `cloudflare-access` when the repo is private; the AD-2 warning is the structural
  backstop. New private-repo inits are NOT auto-defaulted to `cloudflare-access`
  (rejected: forces a Cloudflare account + Zero Trust enablement on every
  private-repo init, even for users who never deploy a wiki).

- **AD-4 — Sequencing = prefer M041-first, soft (#Q-4).** Sequence M043 after
  M041 (`scripts/wiki/` framework-owned carve-out) so `cloudflare-access-setup.sh`
  and the new workflow template auto-distribute via `orchestrator:update`. This is
  a soft preference, not a hard dependency: if M041 is not ready when M043 is
  pulled, M043 ships with the documented manual-`cp` bridge per the M041 proposal.
  Hard-blocking on M041 is rejected (couples two demand-driven milestones and
  stalls a security fix behind unrelated work).

## Scope Boundaries

**In scope (from spec, as bound by the decisions above):**
- `wiki.deploy_target` config switch + commented `wiki.cloudflare:` sub-block (FR-1).
- `wiki-init.sh` workflow-emit + `--deploy` branch on `deploy_target` (FR-2, FR-4).
- `templates/wiki-cloudflare-deploy.yml.tmpl` with the FR-3a pre-deploy health
  check using the Edit-scope token (AD-1), deploy via `npx --yes wrangler@4` (FR-3, FR-3a).
- `wiki-deploy.sh` target-aware workflow-URL print (FR-5).
- `scripts/wiki/cloudflare-access-setup.sh` — idempotent provisioner, access-before-deploy
  ordering, Zero-Trust + scope diagnostics (FR-6..FR-9).
- Fallback-only footgun warning in `status`/`doctor` (FR-10, AD-2).
- `references/installation.md` — pitfall + symmetric Cloudflare entitlement-lapse
  docs + token scopes + Zero Trust prereq + custom-domain note (FR-11).
- giscus unchanged on both targets (FR-12).
- Live/friendly-tester validation protocol (FR-13).

**Out of scope (spec Non-Goals, reaffirmed):** automated github-pages →
cloudflare-access migration; a general multi-cloud deploy abstraction (exactly two
targets); bring-your-own-IdP; secrets management; reliable-plan-detection and
both-branch warning variants (dropped per AD-2); the authenticated-API-probe
new-scope option (dropped per AD-1).

## Design Constraints

- **CON-6 two enforcement sites (provisioning-time setup script + every-CI-deploy
  health check) must both survive** — neither may be removed without reopening the
  exposure window. AD-1 supplies the CI-deploy enforcement.
- **CON-7 domain-list edits reprovision via the setup script** until the M037
  yaml-merge list-element preservation gap closes — `allowed_email_domains` is an
  access-control list; silent emptying is a lockout/data-loss event.
- **CON-2 — `npx --yes wrangler@4`, never `cloudflare/wrangler-action`** (bun
  auto-detect failure); asserted by a template lint (SC-2). `@4` floating pin is
  an accepted risk.
- **Bash 3.2 / POSIX-sh** for all new shell.
- **`github-pages` path byte-stable** vs pre-M043 (CON-4) — existing wikis observe
  no change unless the operator opts in.

## Open Questions

Two genuinely-open items remain for plan-phase; both are external-API research
prerequisites, not framework-internal decisions, and neither blocks roadmap
decomposition.

- **#Q-5-sub (Edit-scope-grants-read)** — *plan-phase research, blocks FR-3a final
  shape.* Confirm whether the Cloudflare Access "Apps and Policies — Edit" scope
  grants read access sufficient to query app/policy existence for the health check.
  If yes → authenticated probe with the existing token (AD-1 primary). If no →
  unauthenticated redirect probe with CDN-cache mitigation (AD-1 fallback).
  Answered by Cloudflare API docs / a one-call spike, not by the orchestrator corpus.
- **#Q-6 (api-error-envelope)** — *plan-phase research, shapes FR-9 / SC-5.*
  Characterize the Cloudflare Access API responses for "Zero Trust not enabled"
  vs. "token missing scope" (HTTP status, error code/body field). If mechanically
  indistinguishable, FR-9 emits a single combined diagnostic and SC-5 is revised
  to that shape (Principle II: do not assert distinguishability without evidence).
  Answered by characterizing real API behavior, not by the orchestrator corpus.
