# M043 Live-Deploy Validation — Recruitment Kit

Thanks for helping. This is a **~30-minute live validation** of the
orchestrator's Cloudflare Pages + Cloudflare Access wiki-deploy target.
The build was verified entirely against recorded API fixtures; you are the
real account that confirms the gate actually closes. Read this one page,
then follow the steps.

The full, authoritative walkthrough is `protocol.md` in this same
directory — this kit is the condensed brief.

## Are you eligible?

You're eligible if **both** are true:

- [ ] You have a real **Cloudflare** account you can enable **Zero Trust**
  on (or access to one).
- [ ] You have a **private test repo** (or can create one) where the
  orchestrator wiki can be initialized.

Unlike the M033 friendly-tester pass, this is **not** a cold-start UX test
— it checks whether a real live deploy actually gates the wiki. So
**maintainers are welcome to run it**; the only scarce thing is a real
Cloudflare account.

## Before you start

You'll need, in the test repo's **GitHub Actions secrets**:

- `CLOUDFLARE_API_TOKEN` scoped to exactly **`Access: Apps and Policies —
  Edit` + `Pages — Edit` + `Account Settings — Read`** (no extra Read
  scope).
- `CLOUDFLARE_ACCOUNT_ID`.

And your **Cloudflare** account must have **Zero Trust enabled** (a
one-time dashboard step — it cannot be turned on via the API).

## What you'll do

```bash
# In the test repo's .orchestrator/config.yml set:
#   wiki.deploy_target: cloudflare-access
#   wiki.cloudflare: { project_name, account-id source, allowed_email_domains }

# 1. Provision Cloudflare (Pages project -> Access app -> allow policy).
bash scripts/wiki/cloudflare-access-setup.sh --project-dir <repo>
#    Expect: "OK: cloudflare-access-setup complete ..."

# 2. Re-run it — confirm it's a no-op (idempotent).
bash scripts/wiki/cloudflare-access-setup.sh --project-dir <repo>

# 3. Emit the deploy workflow + provision, then push to main.
bash scripts/lifecycle/wiki-init.sh --project-dir <repo> --deploy

# 4. Wait for the CI run to go green, then check the gate:
curl -sI https://<name>.pages.dev   # expect 302 -> *.cloudflareaccess.com
```

## What to capture

Five things (the first three are the gate; the last two are informational):

1. **302 redirect** — `curl -sI` of the live URL returns `302` with a
   `location:` header pointing at `*.cloudflareaccess.com` (no content
   served to an unauthenticated client).
2. **Green CI** — the `wiki-cloudflare.yml` workflow run went green.
3. **giscus** — log in as an allowed-domain user, post a comment on a wiki
   page, confirm it persists.
4. **#Q-5** — with the Edit-only token, `GET /accounts/{id}/access/apps`
   returns `200` + app list (or `403` → record the redirect fallback).
5. **#Q-6** — the real Cloudflare error envelopes for Zero-Trust-off
   (expect HTTP 400 / code 12130) vs. token-missing-scope (expect HTTP
   403 / code 9109); record whether they stay distinguishable.

## How to file your report

Copy the evidence template, fill it in, and run the gate:

```bash
cp tests/m043-acceptance/live-deploy/evidence-template.md \
   tests/m043-acceptance/live-deploy/evidence/$(date +%F).md
# fill the frontmatter: redirect_verified / ci_green / giscus_working
#                       (+ edit_scope_grants_read / error_envelopes_match)

bash tests/m043-acceptance/live-deploy/validate-evidence.sh \
   tests/m043-acceptance/live-deploy/evidence/<today>.md
```

It exits 0 when the three gate fields are all `yes`. If you couldn't
complete the live deploy, a maintainer instead files a signed
deferred-validation note (`deferred_validation: yes` + `signed_by:`), which
forward-points the live pass — see `protocol.md`.

Done. Thank you.
