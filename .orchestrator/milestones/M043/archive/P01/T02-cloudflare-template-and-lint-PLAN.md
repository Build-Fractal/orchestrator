---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M043"
name: "Cloudflare workflow template (FR-3/FR-3a) + wrangler/health-check lint"
depends_on: ["T01"]
---

## Prerequisites

- `tools/verify/` exists.
- The P00 findings note recorded the FR-3a probe Decision = `authenticated-edit-token` (authenticated `GET /accounts/{account_id}/access/apps` reusing `CLOUDFLARE_API_TOKEN`, no new scope) — this task encodes that probe into the template's health-check step.

## Description

Author `templates/wiki-cloudflare-deploy.yml.tmpl` — the Cloudflare Pages + Access deploy workflow. Its build steps are **identical** to the existing `pages.yml` (CON-1: only the deploy step differs), then it adds the **FR-3a pre-deploy Access health-check step** (the CON-6 every-CI-deploy enforcement site), then deploys via `npx --yes wrangler@4` (CON-2, never `cloudflare/wrangler-action`). The template uses a `__PROJECT_NAME__` placeholder that wiki-init.sh substitutes at emit time (T03).

Then author `tools/verify/m043-p01-wrangler-lint.sh` enforcing SC-2 (`npx --yes wrangler@4`; no `cloudflare/wrangler-action`) and SC-10 (health-check step precedes the deploy step) over the template (and any path passed as `$1`).

**CON-6 — do not weaken the health check.** It is the steady-state exposure guard. A reviewer must not remove it believing P02's provisioning-time ordering suffices; the two enforcement sites are distinct (the health check catches post-provisioning lapse).

## Steps

1. **Create `templates/wiki-cloudflare-deploy.yml.tmpl`** — verbatim:

   ```yaml
   name: Deploy wiki to Cloudflare Pages

   on:
     push:
       branches: [main]
     workflow_dispatch:

   permissions:
     contents: read

   concurrency:
     group: wiki-cloudflare
     cancel-in-progress: false

   jobs:
     build-and-deploy:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-python@v5
           with:
             python-version: "3.12"
             cache: pip
             cache-dependency-path: wiki/requirements.txt
         - run: pip install -r wiki/requirements.txt
         - name: Check wiki stubs are fresh (no drift vs .orchestrator/)
           run: |
             if [ -x scripts/diagnostics/wiki-stubs-fresh.sh ]; then
               bash scripts/diagnostics/wiki-stubs-fresh.sh
             else
               echo "wiki-stubs-fresh: scripts/diagnostics/wiki-stubs-fresh.sh not present -- skipping (older orchestrator runtime)"
             fi
         - name: Materialize wiki/.staged/ via decorator (or verbatim fallback)
           run: |
             if [ -f scripts/wiki/wiki-decorate-build.py ]; then
               python3 scripts/wiki/wiki-decorate-build.py --force
             else
               echo "wiki-decorate-build: not present in CI checkout -- mirroring .orchestrator/ verbatim into wiki/.staged/ (admonitions-only fallback)"
               mkdir -p wiki/.staged
               for d in memory spec decisions knowledge milestones proposals; do
                 if [ -d ".orchestrator/$d" ]; then
                   cp -R ".orchestrator/$d" "wiki/.staged/"
                 fi
               done
               for f in DECISIONS.md KNOWLEDGE.md milestone-summary.md spikes-registry.md; do
                 if [ -f ".orchestrator/$f" ]; then
                   cp ".orchestrator/$f" "wiki/.staged/"
                 fi
               done
             fi
         - run: mkdocs build -f wiki/mkdocs.yml
         # --- FR-3a / CON-6 (second enforcement site): pre-deploy Access health check ---
         # MUST run BEFORE `wrangler pages deploy` (SC-10). Re-confirms the Cloudflare
         # Access app + an active allow policy gate __PROJECT_NAME__.pages.dev, so a
         # post-provisioning Zero Trust lapse / Access-app deletion / policy removal
         # FAILS the deploy LOUDLY instead of shipping an ungated wiki on a green run
         # (the pbj-central exposure shape). Reuses the existing CLOUDFLARE_API_TOKEN
         # (Access: Apps and Policies — Edit grants read per M043 P00 #Q-5-sub); no
         # extra token scope. (If a future Cloudflare change makes Edit not grant
         # read, P04 swaps this for the unauthenticated 302->cloudflareaccess.com
         # redirect probe per AD-1 fallback.)
         - name: Verify Cloudflare Access gate (FR-3a pre-deploy health check)
           env:
             CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
             CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
           run: |
             set -eu
             DOMAIN="__PROJECT_NAME__.pages.dev"
             API="https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/access/apps"
             resp="$(curl -sS -w '\n%{http_code}' -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" "$API")"
             code="$(printf '%s' "$resp" | tail -n1)"
             body="$(printf '%s' "$resp" | sed '$d')"
             if [ "$code" != "200" ]; then
               echo "FR-3a: Cloudflare Access API returned HTTP $code (expected 200)." >&2
               echo "FR-3a: token may lack read on Access apps (see M043 P00 #Q-5-sub / AD-1 redirect-probe fallback) or Zero Trust is not enabled. Deploy ABORTED to avoid shipping an ungated wiki (CON-6)." >&2
               exit 1
             fi
             app_uid="$(printf '%s' "$body" | jq -r --arg d "$DOMAIN" '.result[] | select(.domain == $d or ((.self_hosted_domains // []) | index($d))) | .id' | head -n1)"
             if [ -z "$app_uid" ] || [ "$app_uid" = "null" ]; then
               echo "FR-3a: no Cloudflare Access application gates ${DOMAIN} — the wiki would deploy UNGATED (public)." >&2
               echo "FR-3a: run scripts/wiki/cloudflare-access-setup.sh to provision the Access app + allow policy. Deploy ABORTED (CON-6)." >&2
               exit 1
             fi
             pol="$(curl -sS -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" "${API}/${app_uid}/policies")"
             if ! printf '%s' "$pol" | jq -e '.result[] | select(.decision == "allow")' >/dev/null 2>&1; then
               echo "FR-3a: Access app ${app_uid} for ${DOMAIN} has no active allow policy. Deploy ABORTED (CON-6)." >&2
               exit 1
             fi
             echo "FR-3a: Access gate present for ${DOMAIN} (app ${app_uid}, allow policy active)."
         - name: Deploy to Cloudflare Pages (private — gated by Cloudflare Access)
           # npx (not cloudflare/wrangler-action): the action auto-detects bun from
           # the app repo and fails on a clean runner. (CON-2; SC-2 lint enforces.)
           run: npx --yes wrangler@4 pages deploy wiki/site --project-name=__PROJECT_NAME__ --branch=main --commit-dirty=true
           env:
             CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
             CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
   ```

2. **Create `tools/verify/m043-p01-wrangler-lint.sh`** — verbatim:

   ```bash
   #!/usr/bin/env bash
   # m043-p01-wrangler-lint.sh — SC-2 (npx wrangler@4, no wrangler-action) +
   # SC-10 (FR-3a health check precedes deploy) over a Cloudflare workflow file.
   # Usage: m043-p01-wrangler-lint.sh [<workflow-or-template-path>]
   #        defaults to templates/wiki-cloudflare-deploy.yml.tmpl
   set -u

   TARGET="${1:-templates/wiki-cloudflare-deploy.yml.tmpl}"
   fail=0
   check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

   test -f "$TARGET"
   check "workflow file exists: $TARGET" $?
   if [ ! -f "$TARGET" ]; then
     echo "SUMMARY: m043-p01-wrangler-lint.sh pass=0 fail=1"; exit 1
   fi

   grep -q "npx --yes wrangler@4" "$TARGET"
   check "SC-2: deploys via npx --yes wrangler@4" $?

   if grep -q "cloudflare/wrangler-action" "$TARGET"; then
     check "SC-2: contains no cloudflare/wrangler-action" 1
   else
     check "SC-2: contains no cloudflare/wrangler-action" 0
   fi

   # SC-10: the FR-3a health-check step line precedes the wrangler deploy line.
   hc_line="$(grep -n "Verify Cloudflare Access gate" "$TARGET" | head -n1 | cut -d: -f1)"
   dep_line="$(grep -n "wrangler@4 pages deploy" "$TARGET" | head -n1 | cut -d: -f1)"
   if [ -n "$hc_line" ] && [ -n "$dep_line" ] && [ "$hc_line" -lt "$dep_line" ]; then
     check "SC-10: FR-3a health check (line $hc_line) precedes deploy (line $dep_line)" 0
   else
     check "SC-10: FR-3a health check precedes deploy (hc=$hc_line dep=$dep_line)" 1
   fi

   if [ "$fail" -eq 0 ]; then echo "SUMMARY: m043-p01-wrangler-lint.sh pass=ALL fail=0"; exit 0; fi
   echo "SUMMARY: m043-p01-wrangler-lint.sh pass=SOME fail=1"; exit 1
   ```

3. **`chmod +x tools/verify/m043-p01-wrangler-lint.sh`** (single command).

4. Run the verification block; confirm all exit 0.

## Must-Haves

- `wiki-cloudflare-deploy.yml.tmpl`: build steps == pages.yml, FR-3a health check before deploy, deploy via npx wrangler@4, no wrangler-action.
- `m043-p01-wrangler-lint.sh`: enforces SC-2 + SC-10.

## Verification

- `bash tools/verify/m043-p01-wrangler-lint.sh`
- `grep -q "npx --yes wrangler@4" templates/wiki-cloudflare-deploy.yml.tmpl`
- `grep -q "Verify Cloudflare Access gate" templates/wiki-cloudflare-deploy.yml.tmpl`

## Notes

The template's build steps are intentionally byte-for-byte the same shape as the `pages.yml` heredoc in `scripts/lifecycle/wiki-init.sh` (checkout → setup-python → pip → stubs-fresh → materialize → mkdocs build), satisfying CON-1 "only the deploy step differs." `jq` and `curl` are preinstalled on GitHub `ubuntu-latest` runners. The `__PROJECT_NAME__` placeholder is substituted by T03's `emit_cloudflare_workflow` (via `sed`). Expected lint output: `SUMMARY: m043-p01-wrangler-lint.sh pass=ALL fail=0`.

## Inputs

### From Previous Tasks

- (T01) `scripts/wiki/resolve-deploy-target.sh` exists but is not read by this task — the template is static.

### From Disk (Pre-existing)

- `scripts/lifecycle/wiki-init.sh` `emit_pages_workflow` heredoc (lines ~538–620) — the reference for the identical build-step block (CON-1). Match its step shape so the only difference is the deploy + health-check steps.

## Constraints

- **CON-2**: deploy via `npx --yes wrangler@4`, never `cloudflare/wrangler-action`. Enforced by the lint.
- **CON-1**: build steps identical to pages.yml; only the deploy step (and the new FR-3a health check) differ.
- **CON-6 / FR-3a / SC-10**: the health-check step MUST exist and precede the deploy step. Do not remove or reorder it.
- **Project-owned verifier under `tools/verify/`**, milestone-slug-prefixed.
- Bash shape-guard (AP-009): single commands only at the shell; verifier-internal logic is fine.

## Expected Output

`templates/wiki-cloudflare-deploy.yml.tmpl` + `tools/verify/m043-p01-wrangler-lint.sh` (executable). The lint exits 0 with `pass=ALL fail=0`.
