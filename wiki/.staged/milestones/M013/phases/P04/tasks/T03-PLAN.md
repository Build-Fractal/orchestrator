---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M013"
name: "FR-16 rate-limit + auth-expiry detection + FR-17 observability emitters (unit_close + conversus_gate_invocation JSONL) in github-sync.sh"
depends_on: ["T02"]
---

## Prerequisites

- Bash 3.2 target (MEM001). AD-19 `Check:` shape for every verification command.
- T01 has landed `scripts/integrations/github-common.sh` helpers `http_probe` and `emit_tier1_record` and the sync fixture tree.
- T02 has landed `scripts/integrations/github-sync.sh` core — flag parser, auto-mode short-circuit, sidecar parse, lock acquisition, state walker, reconcile loop, manifest emit, `perform_upsert` (close + status-sync mutation), `sidecar_update_item_cache` call sites.
- [M019](../../../../../milestones/M019/index.md) Tier 1 JSONL shape for `unit_close`: record is `{"ts":"<ISO>","event":"unit_close","source":"runtime","milestone":"<M###>","phase":"<P##>","task":"<T##>|null","oid":"<orchestrator-id>","issue_number":<int>,"outcome":"closed|status-synced"}`.
- M019 Tier 1 JSONL shape for `conversus_gate_invocation`: record is `{"ts":"<ISO>","event":"conversus_gate_invocation","source":"runtime","issue_ref":"<repo>#<num>","timeout_sec":<int>,"verdict":"PASS|BLOCK|SKIPPED|ERROR","rc":<int>,"duration_ms":<int>}`. T03 ships the emit site in `github-sync.sh` as preparation but the actual gate invocation file `github-conversus-gate.sh` is authored in T05 — T05 calls the same helper.
- FR-16 semantics: `HTTP 403 + X-RateLimit-Remaining: 0` or GraphQL `RATE_LIMITED` code → no auto-retry inside the window, `retry-after` surfaced in exit diagnostic (rc=3); `HTTP 401` or stale `gh auth status` → pointer to `gh auth refresh` (rc=4); pre-flight `gh api rate_limit` probe when projected GraphQL volume > 50 mutations.
- Known orchestrator bug: integer-minutes duration only.

## Description

Layer two additive passes on top of T02's `github-sync.sh`:

1. **Rate-limit + auth-expiry detection (FR-16)**: insert a pre-flight probe block before the reconcile loop + wrap every live `gh api` / `gh issue close` call in a rc-class check that distinguishes rate-limit (403+remaining=0), GraphQL `RATE_LIMITED` error payload, auth-expired (401 or stale `gh auth status`), and transient other-error cases. Specific exit-code contract: rc=3 rate-limit, rc=4 auth-expired, rc=5 reserved (not used in T03), rc=6 lock-acquire-failed (already emitted by T02), rc=1 other error. Emit `RATE-LIMIT: retry-after=<ISO>` or `AUTH-EXPIRED: run gh auth refresh` to stderr on the respective outcomes.

2. **Observability emission (FR-17)**: wire `emit_tier1_record unit_close ...` at the successful-upsert site in `perform_upsert` — one call per item whose `status_field_synced` flips true or whose sub-issue closed. Wire `emit_tier1_record conversus_gate_invocation ...` into a shared helper `emit_conversus_gate_record` in `github-common.sh` that T05 calls from `github-conversus-gate.sh`. Both emitters honor `source: "runtime"` and never write during `--dry-run`.

The script adds NO new GraphQL mutation shapes. The pre-flight `gh api rate_limit` is a REST call (not GraphQL) and is outside FR-5's mutation-whitelist scope (which only governs mutations, not queries or REST).

## Steps

### Step 1: Pre-flight rate-limit probe

Insert immediately after lock acquisition, before the state walker:

```bash
# FR-16 pre-flight rate-limit probe (triggered when projected GraphQL volume > 50).
# The reconcile loop issues at most one mutation per Done phase that flipped
# status_field_synced:false. Sum those from the sidecar + desired-state diff.

count_projected_graphql_mutations() {
  local n=0 i=0 oid synced desired
  while [ "$i" -lt "$cached_count" ]; do
    eval "oid=\"\${cached_oid_${i}}\""
    eval "synced=\"\${cached_synced_${i}}\""
    desired="$(lookup_desired "$oid")"
    if [ "$desired" = "done" ] && [ "$synced" = "false" ] && [ "$(kind_of "$oid")" = "phase-issue" ]; then
      n=$((n + 1))
    fi
    i=$((i + 1))
  done
  echo "$n"
}

if [ "$DRY_RUN" -eq 0 ]; then
  projected_mutations="$(count_projected_graphql_mutations)"
  if [ "${projected_mutations:-0}" -gt 50 ]; then
    probe_out="$(http_probe "/rate_limit")"
    probe_rc=$?
    case "$probe_rc" in
      3)
        reset_ts="$(printf '%s\n' "$probe_out" | awk -F= '/^RATE_LIMIT_RESET=/ { print $2; exit }')"
        echo "RATE-LIMIT: retry-after=${reset_ts}" >&2
        release_lock
        exit 3
        ;;
      4)
        echo "AUTH-EXPIRED: run gh auth refresh" >&2
        release_lock
        exit 4
        ;;
    esac
    remaining="$(printf '%s\n' "$probe_out" | awk -F= '/^RATE_LIMIT_REMAINING=/ { print $2; exit }')"
    if [ -n "${remaining:-}" ] && [ "${remaining:-0}" -lt "$projected_mutations" ]; then
      echo "RATE-LIMIT: budget ${remaining} < projected ${projected_mutations}, aborting" >&2
      release_lock
      exit 3
    fi
  fi
fi
```

### Step 2: Per-call rate-limit wrapper

Extend `perform_upsert` to classify rc into the FR-16 exit classes. Define a shared helper in `github-common.sh`:

```bash
# classify_gh_rc <rc> <stderr-snapshot-path>
# ----------------------------------------------------------------------------
# Maps `gh` subprocess rc + stderr content into an FR-16 class:
#   rc=0  → echo "ok";         return 0
#   403 + X-RateLimit-Remaining:0 OR "rate limit" → echo "rate-limit" <reset>; return 3
#   401 OR "authentication failed" → echo "auth-expired"; return 4
#   GraphQL "RATE_LIMITED" → echo "rate-limit <reset>"; return 3
#   else → echo "other"; return 1
classify_gh_rc() {
  local rc="$1" errfile="$2"
  if [ "$rc" -eq 0 ]; then
    echo "ok"
    return 0
  fi
  if [ -f "$errfile" ]; then
    if grep -qE '(HTTP 403|403 rate limit|RATE_LIMITED|API rate limit exceeded)' "$errfile"; then
      local reset
      reset="$(grep -E 'X-RateLimit-Reset:' "$errfile" | awk '{print $2}' | tr -d '\r' | head -n 1)"
      echo "rate-limit ${reset:-unknown}"
      return 3
    fi
    if grep -qE '(HTTP 401|authentication (required|failed)|gh auth)' "$errfile"; then
      echo "auth-expired"
      return 4
    fi
  fi
  echo "other"
  return 1
}
```

Wrap each live call in `perform_upsert` with:

```bash
errfile="$(mktemp -t m013-sync-err.XXXXXX)"
# ... existing gh call, redirecting stderr to $errfile ...
rc=$?
class="$(classify_gh_rc "$rc" "$errfile")"
case "$class" in
  ok) : ;;
  "rate-limit "*)
    reset="${class#rate-limit }"
    echo "RATE-LIMIT: retry-after=${reset}" >&2
    rm -f "$errfile"
    release_lock
    exit 3
    ;;
  auth-expired)
    echo "AUTH-EXPIRED: run gh auth refresh" >&2
    rm -f "$errfile"
    release_lock
    exit 4
    ;;
  *)
    rm -f "$errfile"
    return 1
    ;;
esac
rm -f "$errfile"
return 0
```

### Step 3: Wire `unit_close` JSONL emission

In the reconcile loop, after `sidecar_update_item_cache` success, emit one Tier 1 record:

```bash
if [ "$DRY_RUN" -eq 0 ] && [ "$reason" != "skip-nochange" ] && [ "$errors_delta" -eq 0 ]; then
  outcome="status-synced"
  [ "$reason" = "close" ] && outcome="closed"
  ORCHESTRATOR_ROOT="${ORCHESTRATOR_ROOT}" emit_tier1_record unit_close \
    "milestone=${MILESTONE_ID}" \
    "oid=${oid}" \
    "phase=$(phase_of "$oid")" \
    "task=$(task_of "$oid")" \
    "issue_number=${issue}" \
    "outcome=${outcome}"
fi
```

Where `phase_of <oid>` extracts `P##` from `M###-P##[-T##]` and `task_of <oid>` extracts `T##` (or emits `null` for phase-issues and milestones).

### Step 4: Add `emit_conversus_gate_record` to `github-common.sh`

```bash
# emit_conversus_gate_record <issue-ref> <timeout-sec> <verdict> <rc> <duration-ms>
# ----------------------------------------------------------------------------
# Thin wrapper around emit_tier1_record for the conversus gate call site.
# Shared between github-sync.sh (if the gate is invoked inline) and the
# standalone github-conversus-gate.sh (T05).
emit_conversus_gate_record() {
  local ref="$1" to="$2" verdict="$3" rc="$4" dur="$5"
  emit_tier1_record conversus_gate_invocation \
    "issue_ref=${ref}" \
    "timeout_sec=${to}" \
    "verdict=${verdict}" \
    "rc=${rc}" \
    "duration_ms=${dur}"
}
```

### Step 5: Create gate `scripts/verify/m013-p04-rate-limit.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p04-rate-limit.sh — T03 gate: FR-16 rate-limit + auth-expiry

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p04/sync-cycle"
SYNC="${REPO_ROOT}/scripts/integrations/github-sync.sh"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Assertion 1: classify_gh_rc helper defined in github-common.sh
if grep -qE '^classify_gh_rc\(\)' "${REPO_ROOT}/scripts/integrations/github-common.sh"; then
  pass "classify_gh_rc defined"
else
  fail "classify_gh_rc missing"
fi

# Assertion 2: github-sync.sh contains rate-limit exit code 3 path
if grep -qE 'exit 3' "$SYNC" && grep -qE 'RATE-LIMIT:' "$SYNC"; then
  pass "rate-limit rc=3 path wired"
else
  fail "rate-limit rc=3 path missing"
fi

# Assertion 3: github-sync.sh contains auth-expired exit code 4 path
if grep -qE 'exit 4' "$SYNC" && grep -qE 'AUTH-EXPIRED:' "$SYNC"; then
  pass "auth-expired rc=4 path wired"
else
  fail "auth-expired rc=4 path missing"
fi

# Assertion 4: rate-limit stub triggers rc=3
shim_dir="$(mktemp -d -t m013-p04-rl.XXXXXX)"
stub_err="${shim_dir}/rate-limit-err.txt"
cat > "$stub_err" <<'ERR'
HTTP/2 403
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 2026-04-22T23:00:00Z

{"message":"API rate limit exceeded"}
ERR
cat > "${shim_dir}/gh" <<SHIM
#!/usr/bin/env bash
cat "$stub_err" >&2
exit 1
SHIM
chmod +x "${shim_dir}/gh"

# Build a sidecar with > 50 phase entries all needing status-sync, to trigger the pre-flight probe.
rl_fx="$(mktemp -d -t m013-p04-rl-fx.XXXXXX)"
mkdir -p "${rl_fx}/.orchestrator/integrations"
mkdir -p "${rl_fx}/.orchestrator/milestones/M013-RL/phases"
cat > "${rl_fx}/.orchestrator/milestones/M013-RL/M013-RL-ROADMAP.md" <<'RM'
---
schema_version: "1.0"
type: roadmap
milestone: "M013-RL"
---
## Phases
RM
{
  echo '{ "schema_version":"1.0","repo_slug":"t/r","project_v2_id":"P1","sync_mode":"manual","sub_issue_mode":"native","items":{'
  sep=""
  for n in $(seq 1 60); do
    mkdir -p "${rl_fx}/.orchestrator/milestones/M013-RL/phases/P${n}-RL"
    cat > "${rl_fx}/.orchestrator/milestones/M013-RL/phases/P${n}-RL/P${n}-RL-PLAN.md" <<-PE
---
type: phase-plan
phase: "P${n}-RL"
milestone: "M013-RL"
state: "done"
---
PE
    cat > "${rl_fx}/.orchestrator/milestones/M013-RL/phases/P${n}-RL/P${n}-RL-SUMMARY.md" <<-SE
---
type: phase-summary
id: "P${n}-RL"
verification_result: "pass"
---
SE
    echo "${sep}\"M013-RL-P${n}-RL\": { \"issue_number\": ${n}00, \"project_v2_attached\": true, \"status_field_synced\": false, \"last_attempt_at\":\"\", \"last_error\": null }"
    sep=","
  done
  echo '}}'
} > "${rl_fx}/.orchestrator/integrations/github.json"

PATH="${shim_dir}:${PATH}" M013_GH_STUB_DIR="${FX}/gh-stub-responses" \
  bash "$SYNC" --root "$rl_fx" --i-am-operator --repo-slug t/r </dev/null > /tmp/t03-rl.out 2>/tmp/t03-rl.err
rc=$?
# NOTE: because stub dir points at FX (which has rate-limit-ample.json as probe stub)
# but we did NOT override http-probe-rate_limit.txt stub, the test requires we
# override the probe stub to a rate-limited response. Write a custom stub dir:
rl_stub_dir="$(mktemp -d -t m013-p04-rl-stub.XXXXXX)"
cat > "${rl_stub_dir}/http-probe-rate_limit.txt" <<'RL'
HTTP/2 403
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 2026-04-22T23:00:00Z

{"message":"API rate limit exceeded"}
RL
PATH="${shim_dir}:${PATH}" M013_GH_STUB_DIR="$rl_stub_dir" \
  bash "$SYNC" --root "$rl_fx" --i-am-operator --repo-slug t/r </dev/null > /tmp/t03-rl.out 2>/tmp/t03-rl.err
rc=$?

if [ "$rc" -eq 3 ]; then
  pass "rc=3 on rate-limit pre-flight"
else
  fail "expected rc=3, got rc=${rc}"
fi
if grep -q 'RATE-LIMIT: retry-after=' /tmp/t03-rl.err; then
  pass "RATE-LIMIT retry-after diagnostic emitted"
else
  fail "RATE-LIMIT diagnostic missing"
fi

# Assertion 5: auth-expired path (401 probe → rc=4)
ae_stub_dir="$(mktemp -d -t m013-p04-ae-stub.XXXXXX)"
cat > "${ae_stub_dir}/http-probe-rate_limit.txt" <<'AE'
HTTP/2 401
X-RateLimit-Remaining: 4500
X-RateLimit-Reset: 0

{"message":"Bad credentials"}
AE
PATH="${shim_dir}:${PATH}" M013_GH_STUB_DIR="$ae_stub_dir" \
  bash "$SYNC" --root "$rl_fx" --i-am-operator --repo-slug t/r </dev/null > /tmp/t03-ae.out 2>/tmp/t03-ae.err
rc=$?
if [ "$rc" -eq 4 ]; then pass "rc=4 on auth-expired pre-flight"; else fail "expected rc=4, got rc=${rc}"; fi
if grep -q 'AUTH-EXPIRED: run gh auth refresh' /tmp/t03-ae.err; then
  pass "AUTH-EXPIRED diagnostic emitted"
else
  fail "AUTH-EXPIRED diagnostic missing"
fi

rm -rf "$shim_dir" "$rl_fx" "$rl_stub_dir" "$ae_stub_dir"
echo "SUMMARY: m013-p04-rate-limit.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-rate-limit.sh"
  exit 0
fi
echo "FAIL: m013-p04-rate-limit.sh" >&2
exit 1
```

Note on AD-19 in this gate: the gate author may find the `{ ... } > file` block-redirect convenient for fixture seeding. That is a block (not a compound one-liner) and does not trigger the harness heuristic. Keep it.

### Step 6: Create gate `scripts/verify/m013-p04-observability.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p04-observability.sh — T03 gate: FR-17 observability emitters

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p04/sync-cycle"
SYNC="${REPO_ROOT}/scripts/integrations/github-sync.sh"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Assertion 1: emit_tier1_record helper defined
if grep -qE '^emit_tier1_record\(\)' "${REPO_ROOT}/scripts/integrations/github-common.sh"; then
  pass "emit_tier1_record defined"
else
  fail "emit_tier1_record missing"
fi

# Assertion 2: emit_conversus_gate_record helper defined
if grep -qE '^emit_conversus_gate_record\(\)' "${REPO_ROOT}/scripts/integrations/github-common.sh"; then
  pass "emit_conversus_gate_record defined"
else
  fail "emit_conversus_gate_record missing"
fi

# Assertion 3: github-sync.sh calls emit_tier1_record with unit_close type
if grep -qE 'emit_tier1_record unit_close' "$SYNC"; then
  pass "unit_close emitter wired"
else
  fail "unit_close emitter missing"
fi

# Assertion 4: dry-run does NOT emit JSONL
live_fx="$(mktemp -d -t m013-p04-obs.XXXXXX)"
cp -R "${FX}/orchestrator-state/"* "$live_fx/"
mkdir -p "${live_fx}/.orchestrator"
# Use --dry-run against fixture root; ORCHESTRATOR_ROOT points at tmp .orchestrator
> "${live_fx}/.orchestrator/execution-log.jsonl"
# Run dry-run
shim_dir="$(mktemp -d -t m013-p04-obs-shim.XXXXXX)"
cat > "${shim_dir}/gh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "${shim_dir}/gh"

PATH="${shim_dir}:${PATH}" M013_GH_STUB_DIR="${FX}/gh-stub-responses" \
  ORCHESTRATOR_ROOT="${live_fx}/.orchestrator" \
  bash "$SYNC" --root "${FX}/orchestrator-state" --i-am-operator \
  --repo-slug test/sync-fixture --dry-run </dev/null >/dev/null 2>&1 || true
if [ ! -s "${live_fx}/.orchestrator/execution-log.jsonl" ]; then
  pass "dry-run wrote zero JSONL records"
else
  fail "dry-run emitted JSONL (should not)"
fi

# Assertion 5: live mode writes JSONL records matching shape
PATH="${shim_dir}:${PATH}" M013_GH_STUB_DIR="${FX}/gh-stub-responses" \
  ORCHESTRATOR_ROOT="${live_fx}/.orchestrator" \
  bash "$SYNC" --root "${FX}/orchestrator-state" --i-am-operator \
  --repo-slug test/sync-fixture </dev/null >/dev/null 2>&1 || true
jsonl="${live_fx}/.orchestrator/execution-log.jsonl"
if [ -s "$jsonl" ]; then
  pass "live mode wrote JSONL"
else
  fail "live mode wrote no JSONL"
fi

# Assertion 6: every JSONL line conforms to shape (starts with ts, contains event, source=runtime)
bad=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    '{"ts":"'*'","event":"unit_close","source":"runtime"'*'}')
      : ;;
    '{"ts":"'*'","event":"conversus_gate_invocation","source":"runtime"'*'}')
      : ;;
    *) bad=$((bad + 1)) ;;
  esac
done < "$jsonl"
if [ "$bad" -eq 0 ]; then
  pass "every JSONL line M019 Tier 1 shape"
else
  fail "${bad} JSONL lines off-shape"
fi

# Assertion 7: at least one unit_close record present
if grep -qE '"event":"unit_close"' "$jsonl"; then
  pass "at least one unit_close record"
else
  fail "no unit_close records"
fi

# Assertion 8: FR-5 lint still green
if bash "${REPO_ROOT}/scripts/verify/graphql-call-shape.sh" >/dev/null 2>&1; then
  pass "FR-5 lint still green"
else
  fail "FR-5 lint REGRESSION"
fi

rm -rf "$shim_dir" "$live_fx"
echo "SUMMARY: m013-p04-observability.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-observability.sh"
  exit 0
fi
echo "FAIL: m013-p04-observability.sh" >&2
exit 1
```

## Must-Haves

From P04-PLAN:

- `scripts/integrations/github-common.sh` defines `classify_gh_rc` and `emit_conversus_gate_record`.
- `scripts/integrations/github-sync.sh` includes pre-flight rate-limit probe (triggered when projected mutations > 50), per-call rate-limit wrapper, `exit 3` on rate-limit, `exit 4` on auth-expired.
- `scripts/integrations/github-sync.sh` calls `emit_tier1_record unit_close ...` at the successful-upsert site; only in live mode; `source: "runtime"`; M019 Tier 1 shape.
- `scripts/verify/m013-p04-rate-limit.sh` passes (≥6 assertions).
- `scripts/verify/m013-p04-observability.sh` passes (≥8 assertions).
- FR-5 lint still green.
- P02/P03 suites still exit 0 byte-for-byte.
- T02 gates (`m013-p04-github-sync.sh`, `m013-p04-dry-run-manifest.sh`) still exit 0 (T03 changes are additive).

## Verification

```bash
bash scripts/verify/m013-p04-rate-limit.sh
bash scripts/verify/m013-p04-observability.sh
bash scripts/verify/m013-p04-github-sync.sh
bash scripts/verify/m013-p04-dry-run-manifest.sh
bash scripts/verify/graphql-call-shape.sh
```

All five exit 0.

## Inputs

### From Previous Tasks

- `scripts/integrations/github-common.sh` (from P04/T01) — T03 appends `classify_gh_rc` + `emit_conversus_gate_record` helpers.
  - Key API (T01): `http_probe <path>` — STATUS / RATE_LIMIT_REMAINING / RATE_LIMIT_RESET output; rc=3 rate-limit, rc=4 auth-expired, rc=1 other.
  - Key API (T01): `emit_tier1_record <type> <kv>...` — appends one JSONL line with `source: "runtime"`.
- `scripts/integrations/github-sync.sh` (from P04/T02) — T03 modifies additively: inserts pre-flight rate-limit probe before reconcile loop, wraps each live `gh` call with `classify_gh_rc`, wires `emit_tier1_record unit_close` after successful upsert.
  - Key variables: `cached_count`, `cached_oid_N`, `cached_synced_N`, `projected_mutations`, `DRY_RUN`, `MILESTONE_ID`.
- `tests/fixtures/m013-p04/sync-cycle/` (from P04/T01) — reused as the primary fixture; T03's gates construct additional rate-limit fixture tmp-dirs inline.

### From Disk (Pre-existing)

- `scripts/verify/graphql-call-shape.sh` (from M013/P03/T03) — regression guard.
- `scripts/verify/m013-p02-phase-suite.sh`, `scripts/verify/m013-p03-phase-suite.sh` — regression guards.
- `.orchestrator/execution-log.jsonl` — append-only JSONL log; `emit_tier1_record` appends here when `ORCHESTRATOR_ROOT` is unset, or to the fixture's `${ORCHESTRATOR_ROOT}/execution-log.jsonl` in tests.

## Constraints

- **Additive-only to github-sync.sh**: T03 inserts new blocks; does NOT rewrite T02's reconcile loop.
- **`source: "runtime"` hard-coded**: all Tier 1 records carry this value; never `planner` or `verify` (those belong to other sources in M019's schema).
- **FR-5 whitelist**: T03 introduces zero new GraphQL mutations. The rate-limit pre-flight is a REST call (`/rate_limit`) — outside the mutation-whitelist scope.
- **FR-11 reversibility**: rate-limit + auth-expiry exits release the lock via `release_lock` BEFORE `exit`.
- **SC-7 zero approval prompts**: rate-limit / auth-expiry paths do not prompt the user; they exit with a diagnostic. The auto-mode short-circuit in T02 already catches the no-TTY case.
- **Dry-run JSONL silence**: `emit_tier1_record` is NEVER called in `--dry-run` mode. Gate assertion 4 verifies this.
- **JSONL append-only**: `emit_tier1_record` appends one line per record; never rewrites or rotates the log. Verified by gate assertion 5.
- **Bash 3.2**: no forbidden idioms.
- **AD-19 Check shape**: gate commands are single-script-file invocations.
- **Integer-minutes duration** in T03-SUMMARY.md.
- **No changes to T02's dry-run manifest shape**: T02's `m013-p04-dry-run-manifest.sh` and `m013-p04-github-sync.sh` gates must still pass after T03 lands — T03 changes the dry-run path only by adding probe short-circuits that NEVER fire in dry-run mode.

## Expected Output

```
PASS: classify_gh_rc defined
PASS: rate-limit rc=3 path wired
PASS: auth-expired rc=4 path wired
PASS: rc=3 on rate-limit pre-flight
PASS: RATE-LIMIT retry-after diagnostic emitted
PASS: rc=4 on auth-expired pre-flight
PASS: AUTH-EXPIRED diagnostic emitted
SUMMARY: m013-p04-rate-limit.sh pass=7 fail=0
PASS: m013-p04-rate-limit.sh

PASS: emit_tier1_record defined
PASS: emit_conversus_gate_record defined
PASS: unit_close emitter wired
PASS: dry-run wrote zero JSONL records
PASS: live mode wrote JSONL
PASS: every JSONL line M019 Tier 1 shape
PASS: at least one unit_close record
PASS: FR-5 lint still green
SUMMARY: m013-p04-observability.sh pass=8 fail=0
PASS: m013-p04-observability.sh
```

Estimated duration: 50 integer minutes.
