# Proposal: M043 — Cloudflare Pages + Access as a first-class wiki-deploy target

**Captured**: 2026-06-04 from `pbj-central-mono-repo` live validation (upstream brief preserved alongside this proposal at `.orchestrator/proposals/M043-source-brief-pbj-central-2026-06-04.md`).
**Shape**: Post-launch fast-follow, **demand-driven by a live incident** (not speculative). Sized ~M037-P02-tier — single milestone, ~6–9 SCs, ~1 week.
**Provisional ID**: M043. (`M041-scripts-wiki-carve-out.md` already shows the milestone-ID-as-filename convention can collide — M041 was consumed by `orchestrator:detective`. Re-confirm the ID at queue-entry; M043 is free as of capture.)
**Predecessors**: M032 (wiki distribution + init integration — owns `wiki-init.sh --deploy` and the `wiki:` config namespace this extends), M037 (wiki team-feedback-ready — shipped `emit_pages_workflow` / FR-19 `pages.yml` scaffold + the `wiki-deploy.sh` gate chain this forks a target into).
**Siblings**: `M041-scripts-wiki-carve-out.md` (framework-owned `scripts/wiki/` — the new `cloudflare-access-setup.sh` lands in that carve-out's blast radius; sequence M041 first if both are live), `post-launch-wiki-ux-and-adapters.md` (wiki UX deep + external-tool adapters — distribution-surface cousin).

## Source — what bit us

`pbj-central-mono-repo` (private repo, org on GitHub **Team** plan after an Enterprise trial lapsed) runs the orchestrator wiki. The wiki surfaces confidential `.orchestrator/` content — spec, decisions, GTM, SME discussions, milestones. Two failure modes surfaced, both rooted in the GitHub-Pages-only deploy assumption:

1. **Silent exposure.** A *private* (access-controlled) GitHub Pages site is a **GitHub Enterprise Cloud–only** feature. On Free/Pro/Team, publishing a private repo's Pages produces a **public** site. A team that enables Pages on a private repo without realizing this makes the entire `.orchestrator/` corpus world-readable.
2. **Silent deploy failure** (the one that actually bit them). The org's Enterprise trial lapsed to Team, dropping the private-Pages entitlement. `actions/deploy-pages` then **422'd on every push** (`"Page is disabled because current plan does not support private GitHub Pages"`) while the **build job stayed green**. The run list looked healthy; the live wiki silently froze for days; root cause was non-obvious (looked like content/config, was plan entitlement).

## The validated fix — Cloudflare Pages + Cloudflare Access

Free, stable private URL, gated by SSO / one-time-PIN, **independent of the GitHub plan and repo visibility**. The mkdocs build is unchanged; **only the deploy step changes.** Validated end-to-end on `pbj-central-mono-repo` 2026-06-04: Cloudflare Pages project `pbj-wiki`, Access self-hosted app gating `pbj-wiki.pages.dev` + `*.pbj-wiki.pages.dev` to two email domains via one-time PIN. Unauthenticated requests `302 → cloudflareaccess.com`; only allowed domains get in. GitHub Pages `pages.yml` was retired in the same change downstream.

## Evaluation verdict — **adopt; recommend cloudflare-access as the default for private wikis**

Strong yes. Rationale:

- **The footgun is severe and silent.** Both failure modes are confidentiality/availability incidents that a non-expert operator cannot easily diagnose. The orchestrator markets the wiki as *the view onto the knowledge graph* (`project_knowledge_graph_vision` memory); shipping a default that silently leaks or silently freezes that view is a launch-credibility liability.
- **Cost of adoption is low.** The build pipeline (stub-freshness check, `wiki/.staged/` materialization, `mkdocs build`) carries over verbatim. The change is contained to the deploy step + a one-time setup script + a config switch + docs. giscus is unaffected (client-side; still posts to the repo's Discussions).
- **It is genuinely runtime-/plan-agnostic**, which matches the orchestrator's "works regardless of your GitHub plan" posture better than the Enterprise-gated status quo.

**Recommended default posture** (not a forced flip — backward compatibility preserved):

- `wiki.deploy_target` defaults to `github-pages` for existing projects (no silent behavior change on upgrade).
- `orchestrator:init` / `wiki-init.sh` **recommend `cloudflare-access` when the repo is private** (probe repo visibility; emit a recommendation, not a hard switch).
- `orchestrator:status` / `orchestrator:doctor` **warn** when `deploy_target: github-pages` AND repo is private AND plan ≠ Enterprise — this is the structural defense against both failure modes above.

## Integration points (mapped to the current code surface)

The deploy target is currently **hardwired to GitHub Pages** across three surfaces. M043 introduces a `wiki.deploy_target` switch consumed by each:

| Surface | Today | M043 change |
|---|---|---|
| `templates/orchestrator-config-default.yml` `wiki:` block (currently `landing_cards` / `code_prefixes` / `spec_paths`) | no deploy key | add `deploy_target: github-pages` (enum: `github-pages \| cloudflare-access`) + a commented `cloudflare:` sub-block (`project_name`, `account_id` source, `allowed_email_domains`) |
| `scripts/lifecycle/wiki-init.sh` — `emit_pages_workflow()` (FR-19, ~L531) + 4-step `--deploy` GitHub-Pages config sequence (~L1101–1271) | always emits `pages.yml` + flips repo Pages `build_type=workflow` + `gh api PUT /pages` | branch on `deploy_target`: `cloudflare-access` emits `wiki-cloudflare.yml` instead and runs `cloudflare-access-setup.sh` (Pages project + Access app/policy) in place of the gh-pages config steps |
| `scripts/wiki/wiki-deploy.sh` — gate chain → `git push` → `pages.yml` (push instruction ~L271) | prints GitHub-Pages workflow URL | when `deploy_target: cloudflare-access`, print the Cloudflare workflow URL + note that gates are identical |
| `.github/workflows/pages.yml` (and the `wiki-init.sh` `emit_pages_workflow` heredoc copy) | `actions/deploy-pages@v4` | **new** `templates/wiki-cloudflare-deploy.yml.tmpl` — identical build steps, deploy via `npx --yes wrangler@4 pages deploy wiki/site --project-name=<name> --branch=main --commit-dirty=true` |
| **new** `scripts/wiki/cloudflare-access-setup.sh` | — | idempotent: creates Pages project + Access self-hosted app + allow policy from `CLOUDFLARE_API_TOKEN` + account id + allowed email domains; covers apex + wildcard |
| `references/installation.md` | GitHub-Pages-only | document the Enterprise-only-private-Pages pitfall + the lapsed-entitlement (build-green / deploy-422) failure mode + the cloudflare-access recipe |
| `orchestrator:status` / `run-doctor.sh` | — | the private-repo + github-pages + non-Enterprise warning |

## Gotchas to bake in (learned the hard way downstream — non-negotiable for the template)

1. **Use `npx --yes wrangler@4 pages deploy …`, NOT `cloudflare/wrangler-action`.** The action auto-detects the repo's package manager (e.g. **bun**, common in orchestrator app repos) and fails with `Unable to locate executable file: bun` on a runner without it. Plain `npx wrangler` sidesteps this entirely.
2. **Create the Access app + policy BEFORE the first deploy** — no public-exposure window. (Creating an empty Pages project exposes nothing; there is no deployment yet.) `cloudflare-access-setup.sh` must enforce this ordering.
3. **Cover apex + wildcard** in the Access app (`<name>.pages.dev` AND `*.<name>.pages.dev`) so preview deployments are gated too.
4. **Zero Trust enablement is a one-time dashboard step** that cannot be API-triggered — surface it as an explicit operator prerequisite (the setup script should detect the missing-Zero-Trust error and emit a loud, actionable diagnostic rather than a raw API error).
5. **Build pipeline is verbatim** — stub-freshness check, `wiki/.staged/` materialization (decorator-or-verbatim fallback), `mkdocs build` all stay as-is.
6. **giscus needs no change** — `overrides/partials/comments.html` is untouched. Document one caveat: a viewer who authenticates via Cloudflare Access but is *not* a GitHub collaborator can read but not comment.

## Strict scope

This is **a second deploy target + a safety warning**, not:

- **A migration tool.** No automated github-pages → cloudflare-access cutover for existing wikis; operators flip the config + re-run `wiki-init.sh --deploy`. (Candidate follow-on if demand appears.)
- **A general multi-cloud deploy abstraction.** Two targets only (`github-pages`, `cloudflare-access`). Netlify/Vercel/S3 are out.
- **An IdP integration.** One-time-PIN is the documented default; bring-your-own-IdP is operator-configurable in the Cloudflare dashboard but not orchestrator-managed.
- **A secrets-management system.** `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` live in GitHub repo secrets (operator-provisioned); the orchestrator documents the required token scopes but does not store or rotate them.

## Phase breakdown (preliminary)

### P01 — Config switch + Cloudflare deploy workflow template
- Add `wiki.deploy_target` (+ `cloudflare:` sub-block) to `templates/orchestrator-config-default.yml`; FR-10 yaml-merge preserves operator values.
- New `templates/wiki-cloudflare-deploy.yml.tmpl` (build steps identical to `pages.yml`; deploy via `npx wrangler`).
- `wiki-init.sh` `emit_pages_workflow()` branches on `deploy_target` → emits the right workflow (CON-3 no-clobber preserved).
- `wiki-deploy.sh` prints the target-appropriate workflow URL.
- Acceptance: `deploy_target: cloudflare-access` emits `wiki-cloudflare.yml` and not `pages.yml`; `github-pages` is unchanged (byte-identical to today).

### P02 — `cloudflare-access-setup.sh` (idempotent provisioner)
- Creates Pages project (`POST /accounts/{acct}/pages/projects`), Access self-hosted app (apex + wildcard), allow policy (email-domain include). Re-running is a no-op on already-provisioned resources.
- **Access-before-deploy ordering** enforced; missing-Zero-Trust detected with an actionable diagnostic.
- `wiki-init.sh --deploy` invokes it in place of the gh-pages config steps when `deploy_target: cloudflare-access`.
- Acceptance: dry-run + a stubbed-API fixture proving the create-order and idempotency; cover the bun-not-found regression as an anti-pattern note (the workflow must use `npx`, asserted by a template lint).

### P03 — Docs + safety warning
- `references/installation.md`: Enterprise-only-private-Pages pitfall + lapsed-entitlement (build-green/deploy-422) failure mode + the cloudflare-access recipe + token scopes + Zero Trust prerequisite.
- `orchestrator:status` / `run-doctor.sh` warning: `deploy_target: github-pages` + private repo + non-Enterprise plan → warn (the structural defense).
- Acceptance: fixture-driven warning fires on the (private, github-pages, non-Enterprise) tuple and stays silent otherwise.

### P04 (optional) — Friendly-tester / live-deploy pass
- Same posture as the M033 / M041 friendly-tester convention: one real project provisioned end-to-end against a fresh Cloudflare account (Zero Trust enable → setup script → first deploy → verified `302 → cloudflareaccess` on the live URL). Human-recruitment task, not autonomous.

## Acceptance criteria (preliminary)

- **SC-1**: `wiki.deploy_target: cloudflare-access` causes `wiki-init.sh` to emit the Cloudflare workflow and skip the gh-pages config steps; `github-pages` path is byte-identical to pre-M043.
- **SC-2**: `cloudflare-access-setup.sh` is idempotent — second run produces no new mutations.
- **SC-3**: The Access app/policy is created **before** any deploy (no exposure window), and covers apex + wildcard.
- **SC-4**: The Cloudflare deploy workflow uses `npx --yes wrangler@4` (asserted by a template lint that rejects `cloudflare/wrangler-action`).
- **SC-5**: Missing Zero Trust enablement yields an actionable operator diagnostic, not a raw API error.
- **SC-6**: `orchestrator:status` / `doctor` warns on the (private repo + github-pages + non-Enterprise) tuple and is silent otherwise.
- **SC-7**: giscus continues to function on both targets with no `comments.html` change (smoke gate unchanged).
- **SC-8** (P04): live end-to-end deploy verified (`302 → cloudflareaccess` on the live URL, CI green run).

## Open questions (resolve at specify-time)

- **#Q-1 — default posture.** Recommended: keep `github-pages` as the upgrade-safe config default, but have `init`/`wiki-init` *recommend* `cloudflare-access` on private repos, and rely on the doctor/status warning to catch the dangerous tuple. Alternative (more aggressive): default new private-repo inits to `cloudflare-access`. Decide at specify-time.
- **#Q-2 — account-id / token sourcing.** Repo secrets only (proposed), or also support a `.env` managed-marker block like the giscus loader in `wiki-deploy.sh`? Lean repo-secrets-only for CI; document `.env` as the local-preview escape hatch.
- **#Q-3 — plan detection for the warning.** Detecting "not Enterprise" reliably via `gh api` may be imperfect. Fallback: warn whenever (private repo + github-pages) regardless of plan, with a "if you're on Enterprise Cloud, ignore" note. Cheaper and never wrong in the dangerous direction.
- **#Q-4 — sequencing vs M041.** `cloudflare-access-setup.sh` lands under `scripts/wiki/`. If M041 (framework-owned `scripts/wiki/` carve-out) ships first, the new script auto-distributes via `orchestrator:update` for free. If M043 ships first, document the manual-`cp` bridge per the M041 proposal. Prefer M041-then-M043 if both are queued together.

## Reference — the working workflow + evidence

The validated GitHub Actions workflow, exact API calls, token scopes, and live evidence are in the source brief at `.orchestrator/proposals/M043-source-brief-pbj-central-2026-06-04.md` (the live `pbj-central` incident is also a publishable case study for the distribution workstream — consider promoting to `.orchestrator/distribution/case-studies/` at specify-time). Deploy step, verbatim:

```yaml
- name: Deploy to Cloudflare Pages (private — gated by Cloudflare Access)
  run: npx --yes wrangler@4 pages deploy wiki/site --project-name=<name> --branch=main --commit-dirty=true
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```
