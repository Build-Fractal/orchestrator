# Upstream proposal: add Cloudflare Pages + Access as a private wiki-hosting target

**For:** the orchestrator framework maintainer agent (`~/Sites/orchestrator`).
**From:** downstream project `pbj-central-mono-repo`, validated live 2026-06-04.
**Ask:** evaluate adding Cloudflare Pages + Cloudflare Access as a first-class wiki-deploy target (ideally the recommended one for private wikis), alongside or instead of the current GitHub Pages path.

---

## The problem with the current GitHub Pages default

The orchestrator wiki ships an mkdocs site deployed via a GitHub Actions workflow (`pages.yml` → `actions/deploy-pages`). That assumes GitHub Pages. But **a *private* (access-controlled) GitHub Pages site is a GitHub Enterprise Cloud–only feature.** On GitHub Free/Pro/Team:

- You can publish Pages from a private repo, **but the published site is PUBLIC** (anyone with the URL can read it).
- An access-controlled private site requires **Enterprise Cloud**.

For orchestrator projects this is a real footgun, because the wiki surfaces **confidential content** (spec, decisions, GTM, SME discussions, milestones). Two bad outcomes:

1. **Silent exposure** — if a team enables Pages on a private repo without realizing the site is public, the whole `.orchestrator/` corpus is world-readable.
2. **Silent deploy failure** — what bit us: the org's Enterprise *trial lapsed to Team*, which dropped the private-Pages entitlement. The `actions/deploy-pages` step then **422'd on every push** (`"Page is disabled because current plan does not support private GitHub Pages"`) while the **build job kept passing green** — so it looked healthy in the run list but the live wiki silently froze for days. Root cause was non-obvious (looked like a content/config issue; was actually plan entitlement).

## The fix we validated: Cloudflare Pages + Cloudflare Access

Free, stable private URL, gated by SSO/one-time-PIN, **independent of the GitHub plan**, works on any repo visibility. Validated live on `pbj-central-mono-repo` (private repo, org on Team plan): `https://pbj-wiki.pages.dev` — unauthenticated requests get `302 → cloudflareaccess.com` login; only allowed email domains get in.

### The recipe (drop-in, mkdocs build unchanged)

1. **One-time, operator (dashboard):** enable Cloudflare **Zero Trust** (pick a team name → Free plan; may ask for a card to verify, no charge). Create a scoped **API token** with: `Account › Cloudflare Pages › Edit`, `Account › Access: Apps and Policies › Edit`, `Account › Account Settings › Read`.

2. **Create the Pages project** (API): `POST /accounts/{acct}/pages/projects` with `{name, production_branch:"main"}`. The host becomes `<name>.pages.dev`.

3. **Create the Access app + policy BEFORE first deploy** (API, so content is never exposed):
   - `POST /accounts/{acct}/access/apps` → `{type:"self_hosted", domain:"<name>.pages.dev", self_hosted_domains:["<name>.pages.dev","*.<name>.pages.dev"], session_duration:"24h"}` (wildcard covers preview deploys).
   - `POST /accounts/{acct}/access/apps/{id}/policies` → `{decision:"allow", include:[{email_domain:{domain:"<org-domain>"}}, ...]}`. One-time-PIN login works out of the box (no IdP needed).

4. **Deploy in CI** (GitHub Actions): build mkdocs, then deploy with **`npx --yes wrangler@4 pages deploy wiki/site --project-name=<name> --branch=main --commit-dirty=true`**, env `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` from repo secrets.

### Gotchas to bake into the template (we hit these)

- **Do NOT use `cloudflare/wrangler-action`** — it auto-detects the repo's package manager (e.g. **bun**, which orchestrator app repos often use) and the step fails with `Unable to locate executable file: bun` on a runner without it. Use plain `npx wrangler` instead.
- **Set Access BEFORE the first deploy** so there's no public-exposure window. (Creating the empty Pages project exposes nothing — no deployment yet.)
- **Cover apex + wildcard** in the Access app (`<name>.pages.dev` and `*.<name>.pages.dev`) so preview deployments are gated too.
- Zero Trust enablement is a **one-time dashboard step** that can't be API-triggered — surface it as an operator prerequisite.
- The existing build pipeline carries over unchanged: stub-freshness check, the `wiki/.staged/` materialization step, and `mkdocs build` all stay as-is. Only the deploy step changes.

### giscus still works (no change needed)

giscus is a client-side widget that talks to GitHub, so the hosting move doesn't affect it — comments still post to the repo's Discussions. It functions on **private** repos when all viewers are repo collaborators (comments land in the private repo's Discussions). The `overrides/partials/comments.html` partial needs no change. Only caveat to document: a viewer who authenticates via Cloudflare Access but is *not* a GitHub collaborator can read but not comment.

## Suggested integration points in orchestrator

- Add a deploy target switch — e.g. `.orchestrator/config.yml` `wiki.deploy_target: github-pages | cloudflare-access`, consumed by `wiki-init.sh --with-deploy` and `scripts/wiki/wiki-deploy.sh`.
- Ship a **`wiki-deploy.yml` workflow template** for the Cloudflare target (build steps identical to the current `pages.yml`; deploy via `npx wrangler`). Our working file is reproduced below.
- A small **`scripts/wiki/cloudflare-access-setup.{sh,py}`** that creates the Pages project + Access app/policy from a token + account id + allowed email domains (idempotent), so projects don't hand-roll the API calls.
- **Docs**: in `references/installation.md` (or the wiki ops doc), state plainly: *private GitHub Pages requires Enterprise Cloud; for a private wiki on any plan, use the Cloudflare Pages + Access target.* Include the lapsed-entitlement failure mode (build green / deploy 422) as a known pitfall.
- Consider a **drift/health note** in `orchestrator:status`: if `wiki.deploy_target: github-pages` AND the repo is private AND the plan isn't Enterprise, warn that the published site is either public or will 422.

## Reference: the working GitHub Actions workflow (from pbj-central-mono-repo)

```yaml
name: Deploy wiki to Cloudflare Pages
on:
  push: { branches: [main] }
  workflow_dispatch:
permissions: { contents: read }
concurrency: { group: wiki-cloudflare, cancel-in-progress: false }
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12", cache: pip, cache-dependency-path: wiki/requirements.txt }
      - run: pip install -r wiki/requirements.txt
      - name: Check wiki stubs are fresh
        run: |
          if [ -x scripts/diagnostics/wiki-stubs-fresh.sh ]; then bash scripts/diagnostics/wiki-stubs-fresh.sh; else echo "skipping"; fi
      - name: Materialize wiki/.staged/ (decorator or verbatim fallback)
        run: |
          if [ -f scripts/wiki/wiki-decorate-build.py ]; then
            python3 scripts/wiki/wiki-decorate-build.py --force
          else
            mkdir -p wiki/.staged
            for d in memory spec decisions knowledge milestones proposals; do [ -d ".orchestrator/$d" ] && cp -R ".orchestrator/$d" "wiki/.staged/"; done
            for f in DECISIONS.md KNOWLEDGE.md milestone-summary.md spikes-registry.md; do [ -f ".orchestrator/$f" ] && cp ".orchestrator/$f" "wiki/.staged/"; done
          fi
      - run: mkdocs build -f wiki/mkdocs.yml
      - name: Deploy to Cloudflare Pages (private — gated by Cloudflare Access)
        run: npx --yes wrangler@4 pages deploy wiki/site --project-name=pbj-wiki --branch=main --commit-dirty=true
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

## Evidence

Validated end-to-end on `pbj-central-mono-repo` 2026-06-04: private repo, org on GitHub Team (post-Enterprise-trial). Cloudflare Pages project `pbj-wiki`, Access self-hosted app gating `pbj-wiki.pages.dev` + `*.pbj-wiki.pages.dev` to two email domains via one-time PIN. CI auto-deploys on push (verified green run + verified `302 → cloudflareaccess` on the live URL). GitHub Pages `pages.yml` retired in the same change.
