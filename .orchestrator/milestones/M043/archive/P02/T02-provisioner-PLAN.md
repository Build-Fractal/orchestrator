---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M043"
name: "The idempotent Cloudflare provisioner script"
depends_on: ["T01"]
---

## Prerequisites

T01 is complete: the recorded-API fixtures + the fixture-replay contract exist
under `tests/fixtures/m043-cloudflare/` (verified by
`bash tools/verify/m043-p02-fixtures-shape.sh` exiting 0). This task implements
the provisioner **against that contract** — the endpoint keys, the
`<ENDPOINT_KEY>.response.json` response files, the `_http_status` envelope field,
and the `M043_CF_FIXTURE_DIR` / `M043_CF_CAPTURE_DIR` env vars are all defined in
`tests/fixtures/m043-cloudflare/README.md`.

`wiki-init.sh` already invokes this script — read
`scripts/lifecycle/wiki-init.sh` lines ~1146-1163: the `--deploy cloudflare-access`
branch calls `bash "$CF_SETUP" --project-dir "$PROJECT_DIR"` and treats a non-zero
exit as fatal (exit 14). So the provisioner MUST accept `--project-dir DIR` and
resolve `wiki.cloudflare.project_name` + `wiki.cloudflare.allowed_email_domains`
from `<DIR>/.orchestrator/config.yml`.

`jq` (`/usr/bin/jq`) and `curl` (`/usr/bin/curl`) are on the path.

## Description

Author `scripts/wiki/cloudflare-access-setup.sh`: an idempotent Cloudflare
provisioner (FR-6..FR-9, CON-5, CON-6 provisioning-time site, CON-7). It
provisions, in order, a Pages project → an Access self-hosted app gating both
`<name>.pages.dev` (apex) and `*.<name>.pages.dev` (wildcard) → an allow policy
keyed on the supplied email domains. Re-running is a no-op for already-present
resources. When Zero Trust is off or the token is under-scoped, it emits an
actionable diagnostic and exits non-zero **before any deploy is possible**.

All HTTP flows through one `cf_api` transport function with a fixture-replay mode,
so the whole script is verifiable against T01's fixtures with no live account.

Also co-author the static `tools/verify/m043-p02-provisioner-shape.sh` verifier
(Plan-Time Discipline rule 2: co-author the verifier alongside its deliverable).

### Design notes (read before writing)

- **No subshell global-loss.** `cf_api` is always called **directly** (never in
  `$( ... )`), because it sets globals (`CF_HTTP_STATUS`) and writes the response
  body to `$CF_LAST_BODY_FILE`. Command-substitution would run the function in a
  subshell and lose the globals. Callers read `$CF_HTTP_STATUS` and
  `$CF_LAST_BODY_FILE` after each `cf_api` call.
- **FR-9 / P00 #Q-6 = `distinguishable`.** Branch the diagnostic on
  `(HTTP status, errors[0].code)`: a `403`/`9109`/`10000` is the missing-scope
  (authorization) failure; an `access.api.error.*` namespace code (e.g. `12130`)
  at a non-403 status, or a zero-trust message match, is the Zero-Trust-not-enabled
  failure. **P00 contingency:** keep these two branches isolated inside
  `emit_provision_diagnostic` so that if a P04 live capture shows the two
  conditions collapse to one envelope, replacing them with a single combined
  diagnostic is a one-line change, not a redesign (record this in a code comment).
- **CON-5 Bash 3.2.** No `declare -A`, no process substitution `<( )` / `>( )`.
  Pipes (`|`) and redirects (`>`) in the script body are fine. (The harness
  shape-guard only governs inline `Check:` commands, not script internals.)

## Steps

1. Author `scripts/wiki/cloudflare-access-setup.sh` with the verbatim content
   below.
2. Author `tools/verify/m043-p02-provisioner-shape.sh` with the verbatim content
   below.
3. Run the verification command.

### Verbatim script: `scripts/wiki/cloudflare-access-setup.sh`
```bash
#!/usr/bin/env bash
# scripts/wiki/cloudflare-access-setup.sh — M043 P02 idempotent Cloudflare
# provisioner (US-2 / FR-6..FR-9). Provisions, in order:
#   1. a Cloudflare Pages project
#   2. a Cloudflare Access self-hosted application gating <name>.pages.dev AND
#      *.<name>.pages.dev (apex + wildcard)
#   3. an Access allow policy keyed on the supplied email domains
# Re-running is a no-op for already-present resources (FR-7). The Access app +
# policy are created before any deploy is possible (FR-8 / CON-6 provisioning-
# time enforcement site). When Zero Trust is not enabled, or the token lacks the
# Access scope, it emits an actionable diagnostic and exits non-zero before any
# content can be exposed (FR-9).
#
# CON-6: this is ONE of two exposure-guard enforcement sites. The other is the
# FR-3a pre-deploy health check emitted into wiki-cloudflare.yml (M043 P01).
# Removing either reopens the exposure window.
#
# Bash 3.2 / POSIX-sh: no `declare -A`, no process substitution.
#
# Inputs (flag overrides env overrides config):
#   --project-dir DIR    read <DIR>/.orchestrator/config.yml wiki.cloudflare.*
#   --project-name NAME  Cloudflare Pages project (site is NAME.pages.dev)
#   --account-id ID      Cloudflare account id (else $CLOUDFLARE_ACCOUNT_ID)
#   --token TOKEN        Cloudflare API token (else $CLOUDFLARE_API_TOKEN)
#   --domains "a,b"      comma/space-separated allow-list email domains
#   --help
#
# Test seam (no live account): set M043_CF_FIXTURE_DIR=<scenario-dir> to replay
# recorded responses; set M043_CF_CAPTURE_DIR=<dir> to record requests.
#
# Exit codes: 0 ok/idempotent; 2 usage; 3 missing input; 4 Zero-Trust-not-enabled;
#   5 token-missing-scope; 6 other Cloudflare API error.
set -u

CF_API_BASE="${CF_API_BASE:-https://api.cloudflare.com/client/v4}"

usage() {
  cat <<'USAGE'
Usage: bash scripts/wiki/cloudflare-access-setup.sh [--project-dir DIR]
         [--project-name NAME] [--account-id ID] [--token TOKEN]
         [--domains "a.com,b.com"]

Provisions (idempotently, in order) a Cloudflare Pages project, an Access
self-hosted app gating NAME.pages.dev + *.NAME.pages.dev, and an allow policy
keyed on the email domains. Fails loudly before any deploy if Zero Trust is not
enabled or the token is under-scoped.
USAGE
}

# -------- flag parsing (Bash 3.2 safe) --------
PROJECT_DIR=""; ARG_PROJECT_NAME=""; ARG_ACCOUNT_ID=""; ARG_TOKEN=""; ARG_DOMAINS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir)  PROJECT_DIR="${2:-}"; shift ;;
    --project-name) ARG_PROJECT_NAME="${2:-}"; shift ;;
    --account-id)   ARG_ACCOUNT_ID="${2:-}"; shift ;;
    --token)        ARG_TOKEN="${2:-}"; shift ;;
    --domains)      ARG_DOMAINS="${2:-}"; shift ;;
    --help|-h)      usage; exit 0 ;;
    *) printf 'ERROR: unknown flag: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# -------- config parse from --project-dir (wiki.cloudflare.*) --------
CFG_PROJECT_NAME=""; CFG_DOMAINS=""
parse_cloudflare_config() {
  _cfg="$1"
  [ -f "$_cfg" ] || return 0
  CFG_PROJECT_NAME="$(awk '
    BEGIN{inw=0;incf=0}
    /^wiki:[[:space:]]*$/{inw=1;next}
    inw && /^[^[:space:]]/{exit}
    inw && /^[[:space:]][[:space:]]cloudflare:[[:space:]]*$/{incf=1;next}
    inw && incf && /^[[:space:]][[:space:]][^[:space:]]/{exit}
    incf && /^[[:space:]][[:space:]][[:space:]][[:space:]]project_name:/{
      line=$0; sub(/^[[:space:]]*project_name:[[:space:]]*/,"",line);
      sub(/[[:space:]]*#.*$/,"",line); gsub(/"/,"",line);
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",line); print line; exit }
  ' "$_cfg" 2>/dev/null || true)"
  CFG_DOMAINS="$(awk '
    BEGIN{inw=0;incf=0;indl=0}
    /^wiki:[[:space:]]*$/{inw=1;next}
    inw && /^[^[:space:]]/{exit}
    inw && /^[[:space:]][[:space:]]cloudflare:[[:space:]]*$/{incf=1;next}
    inw && incf && /^[[:space:]][[:space:]][^[:space:]]/{exit}
    incf && /^[[:space:]][[:space:]][[:space:]][[:space:]]allowed_email_domains:/{indl=1;next}
    incf && indl && /^[[:space:]][[:space:]][[:space:]][[:space:]][[:space:]][[:space:]]-[[:space:]]/{
      line=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",line);
      sub(/[[:space:]]*#.*$/,"",line); gsub(/"/,"",line);
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",line); printf "%s ", line; next }
    incf && indl && /^[[:space:]][[:space:]][[:space:]][[:space:]][^[:space:]-]/{indl=0}
  ' "$_cfg" 2>/dev/null || true)"
}
if [ -n "$PROJECT_DIR" ]; then
  parse_cloudflare_config "$PROJECT_DIR/.orchestrator/config.yml"
fi

# -------- resolve effective inputs --------
CF_PROJECT_NAME="${ARG_PROJECT_NAME:-$CFG_PROJECT_NAME}"
CF_ACCOUNT_ID="${ARG_ACCOUNT_ID:-${CLOUDFLARE_ACCOUNT_ID:-}}"
CF_TOKEN="${ARG_TOKEN:-${CLOUDFLARE_API_TOKEN:-}}"
_domains_raw="${ARG_DOMAINS:-$CFG_DOMAINS}"
CF_DOMAINS="$(printf '%s' "$_domains_raw" | tr ',' ' ' | tr -s ' ' | sed 's/^ //; s/ $//')"

FIXTURE="${M043_CF_FIXTURE_DIR:-}"

# -------- required-input checks --------
if [ -z "$CF_PROJECT_NAME" ]; then
  echo "FAIL: cloudflare-access-setup: project name required (--project-name or wiki.cloudflare.project_name in config)." >&2
  exit 3
fi
if [ -z "$CF_DOMAINS" ]; then
  echo "FAIL: cloudflare-access-setup: at least one allow-list email domain required (--domains or wiki.cloudflare.allowed_email_domains)." >&2
  echo "NOTE (CON-7): the domain list gates the Access allow policy; an empty list would lock every user out." >&2
  exit 3
fi
if [ -z "$FIXTURE" ]; then
  command -v jq >/dev/null 2>&1 || { echo "FAIL: cloudflare-access-setup: jq is required." >&2; exit 3; }
  command -v curl >/dev/null 2>&1 || { echo "FAIL: cloudflare-access-setup: curl is required." >&2; exit 3; }
  if [ -z "$CF_ACCOUNT_ID" ]; then echo "FAIL: cloudflare-access-setup: CLOUDFLARE_ACCOUNT_ID (or --account-id) required." >&2; exit 3; fi
  if [ -z "$CF_TOKEN" ]; then echo "FAIL: cloudflare-access-setup: CLOUDFLARE_API_TOKEN (or --token) required." >&2; exit 3; fi
fi

# -------- temp files --------
CF_LAST_BODY_FILE="$(mktemp 2>/dev/null || echo "/tmp/cf_body.$$")"
CF_REQ_TMP="$(mktemp 2>/dev/null || echo "/tmp/cf_req.$$")"
trap 'rm -f "$CF_LAST_BODY_FILE" "$CF_REQ_TMP"' EXIT

# -------- transport seam --------
CF_HTTP_STATUS=""
CF_APP_UID=""

cf_real_url() {
  case "$1" in
    pages-project-get)    printf '%s/accounts/%s/pages/projects/%s' "$CF_API_BASE" "$CF_ACCOUNT_ID" "$CF_PROJECT_NAME" ;;
    pages-project-create) printf '%s/accounts/%s/pages/projects' "$CF_API_BASE" "$CF_ACCOUNT_ID" ;;
    access-apps-list)     printf '%s/accounts/%s/access/apps' "$CF_API_BASE" "$CF_ACCOUNT_ID" ;;
    access-app-create)    printf '%s/accounts/%s/access/apps' "$CF_API_BASE" "$CF_ACCOUNT_ID" ;;
    access-policies-list) printf '%s/accounts/%s/access/apps/%s/policies' "$CF_API_BASE" "$CF_ACCOUNT_ID" "$CF_APP_UID" ;;
    access-policy-create) printf '%s/accounts/%s/access/apps/%s/policies' "$CF_API_BASE" "$CF_ACCOUNT_ID" "$CF_APP_UID" ;;
  esac
}

# cf_api METHOD ENDPOINT_KEY [REQUEST_BODY_FILE]
# Always call DIRECTLY (never in $()). Sets CF_HTTP_STATUS; writes the response
# body to $CF_LAST_BODY_FILE.
cf_api() {
  _method="$1"; _key="$2"; _body="${3:-}"
  CF_HTTP_STATUS=""
  : > "$CF_LAST_BODY_FILE"

  if [ -n "$FIXTURE" ]; then
    if [ -n "${M043_CF_CAPTURE_DIR:-}" ]; then
      mkdir -p "$M043_CF_CAPTURE_DIR"
      printf '%s %s\n' "$_method" "$_key" >> "$M043_CF_CAPTURE_DIR/requests.log"
      if [ -n "$_body" ] && [ -f "$_body" ]; then
        cp "$_body" "$M043_CF_CAPTURE_DIR/$_key.request.json"
      fi
    fi
    _rf="$FIXTURE/$_key.response.json"
    if [ ! -f "$_rf" ]; then
      echo "cloudflare-access-setup: fixture missing: $_rf (provisioner reached an unexpected call for this scenario)." >&2
      CF_HTTP_STATUS="000"
      return 0
    fi
    CF_HTTP_STATUS="$(jq -r '._http_status // "200"' "$_rf" 2>/dev/null)"
    cp "$_rf" "$CF_LAST_BODY_FILE"
    return 0
  fi

  _url="$(cf_real_url "$_key")"
  if [ "$_method" = "GET" ]; then
    _resp="$(curl -sS -w '\n%{http_code}' -H "Authorization: Bearer ${CF_TOKEN}" "$_url")"
  else
    _resp="$(curl -sS -w '\n%{http_code}' -X "$_method" \
      -H "Authorization: Bearer ${CF_TOKEN}" -H 'Content-Type: application/json' \
      --data @"$_body" "$_url")"
  fi
  CF_HTTP_STATUS="$(printf '%s' "$_resp" | tail -n1)"
  printf '%s' "$_resp" | sed '$d' > "$CF_LAST_BODY_FILE"
  return 0
}

# -------- FR-9 diagnostic (distinguishable per P00 #Q-6) --------
# CONTINGENCY (P00 #Q-6): if a P04 live capture shows Zero-Trust-not-enabled and
# token-missing-scope collapse to one envelope, replace the two branches below
# with a single combined diagnostic — a one-line change, SC-5 is then satisfied
# by the combined shape.
emit_provision_diagnostic() {
  _st="$1"
  _code="$(jq -r '.errors[0].code // empty' "$CF_LAST_BODY_FILE" 2>/dev/null)"
  _msg="$(jq -r '.errors[0].message // empty' "$CF_LAST_BODY_FILE" 2>/dev/null)"

  # missing-scope: authorization failure (HTTP 403 / 9109 / 10000)
  if [ "$_st" = "403" ] || [ "$_code" = "9109" ] || [ "$_code" = "10000" ]; then
    echo "FAIL: cloudflare-access-setup: the API token is missing the 'Access: Apps and Policies — Edit' permission (HTTP $_st, code ${_code:-?})." >&2
    echo "FIX: add the 'Access: Apps and Policies — Edit' scope to the token (Cloudflare dashboard > My Profile > API Tokens), store it as the CLOUDFLARE_API_TOKEN repo secret, then re-run." >&2
    return 5
  fi

  # zero-trust-not-enabled: access.api.error.* namespace (non-403) or message match
  _zt=0
  case "$_code" in 12130|121[0-9][0-9]|122[0-9][0-9]) _zt=1 ;; esac
  if [ "$_zt" = "0" ]; then
    if printf '%s' "$_msg" | grep -qi 'zero trust\|not enabled\|not onboarded\|onboarding'; then _zt=1; fi
  fi
  if [ "$_zt" = "1" ]; then
    echo "FAIL: cloudflare-access-setup: Cloudflare Zero Trust / Access is not enabled on this account (HTTP $_st, code ${_code:-?})." >&2
    echo "FIX: complete the one-time Zero Trust onboarding in the Cloudflare dashboard (Zero Trust > Settings) — this cannot be triggered via the API — then re-run. No Access app can be provisioned until it is done." >&2
    if [ -n "$_msg" ]; then echo "API said: $_msg" >&2; fi
    return 4
  fi

  echo "FAIL: cloudflare-access-setup: unexpected Cloudflare API error (HTTP $_st, code ${_code:-?}): ${_msg:-no message}." >&2
  return 6
}

# -------- policy body builder (one include rule per domain) --------
build_policy_body() {
  _out="$1"
  _inc="$(printf '%s\n' $CF_DOMAINS | jq -R '{email_domain:{domain:.}}' | jq -s '.')"
  jq -n --arg name "Allow $CF_DOMAINS" --argjson inc "$_inc" \
    '{name:$name,decision:"allow",include:$inc,require:[],exclude:[]}' > "$_out"
}

DOMAIN="$CF_PROJECT_NAME.pages.dev"

# ===== 1. Pages project (create if absent) =====
cf_api GET pages-project-get
if [ "$CF_HTTP_STATUS" = "200" ]; then
  echo "ok: Pages project '$CF_PROJECT_NAME' already exists (skip create)."
else
  printf '{"name":"%s","production_branch":"main"}\n' "$CF_PROJECT_NAME" > "$CF_REQ_TMP"
  cf_api POST pages-project-create "$CF_REQ_TMP"
  if [ "$CF_HTTP_STATUS" != "200" ] && [ "$CF_HTTP_STATUS" != "201" ]; then
    emit_provision_diagnostic "$CF_HTTP_STATUS"; exit $?
  fi
  echo "created: Pages project '$CF_PROJECT_NAME'."
fi

# ===== 2. Access self-hosted app (apex + wildcard; create if absent) =====
cf_api GET access-apps-list
if [ "$CF_HTTP_STATUS" != "200" ]; then
  emit_provision_diagnostic "$CF_HTTP_STATUS"; exit $?
fi
CF_APP_UID="$(jq -r --arg d "$DOMAIN" '.result[]? | select(.domain == $d or ((.self_hosted_domains // []) | index($d))) | .id' "$CF_LAST_BODY_FILE" 2>/dev/null | head -n1)"
if [ -n "$CF_APP_UID" ] && [ "$CF_APP_UID" != "null" ]; then
  echo "ok: Access app for $DOMAIN already exists (uid $CF_APP_UID, skip create)."
else
  jq -n --arg name "$CF_PROJECT_NAME wiki (Access-gated)" --arg apex "$DOMAIN" --arg wc "*.$DOMAIN" \
    '{name:$name,type:"self_hosted",session_duration:"24h",self_hosted_domains:[$apex,$wc],app_launcher_visible:false,auto_redirect_to_identity:false}' > "$CF_REQ_TMP"
  cf_api POST access-app-create "$CF_REQ_TMP"
  if [ "$CF_HTTP_STATUS" != "200" ] && [ "$CF_HTTP_STATUS" != "201" ]; then
    emit_provision_diagnostic "$CF_HTTP_STATUS"; exit $?
  fi
  CF_APP_UID="$(jq -r '.result.id // empty' "$CF_LAST_BODY_FILE" 2>/dev/null)"
  echo "created: Access app for $DOMAIN (uid ${CF_APP_UID:-?}, apex+wildcard)."
fi

# ===== 3. Allow policy (create if absent) =====
cf_api GET access-policies-list
if [ "$CF_HTTP_STATUS" != "200" ]; then
  emit_provision_diagnostic "$CF_HTTP_STATUS"; exit $?
fi
if jq -e '.result[]? | select(.decision == "allow")' "$CF_LAST_BODY_FILE" >/dev/null 2>&1; then
  echo "ok: allow policy already present on app ${CF_APP_UID:-?} (skip create)."
else
  build_policy_body "$CF_REQ_TMP"
  cf_api POST access-policy-create "$CF_REQ_TMP"
  if [ "$CF_HTTP_STATUS" != "200" ] && [ "$CF_HTTP_STATUS" != "201" ]; then
    emit_provision_diagnostic "$CF_HTTP_STATUS"; exit $?
  fi
  echo "created: allow policy on app ${CF_APP_UID:-?} for domains: $CF_DOMAINS."
fi

echo "OK: cloudflare-access-setup complete for $DOMAIN. The Access gate is in place BEFORE any deploy (FR-8 / CON-6 provisioning-time enforcement)."
exit 0
```

### Verbatim verifier: `tools/verify/m043-p02-provisioner-shape.sh`
```bash
#!/usr/bin/env bash
# m043-p02-provisioner-shape.sh — static checks on cloudflare-access-setup.sh:
# exists, Bash 3.2 (no declare -A / process substitution), single cf_api seam,
# create-order endpoint keys, FR-9 diagnostic branch, apex+wildcard. Tier 1.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
S="scripts/wiki/cloudflare-access-setup.sh"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

test -f "$S"
check "provisioner exists" $?
grep -q 'cf_api' "$S"
check "cf_api transport seam present" $?
grep -q 'M043_CF_FIXTURE_DIR' "$S"
check "fixture-replay mode wired" $?
grep -q 'emit_provision_diagnostic' "$S"
check "FR-9 diagnostic function present" $?
grep -q 'self_hosted_domains' "$S"
check "apex+wildcard self_hosted_domains constructed" $?
grep -q 'pages-project-create' "$S"
check "pages-project-create endpoint key present" $?
grep -q 'access-app-create' "$S"
check "access-app-create endpoint key present" $?
grep -q 'access-policy-create' "$S"
check "access-policy-create endpoint key present" $?
# CON-5 Bash 3.2 compliance
if grep -q 'declare -A' "$S"; then check "no declare -A (CON-5)" 1; else check "no declare -A (CON-5)" 0; fi
if grep -Eq '<\(|>\(' "$S"; then check "no process substitution (CON-5)" 1; else check "no process substitution (CON-5)" 0; fi

echo "SUMMARY: m043-p02-provisioner-shape.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

## Must-Haves

- `scripts/wiki/cloudflare-access-setup.sh` exists, is Bash 3.2 compliant, routes
  all HTTP through `cf_api`, and declares the create order Pages → app → policy
  (phase Truth 2 / Artifact).
- The provisioner constructs the Access app with BOTH apex and wildcard
  `self_hosted_domains` (feeds phase Truth 3, verified behaviorally in T03).
- The FR-9 diagnostic branch distinguishes Zero-Trust-not-enabled (exit 4) from
  missing-scope (exit 5) (feeds phase Truth 5, verified behaviorally in T03).

## Verification

`bash tools/verify/m043-p02-provisioner-shape.sh`

`bash tools/verify/m043-p02-fixtures-shape.sh`

## Inputs

### From Previous Tasks

- `tests/fixtures/m043-cloudflare/README.md` (from T01)
  - Key contract: `cf_api <METHOD> <ENDPOINT_KEY> [REQUEST_BODY_FILE]`; the six
    endpoint keys (`pages-project-get`, `pages-project-create`, `access-apps-list`,
    `access-app-create`, `access-policies-list`, `access-policy-create`); fixture
    response files `<ENDPOINT_KEY>.response.json` carry a top-level `_http_status`
    string; `M043_CF_FIXTURE_DIR` selects the scenario dir; `M043_CF_CAPTURE_DIR`
    receives `requests.log` (one `<METHOD> <ENDPOINT_KEY>` line per call) and
    `<ENDPOINT_KEY>.request.json` (the create-call body).
- `tests/fixtures/m043-cloudflare/<scenario>/*.response.json` (from T01) — the
  canned responses `cf_api` replays. The error scenarios surface their non-200
  envelope on `access-apps-list`.

### From Disk (Pre-existing)

- `scripts/lifecycle/wiki-init.sh` (~line 1155) — invokes
  `bash "$CF_SETUP" --project-dir "$PROJECT_DIR"`. The provisioner's
  `--project-dir` flag + config parse must satisfy this contract.
- `templates/orchestrator-config-default.yml` (~lines 246-259) — the
  `wiki.cloudflare.project_name` + `allowed_email_domains` shape the
  `parse_cloudflare_config` awk reads (top-level `wiki:` → 2-space `cloudflare:`
  → 4-space `project_name:` / `allowed_email_domains:` → 6-space `- domain`).
- `templates/wiki-cloudflare-deploy.yml.tmpl` (lines 78-88) — the FR-3a health
  check's app-match jq (`.domain == $d or (.self_hosted_domains | index($d))`)
  and policy-match jq (`.decision == "allow"`); the provisioner reuses the same
  match shapes for idempotency so the two CON-6 sites agree on "present".

## Constraints

- **CON-5**: Bash 3.2 — no `declare -A`, no process substitution. `cf_api` must be
  called directly (never in `$( )`), or its globals are lost to the subshell.
- **CON-6**: this is the provisioning-time enforcement site — the Access app +
  allow policy are confirmed before the script reports success; it must never
  print the final `OK:` line if the Access step failed.
- **CON-7**: an empty domain list is a lockout event — the script refuses to run
  with no domains (exit 3).
- **FR-9 contingency**: keep the two diagnostic branches isolated so a collapse to
  a combined diagnostic is a one-line change (comment in place).
- Path discipline: provisioner is framework-owned wiki tooling →
  `scripts/wiki/cloudflare-access-setup.sh`; the verifier is project-owned,
  milestone-prefixed → `tools/verify/m043-p02-provisioner-shape.sh`.

## Expected Output

`bash tools/verify/m043-p02-provisioner-shape.sh` prints `PASS:` lines and
`SUMMARY: m043-p02-provisioner-shape.sh fail=0`, exiting 0.
`bash tools/verify/m043-p02-fixtures-shape.sh` (from T01) continues to exit 0.
