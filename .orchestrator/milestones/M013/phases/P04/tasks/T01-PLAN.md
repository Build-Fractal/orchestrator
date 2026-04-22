---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M013"
name: "Sync fixture tree + github-common.sh P04 helpers (http_probe, sidecar_update_item_cache, emit_tier1_record)"
depends_on: []
---

## Prerequisites

- Bash 3.2 target (MEM001). No `declare -A`, no `mapfile`/`readarray`, no process substitution, no combined-redirect shorthand, no case-conversion expansion. Use parallel indexed arrays where state is needed.
- AD-19 `Check:` shape for every verification command: single-script-file invocation only, no inline compound bash, no plain subshells, no `$()` containing pipes, no `<(…)` process substitution.
- P02 shipped `scripts/integrations/github-common.sh` with public helpers: `gh_auth_preflight`, `gh_scope_preflight`, `gh_subissue_rest_preflight`, `gh_label_collision_preflight`, `emit_marker`, `shasum_marker_byte_identity`, `manifest_upsert_line`, `manifest_footer`, `sidecar_upsert_item`. P03 added `gh_marker_search_remote` and extended `manifest_footer` with an additive 4th-arg `<adopted>`.
- P02 sidecar schema is defined by `templates/github-integration-sidecar.json` (M013/P01/T01 deliverable). Items have shape `{ "issue_number": <int>, "project_v2_attached": <bool>, "status_field_synced": <bool>, "last_attempt_at": "<ISO>", "last_error": <string|null> }` — all five fields declared at P01/P02 but `last_attempt_at`, `last_error`, `status_field_synced`, `project_v2_attached` are written by P04 on every sync run (per the P04 roadmap Produces section "Sidecar schema extensions (per-item cache fields already declared at P01/P02; P04 populates ...)").
- P03 added the FR-5 three-shape GraphQL whitelist lint `scripts/verify/graphql-call-shape.sh`. It whitelists exactly {`createProjectV2`, `addProjectV2ItemById`, `updateProjectV2ItemFieldValue`}. P04/T01 itself introduces NO new mutations; it only adds helpers.
- M013_GH_STUB_DIR environment-variable stub-selector pattern is established by P02 (preflights) and extended by P03 (marker-search family). T01 uses the same pattern for all new stubs: helpers consult `M013_GH_STUB_DIR` first and fall back to live `gh` when empty.
- `.orchestrator/execution-log.jsonl` is the append-only JSONL log authored by `scripts/lifecycle/record-result.sh`. T01's `emit_tier1_record` appends records in the M019 Tier 1 shape with `source: "runtime"` (FR-17).
- M019 Tier 1 JSONL record shape is authoritative — T01 mirrors the shape used by existing runtime emitters; it does NOT extend the schema (per the P04 Cross-Cutting Concerns entry: "M019 owns schema evolution").
- Known orchestrator bug: `scripts/lifecycle/phase-transition.sh` crashes on non-numeric `duration:` fields under `set -euo pipefail`. Work around with integer-minutes strings in the T01 summary.

## Description

Author two deliverables:

1. **Sync fixture tree** at `tests/fixtures/m013-p04/sync-cycle/` containing (a) an `orchestrator-state/` seed with one milestone M013-LIKE, one Done phase P01-FIX (with two Done tasks T01, T02), and one Ready phase P02-FIX (with one in-flight task T01); (b) a pre-populated `.orchestrator/integrations/github.json` sidecar with `repo_slug`, `project_v2_id`, and five `items.<oid>` entries; (c) `gh-stub-responses/` with canned gh responses for `auth status`, `api rate_limit` (remaining > 50), `issue list --search` per projected id, `issue view --json state,body` per cached Issue number, `api graphql` responses for `addProjectV2ItemById` and `updateProjectV2ItemFieldValue`; (d) three pinned-expectation snapshots: `expected-sync-dryrun-manifest.txt`, `expected-unit-close.jsonl`, `expected-conversus-gate-invocation.jsonl`.

2. **Three additive public helpers** in `scripts/integrations/github-common.sh`:
   - `http_probe <rest-path>` — wraps `gh api --include <path>`, parses the HTTP status line + `X-RateLimit-Remaining` header, emits `STATUS=<int>` + `RATE_LIMIT_REMAINING=<int>` + `RATE_LIMIT_RESET=<ISO>` to stdout. Returns 0 on 2xx, 3 on 403+rate-limited, 4 on 401, 1 on other error. Fixture-driven via `M013_GH_STUB_DIR` (reads `http-probe-<path-slug>.txt` when stub dir is set).
   - `sidecar_update_item_cache <oid> <last-attempt-iso> <last-error-or-null> <status-field-synced-bool> <project-v2-attached-bool> [<root>]` — updates the four mutable per-item cache fields in `.orchestrator/integrations/github.json` atomically (temp-file + rename). Preserves `issue_number` untouched. Respects FR-11 reversibility (refuses to operate when sidecar is absent or holds pending sentinels — returns exit 2 with a `sidecar-not-configured` diagnostic).
   - `emit_tier1_record <record-type> <kv-pair>...` — appends one JSONL record to `.orchestrator/execution-log.jsonl`. Record is `{"ts":"<ISO>","event":"<record-type>","source":"runtime",<...kv>}` — fields appear in key-lex-sorted order after the fixed `ts`/`event`/`source` prefix; values are JSON-escaped (double-quote, backslash, newline). Append-only; never rotates. Respects `.orchestrator/` via `ORCHESTRATOR_ROOT` env var when set (M008/M015 4-rule resolver convention).

The helpers are bash 3.2 compatible, jq-optional (awk+sed fallback), and use the `M013_GH_STUB_DIR` stub-selector pattern for all live-command branches. Every helper has exit-code contract + stdout structured output + stderr diagnostics.

## Steps

### Step 1: Create the fixture directory tree

```bash
mkdir -p tests/fixtures/m013-p04/sync-cycle/orchestrator-state/.orchestrator/integrations
mkdir -p tests/fixtures/m013-p04/sync-cycle/orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P01-FIX/tasks
mkdir -p tests/fixtures/m013-p04/sync-cycle/orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P02-FIX/tasks
mkdir -p tests/fixtures/m013-p04/sync-cycle/gh-stub-responses
```

### Step 2: Seed orchestrator-state

Create the following seed files with minimal but walker-complete content:

`tests/fixtures/m013-p04/sync-cycle/orchestrator-state/.orchestrator/milestones/M013-FIX/M013-FIX-ROADMAP.md`:

```markdown
---
schema_version: "1.0"
type: roadmap
milestone: "M013-FIX"
feature_ref: "m013-p04-sync-fixture"
---

## Phases

- [x] **P01-FIX**: Seed phase for sync fixture — "Done; drives status-field-sync UPSERT row"
  - Risk: low
  - Depends: none
- [ ] **P02-FIX**: Seed phase for sync fixture — "Ready; drives skip-nochange UPSERT row"
  - Risk: low
  - Depends: P01-FIX
```

`tests/fixtures/m013-p04/sync-cycle/orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P01-FIX/P01-FIX-PLAN.md`:

```markdown
---
schema_version: "1.0"
type: phase-plan
phase: "P01-FIX"
milestone: "M013-FIX"
state: "done"
goal: "fixture phase"
demo_sentence: "fixture"
risk: "low"
depends_on: []
---
## Must-Haves
- Fixture content
```

`tests/fixtures/m013-p04/sync-cycle/orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P01-FIX/P01-FIX-SUMMARY.md`:

```markdown
---
schema_version: "1.0"
type: phase-summary
id: "P01-FIX"
parent: "M013-FIX"
milestone: "M013-FIX"
verification_result: "pass"
duration: "10m"
completed_at: "2026-04-22T00:00:00Z"
---
Fixture done phase.
```

`tests/fixtures/m013-p04/sync-cycle/orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P01-FIX/tasks/T01-PLAN.md`:

```markdown
---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01-FIX"
milestone: "M013-FIX"
name: "fixture task"
depends_on: []
---
Fixture.
```

`tests/fixtures/m013-p04/sync-cycle/orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P01-FIX/tasks/T01-SUMMARY.md`:

```markdown
---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01-FIX"
milestone: "M013-FIX"
verification_result: "pass"
duration: "5m"
completed_at: "2026-04-22T00:00:00Z"
---
Fixture.
```

Repeat for T02 under P01-FIX (also Done).

`tests/fixtures/m013-p04/sync-cycle/orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P02-FIX/P02-FIX-PLAN.md`:

```markdown
---
schema_version: "1.0"
type: phase-plan
phase: "P02-FIX"
milestone: "M013-FIX"
state: "ready"
goal: "fixture phase"
demo_sentence: "fixture"
risk: "low"
depends_on: ["P01-FIX"]
---
## Must-Haves
- Fixture
```

`tests/fixtures/m013-p04/sync-cycle/orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P02-FIX/tasks/T01-PLAN.md` (no SUMMARY — in-flight).

### Step 3: Seed the sidecar

`tests/fixtures/m013-p04/sync-cycle/orchestrator-state/.orchestrator/integrations/github.json`:

```json
{
  "schema_version": "1.0",
  "repo_slug": "test/sync-fixture",
  "project_v2_id": "PVT_kwDOAAAAAAAAAAAA",
  "sync_mode": "manual",
  "sub_issue_mode": "native",
  "recommended_cron": "",
  "custom_field_mappings": {},
  "last_sync": "",
  "items": {
    "M013-FIX": { "issue_number": 301, "project_v2_attached": true, "status_field_synced": true, "last_attempt_at": "2026-04-21T00:00:00Z", "last_error": null },
    "M013-FIX-P01-FIX": { "issue_number": 302, "project_v2_attached": true, "status_field_synced": false, "last_attempt_at": "2026-04-21T00:00:00Z", "last_error": null },
    "M013-FIX-P01-FIX-T01": { "issue_number": 303, "project_v2_attached": true, "status_field_synced": false, "last_attempt_at": "2026-04-21T00:00:00Z", "last_error": null },
    "M013-FIX-P01-FIX-T02": { "issue_number": 304, "project_v2_attached": true, "status_field_synced": false, "last_attempt_at": "2026-04-21T00:00:00Z", "last_error": null },
    "M013-FIX-P02-FIX": { "issue_number": 305, "project_v2_attached": true, "status_field_synced": true, "last_attempt_at": "2026-04-21T00:00:00Z", "last_error": null },
    "M013-FIX-P02-FIX-T01": { "issue_number": 306, "project_v2_attached": true, "status_field_synced": true, "last_attempt_at": "2026-04-21T00:00:00Z", "last_error": null }
  }
}
```

Note: P01-FIX and its tasks carry `status_field_synced: false` so T02's sync run produces status-sync UPSERT rows. P02-FIX and its task carry `status_field_synced: true` so they produce `skip-nochange` rows.

### Step 4: Author gh-stub responses

Create each file under `tests/fixtures/m013-p04/sync-cycle/gh-stub-responses/` as a minimal canned response:

- `auth-status-green.txt` — one-liner `✓ Logged in to github.com as test-user (oauth_token)`.
- `rate-limit-ample.json` — `{ "resources": { "core": { "remaining": 4500, "reset": 1745000000 }, "graphql": { "remaining": 4500, "reset": 1745000000 } } }`.
- `issue-list-M013-FIX-P01-FIX.json` — `[{"number":302}]`.
- `issue-list-M013-FIX-P01-FIX-T01.json` — `[{"number":303}]`.
- `issue-list-M013-FIX-P01-FIX-T02.json` — `[{"number":304}]`.
- `issue-list-M013-FIX-P02-FIX.json` — `[{"number":305}]`.
- `issue-list-M013-FIX-P02-FIX-T01.json` — `[{"number":306}]`.
- `issue-view-302-state-body.json` — `{"state":"open","body":"<!-- orchestrator-id: M013-FIX-P01-FIX -->\nfixture"}`.
- Repeat for 303, 304 with state `open` (to be closed).
- `issue-view-305-state-body.json` — `{"state":"open","body":"<!-- orchestrator-id: M013-FIX-P02-FIX -->\nfixture"}`.
- `issue-view-306-state-body.json` — `{"state":"open","body":"<!-- orchestrator-id: M013-FIX-P02-FIX-T01 -->\nfixture"}`.
- `graphql-update-status-field-success.json` — `{"data":{"updateProjectV2ItemFieldValue":{"projectV2Item":{"id":"PVTI_1"}}}}`.
- `http-probe-rate_limit.txt` — text capturing `HTTP/2 200` + `X-RateLimit-Remaining: 4500` + `X-RateLimit-Reset: 1745000000`.

### Step 5: Author the three expected-* snapshots

`tests/fixtures/m013-p04/sync-cycle/expected-sync-dryrun-manifest.txt`:

```
DRY-RUN: sync manifest for M013-FIX (repo=test/sync-fixture)
UPSERT: phase-issue M013-FIX-P01-FIX 302 status-sync
UPSERT: task-subissue M013-FIX-P01-FIX-T01 303 close
UPSERT: task-subissue M013-FIX-P01-FIX-T02 304 close
UPSERT: phase-issue M013-FIX-P02-FIX 305 skip-nochange
UPSERT: task-subissue M013-FIX-P02-FIX-T01 306 skip-nochange
UPSERT: milestone M013-FIX 301 skip-nochange
upserts=3 skipped=3 errors=0
```

`tests/fixtures/m013-p04/sync-cycle/expected-unit-close.jsonl`:

```jsonl
{"ts":"<FROZEN-ISO>","event":"unit_close","source":"runtime","milestone":"M013-FIX","oid":"M013-FIX-P01-FIX","phase":"P01-FIX","task":null,"issue_number":302,"outcome":"status-synced"}
{"ts":"<FROZEN-ISO>","event":"unit_close","source":"runtime","milestone":"M013-FIX","oid":"M013-FIX-P01-FIX-T01","phase":"P01-FIX","task":"T01","issue_number":303,"outcome":"closed"}
{"ts":"<FROZEN-ISO>","event":"unit_close","source":"runtime","milestone":"M013-FIX","oid":"M013-FIX-P01-FIX-T02","phase":"P01-FIX","task":"T02","issue_number":304,"outcome":"closed"}
```

The `<FROZEN-ISO>` literal is the sentinel the T03 observability gate replaces with a regex anchor before diffing.

`tests/fixtures/m013-p04/sync-cycle/expected-conversus-gate-invocation.jsonl`:

```jsonl
{"ts":"<FROZEN-ISO>","event":"conversus_gate_invocation","source":"runtime","issue_ref":"test/sync-fixture#999","timeout_sec":30,"verdict":"PASS","rc":0,"duration_ms":1234}
```

### Step 6: Author `http_probe` helper in `scripts/integrations/github-common.sh`

Locate the end of the existing helper block (after `gh_marker_search_remote`). Append:

```bash
# http_probe <rest-path>
# ----------------------------------------------------------------------------
# Wraps `gh api --include <path>`, parses HTTP status + X-RateLimit-Remaining
# header, emits STATUS=<int> + RATE_LIMIT_REMAINING=<int> + RATE_LIMIT_RESET=<int>
# lines. Returns 0 on 2xx, 3 on 403 with rate-limited body, 4 on 401,
# 1 on other error. Fixture-driven via M013_GH_STUB_DIR (reads
# http-probe-<slug>.txt when the env var is set; slug is the path stripped
# of leading slash with remaining slashes replaced by underscores).
http_probe() {
  local path="$1"
  local stub="${M013_GH_STUB_DIR:-}"
  local raw=""
  local slug
  slug="$(printf '%s' "$path" | sed 's#^/##; s#/#_#g')"
  if [ -n "$stub" ] && [ -f "${stub}/http-probe-${slug}.txt" ]; then
    raw="$(cat "${stub}/http-probe-${slug}.txt")"
  else
    raw="$(gh api --include "$path" 2>/dev/null || true)"
  fi
  if [ -z "$raw" ]; then
    return 1
  fi
  local status rem reset
  status="$(printf '%s\n' "$raw" | awk '/^HTTP\// { for (i=1;i<=NF;i++) if ($i ~ /^[0-9][0-9][0-9]$/) { print $i; exit } }')"
  rem="$(printf '%s\n' "$raw" | awk '/^X-RateLimit-Remaining:/ { print $2; exit }' | tr -d '\r')"
  reset="$(printf '%s\n' "$raw" | awk '/^X-RateLimit-Reset:/ { print $2; exit }' | tr -d '\r')"
  echo "STATUS=${status:-0}"
  echo "RATE_LIMIT_REMAINING=${rem:-}"
  echo "RATE_LIMIT_RESET=${reset:-}"
  case "${status:-}" in
    2??) return 0 ;;
    401) return 4 ;;
    403)
      if printf '%s\n' "$raw" | grep -q "rate limit"; then
        return 3
      fi
      return 1
      ;;
    *) return 1 ;;
  esac
}
```

### Step 7: Author `sidecar_update_item_cache` helper

```bash
# sidecar_update_item_cache <oid> <last-attempt-iso> <last-error-or-null>
#                          <status-field-synced-bool> <project-v2-attached-bool>
#                          [<root>]
# ----------------------------------------------------------------------------
# Updates the four mutable per-item cache fields. Preserves issue_number.
# Atomic write: temp-file + rename. Exit 2 on sidecar-absent / pending-sentinel
# (FR-11 reversibility: no-op cleanly in the not-configured state).
sidecar_update_item_cache() {
  local oid="$1" ts="$2" err="$3" synced="$4" attached="$5"
  local root="${6:-.}"
  local sc="${root}/.orchestrator/integrations/github.json"
  if [ ! -f "$sc" ]; then
    echo "sidecar-not-configured: ${sc}" >&2
    return 2
  fi
  if grep -q '"pending"' "$sc"; then
    echo "sidecar-pending-operator-complete: ${sc}" >&2
    return 2
  fi
  # awk rewrite: find items.<oid> block, replace the four fields, preserve
  # issue_number. Bash 3.2 + jq-optional.
  local tmp
  tmp="$(mktemp -t m013-sc-update.XXXXXX)"
  awk -v oid="$oid" -v ts="$ts" -v err="$err" -v sy="$synced" -v at="$attached" '
    BEGIN { depth=0; in_oid=0 }
    {
      # Simple block walker; relies on jq-output shape from P02 init writes.
      line=$0
      if (match(line, "\"" oid "\": *\\{")) { in_oid=1 }
      if (in_oid==1) {
        gsub(/"last_attempt_at":[^,}]*/, "\"last_attempt_at\":\"" ts "\"")
        if (err == "null") {
          gsub(/"last_error":[^,}]*/, "\"last_error\":null")
        } else {
          gsub(/"last_error":[^,}]*/, "\"last_error\":\"" err "\"")
        }
        gsub(/"status_field_synced":[^,}]*/, "\"status_field_synced\":" sy)
        gsub(/"project_v2_attached":[^,}]*/, "\"project_v2_attached\":" at)
        if (match(line, /\}/)) { in_oid=0 }
      }
      print line
    }
  ' "$sc" > "$tmp"
  mv "$tmp" "$sc"
  return 0
}
```

### Step 8: Author `emit_tier1_record` helper

```bash
# emit_tier1_record <record-type> <key>=<value> [<key>=<value>...]
# ----------------------------------------------------------------------------
# Appends one JSONL record to .orchestrator/execution-log.jsonl in the
# M019 Tier 1 shape: {"ts":"<ISO>","event":"<type>","source":"runtime",<kv>...}
# Values are JSON-escaped (double-quote, backslash, newline). Keys are emitted
# in the order they arrive (callers responsible for stable ordering).
# Respects ORCHESTRATOR_ROOT env var for state root (M008/M015 4-rule resolver).
emit_tier1_record() {
  local rtype="$1"; shift
  local root="${ORCHESTRATOR_ROOT:-.orchestrator}"
  local log="${root}/execution-log.jsonl"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local out="{\"ts\":\"${ts}\",\"event\":\"${rtype}\",\"source\":\"runtime\""
  local pair key val esc
  for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    # Escape: backslash, double-quote, newline.
    esc="$(printf '%s' "$val" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk '{ printf "%s\\n", $0 }' | sed 's/\\n$//')"
    # Numeric / null / bool passthrough: no quotes when value looks numeric / null / true / false.
    case "$val" in
      null|true|false) out="${out},\"${key}\":${val}" ;;
      *[!0-9]*|'') out="${out},\"${key}\":\"${esc}\"" ;;
      *)            out="${out},\"${key}\":${val}" ;;
    esac
  done
  out="${out}}"
  mkdir -p "$root"
  printf '%s\n' "$out" >> "$log"
}
```

### Step 9: Create gate `scripts/verify/m013-p04-sync-fixture.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p04-sync-fixture.sh — T01 gate: verify sync fixture tree shape.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p04/sync-cycle"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# --- Assertion 1: fixture root exists
if [ -d "$FX" ]; then pass "fixture root exists"; else fail "fixture root missing: $FX"; fi

# --- Assertion 2: orchestrator-state seed exists with required phase files
for f in \
  orchestrator-state/.orchestrator/milestones/M013-FIX/M013-FIX-ROADMAP.md \
  orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P01-FIX/P01-FIX-PLAN.md \
  orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P01-FIX/P01-FIX-SUMMARY.md \
  orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P02-FIX/P02-FIX-PLAN.md \
  orchestrator-state/.orchestrator/integrations/github.json; do
  if [ -f "${FX}/${f}" ]; then pass "seed ${f}"; else fail "missing ${f}"; fi
done

# --- Assertion 3: sidecar is populated (not pending)
if grep -q '"pending"' "${FX}/orchestrator-state/.orchestrator/integrations/github.json"; then
  fail "sidecar contains pending sentinels (expected populated)"
else
  pass "sidecar is populated (no pending)"
fi

# --- Assertion 4: gh-stub-responses canonical set present
for s in auth-status-green.txt rate-limit-ample.json \
         issue-list-M013-FIX-P01-FIX.json issue-list-M013-FIX-P02-FIX.json \
         issue-view-302-state-body.json issue-view-305-state-body.json \
         graphql-update-status-field-success.json http-probe-rate_limit.txt; do
  if [ -f "${FX}/gh-stub-responses/${s}" ]; then
    pass "stub ${s}"
  else
    fail "missing stub ${s}"
  fi
done

# --- Assertion 5: expected-* snapshots present
for e in expected-sync-dryrun-manifest.txt expected-unit-close.jsonl expected-conversus-gate-invocation.jsonl; do
  if [ -f "${FX}/${e}" ]; then pass "snapshot ${e}"; else fail "missing snapshot ${e}"; fi
done

# --- Assertion 6: dryrun manifest has >=3 UPSERT rows + footer
if grep -cE '^UPSERT: ' "${FX}/expected-sync-dryrun-manifest.txt" | grep -qE '^[3-9]|^[1-9][0-9]'; then
  pass "expected manifest has >=3 UPSERT rows"
else
  fail "expected manifest has <3 UPSERT rows"
fi
if grep -qE '^upserts=[0-9]+ skipped=[0-9]+ errors=[0-9]+$' "${FX}/expected-sync-dryrun-manifest.txt"; then
  pass "expected manifest has P02-shape footer"
else
  fail "expected manifest footer shape mismatch"
fi

echo "SUMMARY: m013-p04-sync-fixture.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-sync-fixture.sh"
  exit 0
fi
echo "FAIL: m013-p04-sync-fixture.sh" >&2
exit 1
```

### Step 10: Create smoke-test gate for the three new helpers

`scripts/verify/m013-p04-github-common-p04.sh` (integrated into the T01 check; simplified into the primary fixture gate for AD-19 single-invocation):

Add these assertions to `m013-p04-sync-fixture.sh` (Step 9), or split into a second gate file. The plan's Check for T01 is the fixture gate above; the helper smoke is covered by T02/T03 gates that exercise `http_probe`/`sidecar_update_item_cache`/`emit_tier1_record` in context. T01 asserts SOURCE PRESENCE only:

Add to `m013-p04-sync-fixture.sh`:

```bash
# --- Assertion 7: three new helpers are defined in github-common.sh
for fn in http_probe sidecar_update_item_cache emit_tier1_record; do
  if grep -qE "^${fn}\(\)" "${REPO_ROOT}/scripts/integrations/github-common.sh"; then
    pass "helper ${fn} defined"
  else
    fail "helper ${fn} missing from github-common.sh"
  fi
done
```

## Must-Haves

From P04-PLAN:

- `tests/fixtures/m013-p04/sync-cycle/` tree exists with orchestrator-state seed + populated sidecar + gh-stub-responses + three expected-* snapshots.
- `scripts/integrations/github-common.sh` defines three new public helpers `http_probe`, `sidecar_update_item_cache`, `emit_tier1_record` — each with documented exit-code contract + stdout structured output + stderr diagnostics.
- Every existing P02/P03 helper in `github-common.sh` stays byte-identical.
- `scripts/verify/m013-p04-sync-fixture.sh` passes (≥15 assertions).

## Verification

```bash
bash scripts/verify/m013-p04-sync-fixture.sh
```

Exit 0. SUMMARY line reports pass≥15 fail=0.

Regression guards:

```bash
bash scripts/verify/m013-p02-phase-suite.sh
bash scripts/verify/m013-p03-phase-suite.sh
```

Both exit 0 byte-for-byte.

## Inputs

### From Previous Tasks

None — T01 is the first task of P04.

### From Disk (Pre-existing)

- `scripts/integrations/github-common.sh` (from M013/P02/T01 + P03/T01)
  - Key API: existing public helpers (`gh_marker_search_remote`, `manifest_footer`, `sidecar_upsert_item`, `shasum_marker_byte_identity`, etc.) MUST stay byte-identical. T01 appends new helpers ONLY — no existing function body is touched.
  - Location of append: end of the helpers block, before any final `# End of helpers` comment or `return 0` EOF sentinel.
- `templates/github-integration-sidecar.json` (from M013/P01/T01)
  - Schema source for the sidecar; T01's fixture sidecar conforms to this schema.
- `scripts/verify/anti-pattern-lint.sh` (M016/M021 invariant)
  - Consumed indirectly via T06 bash32-compat gate.
- `scripts/verify/m013-p02-phase-suite.sh`, `scripts/verify/m013-p03-phase-suite.sh` (prior-phase gates)
  - Regression guards — must stay green after T01 lands.

## Constraints

- **P02/P03 byte-identity**: all existing gates must still exit 0 after T01 lands. Run `scripts/verify/m013-p02-phase-suite.sh` and `scripts/verify/m013-p03-phase-suite.sh` as regression probes.
- **Knowledge-Layer Boundary (D014)**: no knowledge/spec/ writes, no `KNOWLEDGE-INDEX.md` extensions, no `scripts/knowledge/rebuild-index.sh` modifications.
- **FR-12 Claude-Code-only v1**: T01 does not touch Codex or Cursor installers or runtime adapters.
- **FR-4 marker invariant**: the fixture's gh-stub `issue-view-*-state-body.json` responses MUST embed the `<!-- orchestrator-id: <oid> -->` marker in each body field so downstream T02 `shasum_marker_byte_identity` checks pass.
- **FR-5 mutation whitelist**: T01 does not introduce any GraphQL mutation call site. The `graphql-update-status-field-success.json` stub is a RESPONSE payload (data only), not a call site — `graphql-call-shape.sh` scans `scripts/integrations/github-*.sh` for invocations, which T01's deliverables do not contain.
- **FR-11 reversibility**: `sidecar_update_item_cache` exits 2 cleanly when sidecar is absent or holds pending sentinels. T01's fixture sidecar is populated; the absent/pending edge is exercised by T02 gates.
- **FR-17 `source: "runtime"`**: `emit_tier1_record` hard-codes `source: "runtime"` per the roadmap's "`source: \"runtime\"`" clause.
- **Bash 3.2**: all three helpers use only bash 3.2 idioms. No `declare -A`, no `mapfile`, no `<(…)`, no `&>`/`|&`, no `${var^^}`/`${var,,}`. Parallel indexed arrays if state is needed (none needed in T01).
- **AD-19 `Check:` shape**: gate command is a single-script-file invocation (`bash scripts/verify/m013-p04-sync-fixture.sh`). No inline compound bash, no plain subshells, no `$()` containing pipes, no process substitution.
- **SC-7 zero approval prompts**: T01 introduces no new live `gh` call site (helpers are plumbing; call sites arrive in T02/T03/T05). No auto-mode re-entry path added in T01.
- **Integer-minutes duration** in T01-SUMMARY.md when authored.
- **jq-optional**: helpers use awk+sed only. No hard jq dependency.
- **No modifications to existing `github-common.sh` function bodies**: helpers are appended. The P02 `manifest_footer` retains its P03-extended 4-arg signature byte-identical.

## Expected Output

```
PASS: fixture root exists
PASS: seed orchestrator-state/.orchestrator/milestones/M013-FIX/M013-FIX-ROADMAP.md
PASS: seed orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P01-FIX/P01-FIX-PLAN.md
PASS: seed orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P01-FIX/P01-FIX-SUMMARY.md
PASS: seed orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P02-FIX/P02-FIX-PLAN.md
PASS: seed orchestrator-state/.orchestrator/integrations/github.json
PASS: sidecar is populated (no pending)
PASS: stub auth-status-green.txt
PASS: stub rate-limit-ample.json
PASS: stub issue-list-M013-FIX-P01-FIX.json
PASS: stub issue-list-M013-FIX-P02-FIX.json
PASS: stub issue-view-302-state-body.json
PASS: stub issue-view-305-state-body.json
PASS: stub graphql-update-status-field-success.json
PASS: stub http-probe-rate_limit.txt
PASS: snapshot expected-sync-dryrun-manifest.txt
PASS: snapshot expected-unit-close.jsonl
PASS: snapshot expected-conversus-gate-invocation.jsonl
PASS: expected manifest has >=3 UPSERT rows
PASS: expected manifest has P02-shape footer
PASS: helper http_probe defined
PASS: helper sidecar_update_item_cache defined
PASS: helper emit_tier1_record defined
SUMMARY: m013-p04-sync-fixture.sh pass=23 fail=0
PASS: m013-p04-sync-fixture.sh
```

Estimated duration: 45 integer minutes.
