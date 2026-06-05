---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M043"
name: "references/installation.md wiki-deploy footgun + symmetric Cloudflare docs"
depends_on: []
---

## Prerequisites

- `references/installation.md` exists on disk (≈754 lines at plan time). It
  already has a `## ` Wiki/`--deploy` discussion under the `## \`--with-<feature>\`
  Progressive Opt-In Flag Pattern` section (line ≈449) and a `## Installing via
  Homebrew` section (line ≈514). The new wiki-deploy-targets documentation lands
  as a new top-level `## ` section between those two (after the `### See also`
  subsection of the `--with-` pattern, before `## Installing via Homebrew`).
- `scripts/wiki/cloudflare-access-setup.sh` exists (P02) — the recipe references
  its flags. Its documented inputs: `--project-dir DIR`, `--project-name NAME`,
  `--account-id ID`, `--token TOKEN`, `--domains "a.com,b.com"`. Exit codes:
  `0` ok/idempotent, `4` Zero-Trust-not-enabled, `5` token-missing-scope.
- `templates/wiki-cloudflare-deploy.yml.tmpl` exists (P01) — the emitted workflow
  the recipe points to; it carries the FR-3a pre-deploy Access health check that
  reuses `CLOUDFLARE_API_TOKEN` (Access: Apps and Policies — Edit grants read per
  P00 #Q-5-sub; no extra Read scope).

## Description

Add the FR-11 wiki-deploy documentation to `references/installation.md` so the
`pbj-central` footgun and its non-obvious failure modes are captured once and
reused (Principle VII). The section MUST document, with grep-stable anchors: the
Enterprise-only-private-Pages pitfall; the build-green/deploy-422 lapsed-
entitlement mode; the Cloudflare Pages + Access recipe; the required API-token
scopes; the Zero Trust prerequisite; the **symmetric** Cloudflare entitlement-
lapse failure mode (THREAT-7); the custom-domain / `self_hosted_domains`-extension
note (THREAT-11); the CON-7 domain-list reprovision caveat; and the giscus
read-but-not-comment caveat (FR-12 doc side). Co-author the grep-anchor verifier.

## Steps

### Step 1 — Insert the wiki-deploy-targets section into `references/installation.md`

Insert a new top-level section after the `--with-<feature>` pattern's
`### See also` subsection (≈line 512) and before `## Installing via Homebrew`
(≈line 514). Use these EXACT heading texts and marker phrases (the verifier
grep-asserts each — keep them byte-stable):

```markdown
## Wiki Deploy Targets (GitHub Pages vs. Cloudflare Access)

The orchestrator wiki supports two deploy targets, selected by
`wiki.deploy_target` in `.orchestrator/config.yml`: the default `github-pages`
and `cloudflare-access`. The mkdocs build pipeline is identical across both —
only the deploy step differs.

### The Enterprise-only private-Pages pitfall

A **private, access-controlled GitHub Pages site is a GitHub Enterprise Cloud–only
feature.** On Free / Pro / Team, enabling Pages on a private repo publishes the
site — and the entire `.orchestrator/` corpus it surfaces (spec, decisions, GTM,
SME discussions, milestones) — **world-readable to anyone with the URL**. This is
the silent-exposure footgun that bit `pbj-central` (validated 2026-06-04). The
`orchestrator:status` / `orchestrator:doctor` warning (FR-10) fires on the
(private repo + `github-pages`) tuple to surface this; it carries an "ignore if
Enterprise Cloud" note because that plan supports private Pages.

### The build-green / deploy-422 lapsed-entitlement failure mode

When a GitHub Enterprise entitlement lapses (the observed case: a trial reverting
to Team), `actions/deploy-pages` begins returning **HTTP 422** on every push
(`"Page is disabled because current plan does not support private GitHub Pages"`)
**while the build job stays green.** The run list looks healthy, the live wiki
silently freezes for days, and the root cause reads as a content/config issue
when it is actually a plan entitlement. Treat a green build + frozen live site as
a plan-entitlement check first.

### Recipe: Cloudflare Pages + Access (plan-independent gated wiki)

`cloudflare-access` is free, plan-independent, and gates the site by SSO /
one-time-PIN. Steps:

1. Create a free Cloudflare account and **enable Cloudflare Zero Trust** in the
   dashboard (a one-time step that **cannot** be API-triggered — see the
   prerequisite below).
2. Create a scoped Cloudflare API token and store it plus the account id as
   GitHub repo secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
3. Set `wiki.deploy_target: cloudflare-access` and the `wiki.cloudflare:`
   sub-block (`project_name`, `allowed_email_domains`) in
   `.orchestrator/config.yml`.
4. Run `scripts/wiki/cloudflare-access-setup.sh` (via `orchestrator:wiki-init
   --deploy`, or directly) to provision the Pages project → Access app
   (apex + wildcard) → allow policy, in that order.
5. Push; the emitted `wiki-cloudflare.yml` runs the FR-3a pre-deploy Access
   health check, then deploys via `npx --yes wrangler@4 pages deploy`.

### Required API-token scopes

The Cloudflare API token needs exactly:

- **Account › Cloudflare Pages › Edit**
- **Account › Access: Apps and Policies › Edit**
- **Account › Account Settings › Read**

**No additional `Access: Apps and Policies › Read` scope is required.** The FR-3a
pre-deploy health check reuses the existing Edit-scope token — the Cloudflare Edit
permission grants the read access needed to query Access app / policy existence
(M043 P00 #Q-5-sub). If a future Cloudflare change removes that read grant, the
health check falls back to the unauthenticated `302 → cloudflareaccess.com`
redirect probe, which needs no token scope at all.

### Zero Trust prerequisite

`cloudflare-access-setup.sh` cannot enable Cloudflare Zero Trust for you — it is a
one-time dashboard action. If Zero Trust is not enabled, the provisioner exits
non-zero (exit 4) with a diagnostic naming the dashboard step, **before** any
deploy can expose content. A token missing the Access scope exits 5 with a
scope-specific diagnostic.

### Symmetric failure mode: Cloudflare entitlement lapse

The Cloudflare path is not held to a lower documentation standard than the GitHub
Pages path it replaces. Cloudflare has its **own** entitlement-lapse failure
modes (THREAT-7): a **trial → free downgrade**, growth past the **50-user
free-tier Access limit**, or a billing change can disable or degrade the Access
gate. The observable signal is the Cloudflare dashboard state **plus the FR-3a
pre-deploy health-check failing the CI deploy** — the same loud-not-silent
contract the GitHub-Pages 422 mode lacks. A green build that stops deploying on
the Cloudflare target is a Cloudflare-entitlement check first.

### Custom domains and extending the Access app

To serve the wiki on a custom domain instead of `<name>.pages.dev`, add the
custom hostname in Cloudflare Pages **and** extend the Access application's
`self_hosted_domains` to cover it (THREAT-11) — otherwise the new hostname is
served **ungated**. Re-run `cloudflare-access-setup.sh` (or edit the Access app)
so the apex, wildcard, and custom domains are all gated.

### Caveat: editing `allowed_email_domains` (CON-7)

`wiki.cloudflare.allowed_email_domains` is an access-control list. Until the M037
yaml-merge list-element preservation gap closes, **do not rely on
`orchestrator:update` config-merge to carry domain-list edits** — a silently
emptied list is a lockout / data-loss event. Apply domain-list changes by
re-running `cloudflare-access-setup.sh`, which reapplies the Access policy.

### giscus: read-but-not-comment for Access-authenticated non-collaborators

giscus is unchanged on both targets. Note (FR-12): a viewer authenticated through
Cloudflare Access who is **not** a GitHub collaborator on the repo can **read**
the giscus comment thread but **cannot post** — commenting requires a GitHub
identity with Discussions access. This is expected behavior, not a bug.
```

### Step 2 — Author `tools/verify/m043-p03-installation-anchors.sh`

Project-owned grep-anchor verifier (single-script-file, AD-19). Asserts each
FR-11/SC-7 anchor phrase is present in `references/installation.md`.

```bash
#!/usr/bin/env bash
# m043-p03-installation-anchors.sh — SC-7 (FR-11). references/installation.md
# documents the GitHub-Pages footgun + the symmetric Cloudflare entitlement-lapse
# failure mode, token scopes, Zero Trust prereq, custom-domain + CON-7 + giscus
# caveats. Grep-asserted anchors.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
DOC="references/installation.md"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }
anchor() { if grep -qiF -- "$2" "$DOC"; then echo "PASS: $1"; else echo "FAIL: $1 (missing: $2)"; fail=1; fi; }

[ -f "$DOC" ]; check "installation.md exists" $?

anchor "Wiki Deploy Targets section"        "## Wiki Deploy Targets"
anchor "Enterprise-only private-Pages pitfall" "Enterprise-only private-Pages pitfall"
anchor "build-green / deploy-422 mode"       "build-green / deploy-422"
anchor "Cloudflare Pages + Access recipe"    "Recipe: Cloudflare Pages + Access"
anchor "token scope: Pages Edit"             "Cloudflare Pages › Edit"
anchor "token scope: Access Apps and Policies Edit" "Access: Apps and Policies › Edit"
anchor "token scope: Account Settings Read"  "Account Settings › Read"
anchor "no extra Read scope"                 "No additional"
anchor "Zero Trust prerequisite"             "Zero Trust prerequisite"
anchor "symmetric Cloudflare entitlement lapse (THREAT-7)" "Cloudflare entitlement lapse"
anchor "50-user free-tier limit"             "50-user"
anchor "FR-3a health-check failure as signal" "FR-3a pre-deploy health-check"
anchor "custom-domain / self_hosted_domains note (THREAT-11)" "self_hosted_domains"
anchor "CON-7 domain-list reprovision caveat" "allowed_email_domains"
anchor "giscus read-but-not-comment caveat"  "read-but-not-comment"

echo "SUMMARY: m043-p03-installation-anchors.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

## Must-Haves

- Truth: installation.md documents all FR-11 anchors (pitfall, 422 mode, recipe,
  scopes, Zero Trust, symmetric Cloudflare lapse, custom-domain, CON-7, giscus).
  - Check: `bash tools/verify/m043-p03-installation-anchors.sh`
- Artifact: `references/installation.md` (modify; gains the Wiki Deploy Targets section)
- Artifact: `tools/verify/m043-p03-installation-anchors.sh`

## Verification

```bash
bash tools/verify/m043-p03-installation-anchors.sh
```

## Inputs

### From Previous Tasks

None — T02 is independent of T01 (disjoint files). It documents the P01/P02
surfaces but reads them only as pre-existing disk state.

### From Disk (Pre-existing)

- `references/installation.md` — the doc to extend (insert the new section
  between the `--with-` pattern's `### See also` and `## Installing via Homebrew`).
- `scripts/wiki/cloudflare-access-setup.sh` — recipe references its flags + exit
  codes (4 = Zero-Trust-off, 5 = missing-scope).
- `templates/wiki-cloudflare-deploy.yml.tmpl` — the FR-3a health-check workflow
  the recipe points to (token-scope reuse rationale).

## Constraints

- **Grep-stable anchors** — the heading texts and marker phrases the verifier
  greps MUST be byte-stable; if you reword the prose, update the verifier anchors
  in lockstep (they are co-authored in THIS task, so keep them consistent).
- **Symmetric coverage (THREAT-7)** — the Cloudflare entitlement-lapse mode is
  mandatory, not optional; the Cloudflare path must not be documented to a lower
  standard than the GitHub-Pages path.
- **No behavior change** — T02 is docs-only; it touches no scripts, templates, or
  config. Do not modify the warning emitter or any P01/P02 deliverable.
- **Single-script-file Check (AD-19)** — verifier invoked as
  `bash tools/verify/m043-p03-installation-anchors.sh`.

## Expected Output

`bash tools/verify/m043-p03-installation-anchors.sh` prints a `PASS:` line per
anchor and `SUMMARY: m043-p03-installation-anchors.sh fail=0`.
