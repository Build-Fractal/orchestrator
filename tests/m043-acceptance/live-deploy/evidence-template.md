---
schema_version: "1.0"
type: live-deploy-evidence
report_date: "YYYY-MM-DD"
# --- SC-9 triad (set all three to "yes" for a completed live pass) ---
redirect_verified: "no"      # 302 -> *.cloudflareaccess.com on the live URL
ci_green: "no"               # wiki-cloudflare.yml workflow run went green
giscus_working: "no"         # a giscus comment posted and persisted
# --- P00 forward-pointed API confirmations (informational) ---
edit_scope_grants_read: "unconfirmed"   # #Q-5: GET access/apps with Edit-only token -> 200?
error_envelopes_match: "unconfirmed"    # #Q-6: 400/12130 vs 403/9109 confirmed?
# --- deferred path (set both to close at shippable scope without a live run) ---
deferred_validation: "no"    # "yes" forward-points the live pass
signed_by: ""                # maintainer handle (required when deferred_validation: yes)
---

# M043 Live-Deploy Evidence Note

<!--
  Fill this note after walking `protocol.md`. There are two valid closing
  paths under SC-9; record exactly one:

  (a) Completed live pass — set the SC-9 triad all to "yes":
        redirect_verified: "yes"
        ci_green:          "yes"
        giscus_working:    "yes"
      and fill the Capture sections below with the real observations.

  (b) Signed deferred-validation note — the live pass is forward-pointed
      because no Cloudflare account is available. Set:
        deferred_validation: "yes"
        signed_by:           "<maintainer handle>"
      and fill the Deferred-Validation Acknowledgment section. The triad
      fields stay "no"; this does NOT claim the live deploy happened.

  Then run the gate:
    bash tests/m043-acceptance/live-deploy/validate-evidence.sh <this-file>
  It exits 0 iff path (a) or path (b) is satisfied. Anything else exits 1.
-->

## Environment

- Cloudflare account: <account / org name>
- Pages project name (`wiki.cloudflare.project_name`): <name>
- Test repo (private): <owner/repo>
- Token scopes used: `Access: Apps and Policies — Edit` + `Pages — Edit` +
  `Account Settings — Read` (no extra Read scope)

## Capture 1 — 302 redirect gate

Paste the `curl -sI https://<name>.pages.dev` status line + `location:`
header (expect `302` → `*.cloudflareaccess.com`):

```
<paste here>
```

## Capture 2 — green CI run

Workflow-run URL for the green `wiki-cloudflare.yml` run:

- <url>

## Capture 3 — giscus comment

Confirmation the comment posted and persisted (allowed-domain user) + link:

- <link / note>

## Capture 4 — #Q-5 Edit-scope-grants-read

Result of `GET /accounts/{id}/access/apps` with the Edit-only token —
`200` + app list, or `403` + the recorded redirect-fallback note:

```
<paste here>
```

## Capture 5 — #Q-6 error envelopes

Observed Zero-Trust-off (expect HTTP 400 / code 12130) and missing-scope
(expect HTTP 403 / code 9109) envelopes; note whether they stayed
distinguishable on `(HTTP status, errors[].code)`:

```
<paste here>
```

## Deferred-Validation Acknowledgment (if applicable)

Fill this only when forward-pointing the live pass (path (b)):

- Reason the live pass is deferred: <e.g. no Cloudflare account available>
- Forward-pointer: `tests/m043-acceptance/live-deploy/protocol.md`
- Signer (the operator who authorized closing at shippable scope): see
  `signed_by` in the frontmatter.

## Maintainer Sign-Off

- Recorded by: <handle>
- Date: <YYYY-MM-DD>
