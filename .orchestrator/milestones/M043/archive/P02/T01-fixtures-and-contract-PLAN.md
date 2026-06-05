---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M043"
name: "Promote P00 seeds into recorded-API fixtures + define the fixture-replay contract"
depends_on: []
---

## Prerequisites

The five P00 doc-derived seed files exist on disk (verified at plan-authoring time):

- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/pages-project-create-request.json`
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/access-app-create-request.json`
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/access-policy-create-request.json`
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/zero-trust-not-enabled-response.json`
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/missing-scope-response.json`

`jq` is available on the dev/runner path (`/usr/bin/jq`). No live Cloudflare
credentials are needed for this task — it writes static fixture files only.

## Description

The P02 provisioner (`cloudflare-access-setup.sh`, authored in T02) makes a
sequence of Cloudflare API calls. To verify it against recorded-API fixtures
(SC-3 / SC-4 / SC-5) without a live account, the provisioner routes ALL HTTP
through one internal transport function, `cf_api`, that has a **fixture-replay
mode**: when `M043_CF_FIXTURE_DIR` is set, `cf_api` returns canned responses
from that directory and records each request into a capture directory instead of
calling the network.

This task creates the recorded-API fixtures and the README that **defines that
contract** — it is the seam T02 builds against. It also authors the
`m043-p02-fixtures-shape.sh` verifier that asserts the fixture tree is
well-formed.

### The fixture-replay contract (authoritative — T02 implements exactly this)

`cf_api <METHOD> <ENDPOINT_KEY> [REQUEST_BODY_FILE]`

- `ENDPOINT_KEY` is a stable logical token chosen by the provisioner (NOT derived
  from a URL). The six keys, and the real Cloudflare endpoint each maps to:

  | ENDPOINT_KEY | METHOD | Real endpoint |
  | --- | --- | --- |
  | `pages-project-get` | GET | `/accounts/{acct}/pages/projects/{name}` |
  | `pages-project-create` | POST | `/accounts/{acct}/pages/projects` |
  | `access-apps-list` | GET | `/accounts/{acct}/access/apps` |
  | `access-app-create` | POST | `/accounts/{acct}/access/apps` |
  | `access-policies-list` | GET | `/accounts/{acct}/access/apps/{uid}/policies` |
  | `access-policy-create` | POST | `/accounts/{acct}/access/apps/{uid}/policies` |

- **Response files**: in fixture mode, `cf_api` reads
  `$M043_CF_FIXTURE_DIR/<ENDPOINT_KEY>.response.json`. Each response file is the
  Cloudflare `{success, errors, messages, result}` envelope with an added
  top-level `_http_status` string field (the HTTP status is not part of the JSON
  body; it is carried here so the provisioner and the verifiers can branch on it).
  `cf_api` strips `_http_status` into a global the caller reads and prints the
  remaining envelope to stdout.

- **Request capture**: when `M043_CF_CAPTURE_DIR` is set, `cf_api` appends one
  line `<METHOD> <ENDPOINT_KEY>` to `$M043_CF_CAPTURE_DIR/requests.log` for every
  call (order + idempotency assertions), and when `REQUEST_BODY_FILE` is given it
  copies that body to `$M043_CF_CAPTURE_DIR/<ENDPOINT_KEY>.request.json` (payload
  assertions, e.g. SC-3 apex+wildcard).

- **Error-scenario call site**: both error fixtures surface their non-200 envelope
  on **`access-apps-list`** — the FIRST Access API call. This gives the provisioner
  a single, well-defined diagnostic check point right after the first Access call.
  (P00's seeds were captured as create-call envelopes; the same envelope applies to
  the list call on a not-onboarded / under-scoped account. This is doc-derived and
  forward-pointed to P04 live confirmation — documented in the fixture README.)

### Scenario → call-sequence map (what each fixture must drive)

- **clean-account** (SC-3): project absent → created; app absent → created; policy
  absent → created. Drives the full six-call create path.
  - `pages-project-get` → 404 (absent) → provisioner creates
  - `pages-project-create` → 200
  - `access-apps-list` → 200, `result: []` (app absent) → provisioner creates
  - `access-app-create` → 200, `result.id` = a fixture uid, `self_hosted_domains`
    carries BOTH apex and wildcard
  - `access-policies-list` → 200, `result: []` (policy absent) → provisioner creates
  - `access-policy-create` → 200, `result.decision: "allow"`
- **all-present** (SC-4): all three present → zero creates.
  - `pages-project-get` → 200 (exists) → skip
  - `access-apps-list` → 200, `result: [ {existing app, apex+wildcard} ]` → skip
  - `access-policies-list` → 200, `result: [ {allow policy} ]` → skip
- **zero-trust-not-enabled** (SC-5): Pages OK, first Access call errors.
  - `pages-project-get` → 404 → create
  - `pages-project-create` → 200
  - `access-apps-list` → `_http_status: "400"`, `errors[0].code: 12130`
    (`access.api.error.*` namespace) → provisioner emits the dashboard-enablement
    diagnostic, exits non-zero
- **missing-scope** (SC-5): Pages OK, first Access call 403.
  - `pages-project-get` → 404 → create
  - `pages-project-create` → 200
  - `access-apps-list` → `_http_status: "403"`, `errors[0].code: 9109` → provisioner
    emits the scope-specific diagnostic, exits non-zero

## Steps

1. Create the fixture root and four scenario directories:
   `tests/fixtures/m043-cloudflare/{clean-account,all-present,zero-trust-not-enabled,missing-scope}`.

2. Write the **clean-account** response files (verbatim content below).

3. Write the **all-present** response files (verbatim content below).

4. Write the **zero-trust-not-enabled** response files (verbatim content below).

5. Write the **missing-scope** response files (verbatim content below).

6. Write `tests/fixtures/m043-cloudflare/README.md` documenting the fixture-replay
   contract, the placeholder convention (no real secrets), and the doc-derived /
   P04-forward-pointer provenance carried over from the P00 seeds.

7. Author `tools/verify/m043-p02-fixtures-shape.sh` (verbatim below).

### Verbatim fixture content

All `result` values use the same placeholder convention as the P00 seeds:
`<name>` is the Pages project name, `<allowed_email_domains>` the email-domain
allow value. The `_http_status` field is a string. Fixture uids are fixed literals
(`app-uid-fixture-0001`, `pol-uid-fixture-0001`) so the verifiers are deterministic.

**`tests/fixtures/m043-cloudflare/clean-account/pages-project-get.response.json`**
```json
{
  "_http_status": "404",
  "success": false,
  "errors": [{ "code": 8000007, "message": "Project not found." }],
  "messages": [],
  "result": null
}
```

**`tests/fixtures/m043-cloudflare/clean-account/pages-project-create.response.json`**
```json
{
  "_http_status": "200",
  "success": true,
  "errors": [],
  "messages": [],
  "result": { "name": "<name>", "production_branch": "main", "subdomain": "<name>.pages.dev" }
}
```

**`tests/fixtures/m043-cloudflare/clean-account/access-apps-list.response.json`**
```json
{
  "_http_status": "200",
  "success": true,
  "errors": [],
  "messages": [],
  "result": []
}
```

**`tests/fixtures/m043-cloudflare/clean-account/access-app-create.response.json`**
```json
{
  "_http_status": "200",
  "success": true,
  "errors": [],
  "messages": [],
  "result": {
    "id": "app-uid-fixture-0001",
    "name": "<name> wiki (Access-gated)",
    "type": "self_hosted",
    "self_hosted_domains": ["<name>.pages.dev", "*.<name>.pages.dev"]
  }
}
```

**`tests/fixtures/m043-cloudflare/clean-account/access-policies-list.response.json`**
```json
{
  "_http_status": "200",
  "success": true,
  "errors": [],
  "messages": [],
  "result": []
}
```

**`tests/fixtures/m043-cloudflare/clean-account/access-policy-create.response.json`**
```json
{
  "_http_status": "200",
  "success": true,
  "errors": [],
  "messages": [],
  "result": { "id": "pol-uid-fixture-0001", "decision": "allow", "name": "Allow <allowed_email_domains>" }
}
```

**`tests/fixtures/m043-cloudflare/all-present/pages-project-get.response.json`**
```json
{
  "_http_status": "200",
  "success": true,
  "errors": [],
  "messages": [],
  "result": { "name": "<name>", "production_branch": "main", "subdomain": "<name>.pages.dev" }
}
```

**`tests/fixtures/m043-cloudflare/all-present/access-apps-list.response.json`**
```json
{
  "_http_status": "200",
  "success": true,
  "errors": [],
  "messages": [],
  "result": [
    {
      "id": "app-uid-fixture-0001",
      "name": "<name> wiki (Access-gated)",
      "type": "self_hosted",
      "domain": "<name>.pages.dev",
      "self_hosted_domains": ["<name>.pages.dev", "*.<name>.pages.dev"]
    }
  ]
}
```

**`tests/fixtures/m043-cloudflare/all-present/access-policies-list.response.json`**
```json
{
  "_http_status": "200",
  "success": true,
  "errors": [],
  "messages": [],
  "result": [
    { "id": "pol-uid-fixture-0001", "decision": "allow", "name": "Allow <allowed_email_domains>" }
  ]
}
```

**`tests/fixtures/m043-cloudflare/zero-trust-not-enabled/pages-project-get.response.json`**
```json
{
  "_http_status": "404",
  "success": false,
  "errors": [{ "code": 8000007, "message": "Project not found." }],
  "messages": [],
  "result": null
}
```

**`tests/fixtures/m043-cloudflare/zero-trust-not-enabled/pages-project-create.response.json`**
```json
{
  "_http_status": "200",
  "success": true,
  "errors": [],
  "messages": [],
  "result": { "name": "<name>", "production_branch": "main", "subdomain": "<name>.pages.dev" }
}
```

**`tests/fixtures/m043-cloudflare/zero-trust-not-enabled/access-apps-list.response.json`**
```json
{
  "_http_status": "400",
  "success": false,
  "errors": [
    {
      "code": 12130,
      "message": "[unconfirmed-P04] access.api.error.invalid_request: Cloudflare Zero Trust is not enabled for this account. Complete the one-time Zero Trust onboarding in the Cloudflare dashboard (Zero Trust > Settings) before provisioning Access applications via the API."
    }
  ],
  "messages": [],
  "result": null
}
```

**`tests/fixtures/m043-cloudflare/missing-scope/pages-project-get.response.json`**
```json
{
  "_http_status": "404",
  "success": false,
  "errors": [{ "code": 8000007, "message": "Project not found." }],
  "messages": [],
  "result": null
}
```

**`tests/fixtures/m043-cloudflare/missing-scope/pages-project-create.response.json`**
```json
{
  "_http_status": "200",
  "success": true,
  "errors": [],
  "messages": [],
  "result": { "name": "<name>", "production_branch": "main", "subdomain": "<name>.pages.dev" }
}
```

**`tests/fixtures/m043-cloudflare/missing-scope/access-apps-list.response.json`**
```json
{
  "_http_status": "403",
  "success": false,
  "errors": [
    {
      "code": 9109,
      "message": "[unconfirmed-P04] Unauthorized to access requested resource. The API token is missing the 'Access: Apps and Policies — Edit' permission. Add the scope to the token in the Cloudflare dashboard (My Profile > API Tokens) and store it as the CLOUDFLARE_API_TOKEN repo secret."
    }
  ],
  "messages": [],
  "result": null
}
```

### Verbatim README content

**`tests/fixtures/m043-cloudflare/README.md`** — write a doc of at least 30 lines
covering, in order:

1. A heading `# M043 Cloudflare recorded-API fixtures`.
2. A paragraph stating these are promoted from the P00 doc-derived seeds
   (`.orchestrator/milestones/M043/phases/P00/fixture-seeds/`) and drive SC-3
   (create-order + apex/wildcard), SC-4 (idempotent second run), and SC-5
   (Zero-Trust / missing-scope diagnostics).
3. A `## Fixture-replay contract` section containing the literal string
   `fixture-replay`, documenting the `cf_api <METHOD> <ENDPOINT_KEY>
   [REQUEST_BODY_FILE]` seam, the six endpoint keys table (copied from this plan),
   the `<ENDPOINT_KEY>.response.json` naming, the `_http_status` envelope field,
   and the `M043_CF_FIXTURE_DIR` / `M043_CF_CAPTURE_DIR` env vars + the
   `requests.log` + `<ENDPOINT_KEY>.request.json` capture outputs.
4. A `## Scenarios` section: one bullet per scenario dir describing its call
   sequence (copy the Scenario → call-sequence map from this plan).
5. A `## Provenance` section: every value is `doc-derived` (P00 Mode B); the two
   error fixtures carry `[unconfirmed-P04]` markers; P04 (friendly-tester live
   pass) must capture the real envelopes. Note explicitly that the error envelopes
   are modelled on the `access-apps-list` (first Access) call site even though the
   P00 seeds were captured as create-call envelopes — the same envelope applies on
   a not-onboarded / under-scoped account; P04 confirms.
6. A `## Placeholder convention` section: no real account id / token / project name
   / email domain appears; `<name>` and `<allowed_email_domains>` are
   runtime-substituted placeholders.

### Verbatim verifier: `tools/verify/m043-p02-fixtures-shape.sh`
```bash
#!/usr/bin/env bash
# m043-p02-fixtures-shape.sh — assert the M043 Cloudflare recorded-API fixture
# tree is well-formed: four scenario dirs, required response files per scenario,
# valid JSON with an _http_status field, the clean-account app-create body
# carrying BOTH apex and wildcard self_hosted_domains, and the two error
# fixtures carrying distinguishable (status, code) discriminators. Tier 1.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
FX="tests/fixtures/m043-cloudflare"
fail=0

check() {
  if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi
}

# README present + documents the contract
test -f "$FX/README.md"
check "fixtures README present" $?
grep -q "fixture-replay" "$FX/README.md" 2>/dev/null
check "README documents the fixture-replay contract" $?

# Required response files per scenario
for f in \
  clean-account/pages-project-get.response.json \
  clean-account/pages-project-create.response.json \
  clean-account/access-apps-list.response.json \
  clean-account/access-app-create.response.json \
  clean-account/access-policies-list.response.json \
  clean-account/access-policy-create.response.json \
  all-present/pages-project-get.response.json \
  all-present/access-apps-list.response.json \
  all-present/access-policies-list.response.json \
  zero-trust-not-enabled/access-apps-list.response.json \
  missing-scope/access-apps-list.response.json
do
  test -f "$FX/$f"
  check "fixture present: $f" $?
done

# Every response file is valid JSON and carries _http_status
while IFS= read -r jf; do
  jq -e . "$jf" >/dev/null 2>&1
  check "valid JSON: ${jf#$FX/}" $?
  jq -e 'has("_http_status")' "$jf" >/dev/null 2>&1
  check "_http_status present: ${jf#$FX/}" $?
done < <(find "$FX" -name '*.response.json' | sort)

# clean-account app-create carries BOTH apex and wildcard self_hosted_domains
APP="$FX/clean-account/access-app-create.response.json"
if [ -f "$APP" ]; then
  jq -e '.result.self_hosted_domains | index("<name>.pages.dev")' "$APP" >/dev/null 2>&1
  check "clean-account app-create has apex self_hosted_domain" $?
  jq -e '.result.self_hosted_domains | index("*.<name>.pages.dev")' "$APP" >/dev/null 2>&1
  check "clean-account app-create has wildcard self_hosted_domain" $?
fi

# all-present access-apps-list returns a non-empty result with an existing app
AP="$FX/all-present/access-apps-list.response.json"
if [ -f "$AP" ]; then
  jq -e '.result | length > 0' "$AP" >/dev/null 2>&1
  check "all-present apps-list is non-empty (idempotency seed)" $?
fi

# Error fixtures: distinguishable on (status, code)
ZT="$FX/zero-trust-not-enabled/access-apps-list.response.json"
MS="$FX/missing-scope/access-apps-list.response.json"
if [ -f "$ZT" ] && [ -f "$MS" ]; then
  zt_code="$(jq -r '.errors[0].code' "$ZT" 2>/dev/null)"
  ms_code="$(jq -r '.errors[0].code' "$MS" 2>/dev/null)"
  zt_status="$(jq -r '._http_status' "$ZT" 2>/dev/null)"
  ms_status="$(jq -r '._http_status' "$MS" 2>/dev/null)"
  if [ "$ms_status" = "403" ]; then s_ok=0; else s_ok=1; fi
  check "missing-scope fixture is HTTP 403" $s_ok
  if [ "$zt_status" != "403" ]; then z_ok=0; else z_ok=1; fi
  check "zero-trust fixture is NOT HTTP 403 (distinct status axis)" $z_ok
  if [ -n "$zt_code" ] && [ -n "$ms_code" ] && [ "$zt_code" != "$ms_code" ]; then c_ok=0; else c_ok=1; fi
  check "error fixtures carry distinct errors[].code (distinct code axis)" $c_ok
fi

echo "SUMMARY: m043-p02-fixtures-shape.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

Note: the verifier uses `< <(find ...)` process substitution **inside the
verifier script body** — this is allowed (the AD-19 / harness shape-guard applies
to the `Check:` command shape that the harness sees, i.e. the single
`bash tools/verify/...sh` invocation, NOT to constructs internal to the script).
The seam in the *provisioner* (T02) must still be Bash 3.2 (no process
substitution) because that is operator-facing shell; verifier scripts are
dev-runner-only and may use Bash 4+ constructs since they are never invoked as
inline harness commands.

## Must-Haves

- The recorded-API fixtures exist as four scenario directories with well-formed,
  endpoint-keyed JSON response files, and the clean-account Access-app create body
  carries both apex and wildcard `self_hosted_domains` (phase Truth 1).
- `tests/fixtures/m043-cloudflare/README.md` documents the fixture-replay contract
  (phase Artifact).

## Verification

`bash tools/verify/m043-p02-fixtures-shape.sh`

## Inputs

### From Previous Tasks

None — T01 is the first P02 task.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/*.json` — the five
  doc-derived seeds being promoted. Their content + `_seed_meta` provenance notes
  are the source-of-truth for the fixture envelopes (the `result`/`errors` shapes
  above are derived from them).
- `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` — the
  `#Q-6` finding that the two error envelopes are `distinguishable` on
  `(HTTP status, errors[].code)`; the error-fixture `_http_status`/`code` values
  above encode that decision.

## Constraints

- No real Cloudflare account id, API token, project name, or email domain in any
  fixture (these land in git). Use the `<name>` / `<allowed_email_domains>`
  placeholders only.
- The fixture tree is the seam T02 implements against — do NOT change endpoint-key
  names, the `_http_status` envelope field, or the `<ENDPOINT_KEY>.response.json`
  naming without updating the T02 plan in lockstep.
- Verifier path discipline: the verifier is a project-owned, milestone-prefixed
  per-phase verifier → `tools/verify/m043-p02-fixtures-shape.sh` (NOT
  `scripts/verify/`).

## Expected Output

`bash tools/verify/m043-p02-fixtures-shape.sh` prints a series of `PASS:` lines
and a final `SUMMARY: m043-p02-fixtures-shape.sh fail=0`, exiting 0.
