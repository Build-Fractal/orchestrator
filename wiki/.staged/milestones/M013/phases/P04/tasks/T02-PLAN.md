---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M013"
name: "github-sync.sh core — state walker + per-item upsert engine + --dry-run manifest + lock acquisition + updateProjectV2ItemFieldValue mutation + sidecar cache update"
depends_on: ["T01"]
---

## Prerequisites

- Bash 3.2 target (MEM001). AD-19 `Check:` shape for every verification command.
- T01 has landed `tests/fixtures/m013-p04/sync-cycle/` fixture tree and the three new public helpers (`http_probe`, `sidecar_update_item_cache`, `emit_tier1_record`) in `scripts/integrations/github-common.sh`.
- P02 shipped `scripts/integrations/github-init.sh` (~644 lines): `while`-loop flag parser (lines ~48-62), auto-mode pending-sentinel short-circuit (lines ~78-94), milestone discovery, state walker with AS-4a lazy projection, preflight fan-out, live create fan-out, `manifest_footer` emit. The walker shape is the template T02 reuses. Copy the walker pattern — do NOT re-invoke `github-init.sh`.
- P02 shipped `scripts/lifecycle/lock-manager.sh` with subcommands `create --owner <name> --reason <text>`, `release <lock-id>`, `status`. Lock file lives at `.orchestrator/lock.json`.
- P02 shipped the `sidecar_upsert_item` helper in `github-common.sh` for initial item insertion; T02 uses T01's `sidecar_update_item_cache` for mutation of existing cached items.
- P03 pre-whitelisted `updateProjectV2ItemFieldValue` in `scripts/verify/graphql-call-shape.sh`. T02 introduces this mutation; it must pass the FR-5 lint on arrival (zero edits to the lint needed).
- P03 ships `gh_marker_search_remote <repo-slug> <oid>` which T02 uses to search-before-create on every sync upsert.
- [M019](../../../../../milestones/M019/index.md) Tier 1 JSONL shape for `unit_close`: `{"ts":"<ISO>","event":"unit_close","source":"runtime","milestone":"<M###>","phase":"<P##>","task":"<T##>|null","oid":"<orchestrator-id>","issue_number":<int>,"outcome":"closed|status-synced"}`. T03 ships the emit sites; T02 emits `UPSERT:` manifest rows but NOT JSONL records yet (JSONL arrives in T03 layered on top).
- Known orchestrator bug: integer-minutes duration only.
- The conversus gate invocation (`--conversus-gate` flag handling inside `github-sync.sh`) is scaffolded in T02 as a no-op flag (flag parsed, variable set) but the actual `github-conversus-gate.sh` invocation site arrives in T05.

## Description

Author `scripts/integrations/github-sync.sh` — the core sync engine. This script is the symmetric partner to P02's `github-init.sh`: same walker shape, same flag-parser layout, same auto-mode short-circuit, same lock-acquire-before-write discipline, same marker-search-before-write idempotency, same `manifest_upsert_line` + `manifest_footer` output contract. Where `init` is a projection-writer's **create** pass (populate empty remote from orchestrator state), `sync` is a **reconcile** pass (diff cached-vs-desired state and push deltas, not a full re-create).

The key differences from `init`:

1. **No create fan-out**: sync consumes an already-populated sidecar (`STATUS: configured`). If the sidecar is absent or holds pending sentinels, sync emits `STATUS: pending-operator-complete`, exits 0 (no-op per FR-11 reversibility), and touches nothing.
2. **Diff-driven**: for each cached `items.<oid>`, sync computes the desired state from orchestrator state (walker → projected state) and emits one of `skip-nochange`, `close`, `status-sync` as the UPSERT reason. `create` and `adopt` are `init` vocabulary — sync never emits them.
3. **GraphQL mutation**: when a phase is Done on disk but `status_field_synced: false` in sidecar, sync issues `updateProjectV2ItemFieldValue` to flip the Project v2 status field. This is the third and final whitelisted GraphQL mutation in M013.
4. **Lock-bounded**: sync acquires the lifecycle lock via `lock-manager.sh create` at entry and releases on every exit path (EXIT trap). FR-7 mandates lock acquisition for the entire reconcile pass.
5. **Sidecar cache update**: on every successful per-item operation, sync updates `last_attempt_at` to now, `last_error: null`, `status_field_synced: true`, `project_v2_attached: true` via the T01-authored `sidecar_update_item_cache` helper. On error, sync updates `last_error` to a diagnostic string.

The manifest shape — `DRY-RUN:` header + per-row `UPSERT: <kind> <oid> <target> <reason>` + footer `upserts=<N> skipped=<M> errors=<E>` — is byte-identical to `init`. T02's `expected-sync-dryrun-manifest.txt` is the pinned SSOT snapshot for diff comparison.

## Steps

### Step 1: Scaffold `scripts/integrations/github-sync.sh`

Create the file with the standard header + shebang + flag parser + auto-mode short-circuit + lock acquisition + state walker + reconcile loop + footer emit. Mirror the layout of `github-init.sh` — same section comments, same ordering. Target minimum 500 lines fully commented.

Top-of-file:

```bash
#!/usr/bin/env bash
# scripts/integrations/github-sync.sh — M013/P04 sync cycle
#
# Reconciles orchestrator state with GitHub. Consumes a populated sidecar
# from P02's `orchestrator:github init` pass and pushes per-item deltas
# (sub-Issue closes + Project v2 status-field updates) to the remote.
#
# Contracts:
#   - FR-4: search-before-create on every upsert (marker-based)
#   - FR-5: mutations limited to {createProjectV2, addProjectV2ItemById,
#           updateProjectV2ItemFieldValue}. Sync introduces only the third.
#   - FR-7: acquires lifecycle lock for the duration of the run
#   - FR-11: no-op cleanly when sidecar absent / pending
#   - FR-12: Claude-Code-only v1 (no runtime-specific branching)
#   - FR-15: --dry-run manifest byte-identical-shape to init --dry-run
#   - FR-16: rate-limit + auth-expiry detection (T03 layers on this)
#   - FR-17: observability emitters (T03 layers unit_close JSONL on this)
#   - SC-7: zero approval prompts under auto-mode (pending-sentinel exit)
#
# Bash 3.2 compatible (MEM001).

set -u
```

### Step 2: Flag parser + defaults

Mirror `github-init.sh` parser:

```bash
DRY_RUN=0
OPERATOR=0
ROOT="."
REPO_SLUG=""
CONVERSUS_GATE=0
TIMEOUT=30

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --i-am-operator) OPERATOR=1; shift ;;
    --root) ROOT="$2"; shift 2 ;;
    --repo-slug) REPO_SLUG="$2"; shift 2 ;;
    --conversus-gate) CONVERSUS_GATE=1; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
Usage: github-sync.sh [--dry-run] [--i-am-operator] [--root <path>]
                      [--repo-slug <slug>] [--conversus-gate]
                      [--timeout <sec>]

Reconciles orchestrator state with GitHub Issues / Milestones / Projects v2.
See references/github-integration.md (Sync Modes) for full contract.
EOF
      exit 0
      ;;
    *) shift ;;
  esac
done
```

### Step 3: Auto-mode short-circuit (SC-7)

Immediately after flag parse, BEFORE any `gh` call or lock acquisition:

```bash
# SC-7: zero approval prompts under auto-mode.
# Reuses the same detect-interactive logic as github-init.sh.
if [ ! -t 0 ] && [ "$OPERATOR" -eq 0 ]; then
  echo "STATUS: pending-operator-complete"
  echo "MESSAGE: sync requires --i-am-operator in non-interactive mode"
  exit 0
fi
```

### Step 4: Source common helpers + resolve paths

```bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "${REPO_ROOT}/scripts/integrations/github-common.sh"

ORCHESTRATOR_ROOT="${ROOT}/.orchestrator"
SIDECAR_TARGET="${ORCHESTRATOR_ROOT}/integrations/github.json"

if [ ! -f "$SIDECAR_TARGET" ]; then
  echo "STATUS: pending-operator-complete"
  echo "MESSAGE: sidecar absent at ${SIDECAR_TARGET}"
  exit 0
fi
if grep -q '"pending"' "$SIDECAR_TARGET"; then
  echo "STATUS: pending-operator-complete"
  exit 0
fi
```

### Step 5: Acquire the lifecycle lock (FR-7)

```bash
LOCK_MGR="${REPO_ROOT}/scripts/lifecycle/lock-manager.sh"
LOCK_ID=""
acquire_lock() {
  if [ "$DRY_RUN" -eq 1 ]; then return 0; fi
  LOCK_ID="$(bash "$LOCK_MGR" create --owner github-sync --reason "M013 P04 sync" --root "$ORCHESTRATOR_ROOT" 2>/dev/null | awk -F= '/^lock_id=/ { print $2; exit }')"
  if [ -z "$LOCK_ID" ]; then
    echo "FAIL: lock acquisition failed" >&2
    exit 6
  fi
}
release_lock() {
  if [ -n "$LOCK_ID" ]; then
    bash "$LOCK_MGR" release "$LOCK_ID" --root "$ORCHESTRATOR_ROOT" >/dev/null 2>&1 || true
    LOCK_ID=""
  fi
}
trap 'release_lock' EXIT INT TERM HUP

acquire_lock
```

### Step 6: Parse sidecar → cached items table

Use awk to extract each `items.<oid>` block into parallel indexed arrays `cached_oid_N`, `cached_issue_N`, `cached_synced_N`, `cached_attached_N`:

```bash
cached_count=0
parse_cached_items() {
  local in_items=0 oid="" issue="" synced="" attached=""
  # Simple line-based JSON walker targeting the flat items map.
  while IFS= read -r line; do
    case "$line" in
      *\"items\":*)
        in_items=1
        continue
        ;;
    esac
    [ "$in_items" -eq 0 ] && continue
    case "$line" in
      *\"M*\"*:*\{*)
        oid="$(printf '%s\n' "$line" | sed -E 's/.*"(M[A-Z0-9\-]+)": *\{.*/\1/')"
        issue=""; synced=""; attached=""
        ;;
      *issue_number*)
        issue="$(printf '%s\n' "$line" | sed -E 's/.*"issue_number": *([0-9]+).*/\1/')"
        ;;
      *status_field_synced*)
        synced="$(printf '%s\n' "$line" | sed -E 's/.*"status_field_synced": *(true|false).*/\1/')"
        ;;
      *project_v2_attached*)
        attached="$(printf '%s\n' "$line" | sed -E 's/.*"project_v2_attached": *(true|false).*/\1/')"
        ;;
      *\}*)
        if [ -n "$oid" ] && [ -n "$issue" ]; then
          eval "cached_oid_${cached_count}=\"${oid}\""
          eval "cached_issue_${cached_count}=\"${issue}\""
          eval "cached_synced_${cached_count}=\"${synced:-false}\""
          eval "cached_attached_${cached_count}=\"${attached:-false}\""
          cached_count=$((cached_count + 1))
          oid=""
        fi
        ;;
    esac
  done < "$SIDECAR_TARGET"
}
parse_cached_items
```

### Step 7: State walker → desired state table

Walk `${ROOT}/.orchestrator/milestones/*/` (same walker pattern as `github-init.sh`'s lazy projection):

For each milestone, phase, and task, derive the desired state:

- Milestone: always `desired=track`.
- Phase: `desired=done` if `P##-SUMMARY.md` exists with `verification_result: "pass"`; `desired=ready` otherwise.
- Task (only for Done phases): `desired=done` if `T##-SUMMARY.md` exists with `verification_result: "pass"`; else `desired=ready`.

Store in parallel indexed arrays `desired_oid_N`, `desired_state_N`.

### Step 8: Reconcile loop — emit UPSERT rows

For each cached item, look up its desired state and emit one manifest row:

```bash
upserts=0; skipped=0; errors=0

echo "DRY-RUN: sync manifest for ${MILESTONE_ID:-unknown} (repo=${REPO_SLUG:-unknown})"

i=0
while [ "$i" -lt "$cached_count" ]; do
  eval "oid=\"\${cached_oid_${i}}\""
  eval "issue=\"\${cached_issue_${i}}\""
  eval "synced=\"\${cached_synced_${i}}\""
  desired="$(lookup_desired "$oid")"
  reason=""
  case "$desired:$synced" in
    done:false)
      reason="status-sync"
      if [ "$(kind_of "$oid")" = "task-subissue" ]; then
        reason="close"
      fi
      upserts=$((upserts + 1))
      ;;
    done:true)  reason="skip-nochange"; skipped=$((skipped + 1)) ;;
    ready:*)    reason="skip-nochange"; skipped=$((skipped + 1)) ;;
    *)          reason="skip-nochange"; skipped=$((skipped + 1)) ;;
  esac

  manifest_upsert_line "$(kind_of "$oid")" "$oid" "$issue" "$reason"

  # Live mode: issue mutation + update sidecar.
  if [ "$DRY_RUN" -eq 0 ] && [ "$reason" != "skip-nochange" ]; then
    if ! perform_upsert "$oid" "$issue" "$reason"; then
      errors=$((errors + 1))
      sidecar_update_item_cache "$oid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "upsert-failed" "false" "true" "$ROOT"
    else
      sidecar_update_item_cache "$oid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "null" "true" "true" "$ROOT"
    fi
  fi

  i=$((i + 1))
done

manifest_footer "$upserts" "$skipped" "$errors"
```

### Step 9: `perform_upsert` — issue the mutations

Two cases:

- `reason="close"` on a task-subissue: `gh issue close <issue-number> -R <repo-slug> --reason completed`.
- `reason="status-sync"` on a phase-issue: GraphQL `updateProjectV2ItemFieldValue` mutation.

```bash
perform_upsert() {
  local oid="$1" issue="$2" reason="$3"
  case "$reason" in
    close)
      if [ -n "${M013_GH_STUB_DIR:-}" ]; then
        # Fixture mode: no-op success.
        return 0
      fi
      gh issue close "$issue" -R "$REPO_SLUG" --reason completed >/dev/null 2>&1
      return $?
      ;;
    status-sync)
      # GraphQL mutation — the third and final whitelisted shape.
      local pid iid fid val
      pid="$PROJECT_V2_ID"
      iid="$(lookup_project_v2_item_id "$oid")"
      fid="$(lookup_status_field_id)"
      val="$(lookup_done_option_id)"
      if [ -n "${M013_GH_STUB_DIR:-}" ]; then
        cat "${M013_GH_STUB_DIR}/graphql-update-status-field-success.json"
        return 0
      fi
      gh api graphql \
        -F pid="$pid" -F iid="$iid" -F fid="$fid" -F val="$val" \
        --field query='mutation($pid:ID!,$iid:ID!,$fid:ID!,$val:String!){updateProjectV2ItemFieldValue(input:{projectId:$pid,itemId:$iid,fieldId:$fid,value:{singleSelectOptionId:$val}}){projectV2Item{id}}}' \
        >/dev/null 2>&1
      return $?
      ;;
  esac
  return 1
}
```

This is the `mutation-lparen` anchor shape that `scripts/verify/graphql-call-shape.sh` whitelists — the awk regex matches `mutation(...){updateProjectV2ItemFieldValue(...` and the pre-whitelist in P03/T03 means this passes FR-5 on arrival.

### Step 10: Create gate `scripts/verify/m013-p04-github-sync.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p04-github-sync.sh — T02 gate: github-sync.sh core

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p04/sync-cycle"
SYNC="${REPO_ROOT}/scripts/integrations/github-sync.sh"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Assertion 1: script exists + is executable
if [ -x "$SYNC" ]; then pass "github-sync.sh present + executable"; else fail "github-sync.sh missing or not executable"; fi

# Assertion 2: script sources github-common.sh
if grep -qE '^\. .*github-common\.sh"?$' "$SYNC" || grep -qE '^source .*github-common\.sh' "$SYNC"; then
  pass "github-common.sh sourced"
else
  fail "github-common.sh not sourced"
fi

# Assertion 3: script contains updateProjectV2ItemFieldValue mutation shape
if grep -qE 'mutation.*\{.*updateProjectV2ItemFieldValue' "$SYNC"; then
  pass "updateProjectV2ItemFieldValue mutation shape present"
else
  fail "updateProjectV2ItemFieldValue mutation shape missing"
fi

# Assertion 4: FR-5 lint still passes
if bash "${REPO_ROOT}/scripts/verify/graphql-call-shape.sh" >/dev/null 2>&1; then
  pass "FR-5 lint green with new mutation"
else
  fail "FR-5 lint REGRESSION on new mutation"
fi

# Assertion 5: script invokes lock-manager
if grep -qE 'lock-manager\.sh create' "$SYNC"; then
  pass "lock-manager.sh invoked"
else
  fail "lock-manager.sh not invoked"
fi

# Assertion 6: EXIT trap set for lock release
if grep -qE "trap.*release_lock.*EXIT" "$SYNC"; then
  pass "EXIT trap releases lock"
else
  fail "EXIT trap missing"
fi

# Assertion 7: auto-mode short-circuit present
if grep -qE 'pending-operator-complete' "$SYNC"; then
  pass "auto-mode short-circuit present"
else
  fail "auto-mode short-circuit missing"
fi

# Assertion 8: --dry-run flag recognized
if bash "$SYNC" --help 2>&1 | grep -q -- "--dry-run"; then
  pass "--dry-run in help"
else
  fail "--dry-run not in help"
fi

# Assertion 9: auto-mode (no TTY + no --i-am-operator) exits 0 with STATUS line + no gh call
shim_dir="$(mktemp -d -t m013-p04-t02-shim.XXXXXX)"
call_log="${shim_dir}/calls.log"
: > "$call_log"
cat > "${shim_dir}/gh" <<'SHIM'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >> "${SHIM_CALL_LOG:-/tmp/gh-calls.log}"
exit 0
SHIM
chmod +x "${shim_dir}/gh"
PATH="${shim_dir}:${PATH}" SHIM_CALL_LOG="$call_log" \
  bash "$SYNC" --root "${FX}/orchestrator-state" --dry-run </dev/null >/tmp/t02-automode.out 2>&1 || true
if grep -q 'pending-operator-complete' /tmp/t02-automode.out; then
  pass "auto-mode emits pending-sentinel"
else
  fail "auto-mode did NOT emit pending-sentinel"
fi
if [ -s "$call_log" ]; then
  fail "auto-mode issued $(wc -l <"$call_log") gh calls (should be zero)"
else
  pass "zero gh calls under auto-mode"
fi

# Assertion 10: dry-run fixture produces manifest
export M013_GH_STUB_DIR="${FX}/gh-stub-responses"
out="$(bash "$SYNC" --root "${FX}/orchestrator-state" --i-am-operator \
  --repo-slug test/sync-fixture --dry-run 2>/dev/null || true)"
if printf '%s\n' "$out" | grep -qE '^DRY-RUN:'; then
  pass "dry-run manifest header emitted"
else
  fail "dry-run manifest header missing"
fi

# Assertion 11: manifest contains UPSERT rows
if printf '%s\n' "$out" | grep -qE '^UPSERT: [a-z\-]+ [^ ]+ [^ ]+ [a-z\-]+$'; then
  pass "UPSERT rows present"
else
  fail "no UPSERT rows"
fi

# Assertion 12: manifest footer has P02 3-field shape (no adopted=)
if printf '%s\n' "$out" | grep -qE '^upserts=[0-9]+ skipped=[0-9]+ errors=[0-9]+$'; then
  pass "footer has P02 3-field shape"
else
  fail "footer shape mismatch"
fi

# Assertion 13: byte-identical diff vs expected snapshot
diff_out="$(diff "${FX}/expected-sync-dryrun-manifest.txt" <(printf '%s\n' "$out"))"
if [ -z "$diff_out" ]; then
  pass "manifest byte-identical to expected snapshot"
else
  fail "manifest diff vs expected snapshot (see /tmp/t02-manifest-diff.out)"
  printf '%s\n' "$diff_out" > /tmp/t02-manifest-diff.out
fi

rm -rf "$shim_dir"
echo "SUMMARY: m013-p04-github-sync.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-github-sync.sh"
  exit 0
fi
echo "FAIL: m013-p04-github-sync.sh" >&2
exit 1
```

Note: The diff line uses `<(...)` process substitution which is an AD-19 forbidden shape. Re-shape the assertion to write both outputs to temp files and diff them directly:

```bash
# Assertion 13 replacement (AD-19 compliant):
printf '%s\n' "$out" > /tmp/t02-manifest-actual.out
if diff "${FX}/expected-sync-dryrun-manifest.txt" /tmp/t02-manifest-actual.out >/tmp/t02-manifest-diff.out 2>&1; then
  pass "manifest byte-identical to expected snapshot"
else
  fail "manifest diff vs expected snapshot (see /tmp/t02-manifest-diff.out)"
fi
```

### Step 11: Create gate `scripts/verify/m013-p04-dry-run-manifest.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p04-dry-run-manifest.sh — T02 gate: dry-run manifest
# byte-identical-shape to init --dry-run.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p04/sync-cycle"
SYNC="${REPO_ROOT}/scripts/integrations/github-sync.sh"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

export M013_GH_STUB_DIR="${FX}/gh-stub-responses"
out="$(bash "$SYNC" --root "${FX}/orchestrator-state" --i-am-operator \
  --repo-slug test/sync-fixture --dry-run 2>/dev/null || true)"
printf '%s\n' "$out" > /tmp/t02-dryrun.out

# Shape assertion: header regex
if grep -qE '^DRY-RUN:' /tmp/t02-dryrun.out; then pass "DRY-RUN: header"; else fail "DRY-RUN: header"; fi

# Shape assertion: per-row regex
row_count="$(grep -cE '^UPSERT: [a-z\-]+ [^ ]+ [^ ]+ [a-z\-]+$' /tmp/t02-dryrun.out || true)"
if [ "${row_count:-0}" -ge 3 ]; then pass "≥3 UPSERT rows shape-match"; else fail "UPSERT rows shape-match"; fi

# Shape assertion: footer regex (P02 3-field)
if grep -qE '^upserts=[0-9]+ skipped=[0-9]+ errors=[0-9]+$' /tmp/t02-dryrun.out; then
  pass "footer P02 3-field shape"
else
  fail "footer shape"
fi

# Byte-identity with expected snapshot
if diff "${FX}/expected-sync-dryrun-manifest.txt" /tmp/t02-dryrun.out >/dev/null 2>&1; then
  pass "manifest byte-identical"
else
  fail "manifest byte-identity regression"
fi

echo "SUMMARY: m013-p04-dry-run-manifest.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-dry-run-manifest.sh"
  exit 0
fi
echo "FAIL: m013-p04-dry-run-manifest.sh" >&2
exit 1
```

## Must-Haves

From P04-PLAN:

- `scripts/integrations/github-sync.sh` exists, is executable, and passes shape assertions (sources `github-common.sh`, contains `updateProjectV2ItemFieldValue` mutation, invokes `lock-manager.sh`, sets EXIT trap, honors auto-mode short-circuit, recognizes `--dry-run`).
- `scripts/integrations/github-sync.sh --dry-run` against the T01 fixture emits a manifest byte-identical to `tests/fixtures/m013-p04/sync-cycle/expected-sync-dryrun-manifest.txt`.
- Manifest shape is P02 3-field footer (`upserts=N skipped=M errors=E` — no `adopted=`).
- `scripts/verify/graphql-call-shape.sh` still exits 0.
- `scripts/verify/m013-p04-github-sync.sh` passes (≥13 assertions).
- `scripts/verify/m013-p04-dry-run-manifest.sh` passes (≥4 assertions).
- P02/P03 phase suites still exit 0 byte-for-byte.

## Verification

```bash
bash scripts/verify/m013-p04-github-sync.sh
bash scripts/verify/m013-p04-dry-run-manifest.sh
bash scripts/verify/graphql-call-shape.sh
```

All three exit 0. Then regression:

```bash
bash scripts/verify/m013-p02-phase-suite.sh
bash scripts/verify/m013-p03-phase-suite.sh
```

Both exit 0.

## Inputs

### From Previous Tasks

- `scripts/integrations/github-common.sh` (from P04/T01, inherited from P02/T01 + P03/T01)
  - Key API: `gh_marker_search_remote <repo-slug> <oid>` — returns Issue number on unique hit.
  - Key API: `manifest_upsert_line <kind> <oid> <target> <reason>` — emits one manifest line.
  - Key API: `manifest_footer <upserts> <skipped> <errors> [<adopted>]` — T02 calls the 3-arg form (no `adopted=` suffix in sync path).
  - Key API: `shasum_marker_byte_identity <body-file> <oid>` — FR-4 byte-identity verification.
  - Key API (NEW from T01): `http_probe <path>` — returns STATUS + RATE_LIMIT_REMAINING + RATE_LIMIT_RESET. T02 uses this in Step 11's pre-flight rate-limit check only when projected GraphQL volume > 50 (in this fixture, below threshold — optional invocation deferred to T03).
  - Key API (NEW from T01): `sidecar_update_item_cache <oid> <iso-ts> <error-or-null> <synced-bool> <attached-bool> [<root>]` — T02 calls this on every live-mode upsert outcome.
  - Key API (NEW from T01): `emit_tier1_record` — T02 SCAFFOLDS but does not INVOKE this helper; T03 wires the call sites.
- `tests/fixtures/m013-p04/sync-cycle/` (from P04/T01)
  - Shape: `orchestrator-state/` seed (Done P01-FIX + Ready P02-FIX) + populated sidecar + `gh-stub-responses/` + `expected-sync-dryrun-manifest.txt` snapshot.

### From Disk (Pre-existing)

- `scripts/integrations/github-init.sh` (from M013/P02/T02 + P03/T02)
  - Reference implementation for: flag parser layout, auto-mode short-circuit, state walker, `MILESTONE_ID` discovery, `manifest_upsert_line` / `manifest_footer` usage patterns.
  - T02 does NOT modify `github-init.sh`. It copies the walker shape into `github-sync.sh` as new code.
- `scripts/lifecycle/lock-manager.sh` (from M001/P03)
  - Key API: `create --owner <name> --reason <text> --root <.orchestrator>` → emits `lock_id=<uuid>` on stdout; `release <lock-id> --root <.orchestrator>` → releases.
  - Lock file lives at `.orchestrator/lock.json`.
- `scripts/verify/graphql-call-shape.sh` (from M013/P03/T03)
  - FR-5 lint. Pre-whitelisted `updateProjectV2ItemFieldValue` means T02's new mutation passes on arrival.
- `scripts/verify/m013-p02-phase-suite.sh`, `scripts/verify/m013-p03-phase-suite.sh` (prior-phase gates)
  - Regression guards.

## Constraints

- **P01/P02/P03 byte-identity**: all prior phase suites must still exit 0 after T02 lands. Run each as regression.
- **FR-5 whitelist**: T02 introduces exactly ONE new mutation shape — `updateProjectV2ItemFieldValue` — which P03/T03 pre-whitelisted. No fourth shape. The mutation must use the `mutation(...){updateProjectV2ItemFieldValue(...` literal shape so the FR-5 awk regex matches.
- **FR-4 marker invariant**: every sync upsert must search-before-act via `gh_marker_search_remote`. A duplicate marker is a bug — T02 honors this by consuming the cached `issue_number` and verifying against the marker search on the first live call.
- **FR-7 lock acquisition**: the entire reconcile pass runs under the lifecycle lock. Lock is acquired BEFORE any `gh` write call and released on every exit path (EXIT trap).
- **FR-11 reversibility**: sidecar absent / pending → `STATUS: pending-operator-complete` + exit 0 (no-op). T02 checks sidecar presence BEFORE acquiring the lock.
- **FR-12 Claude-Code-only v1**: no runtime-specific branching; `github-sync.sh` runs identically under CC / Codex CLI / Cursor (the packaging layer's Claude-Code-specific post-verify hook arrives in T04).
- **FR-15 dry-run shape**: manifest byte-identical-shape to `init --dry-run`. T02's expected-sync-dryrun-manifest snapshot is the pinned SSOT.
- **SC-7 zero approval prompts**: auto-mode short-circuit fires BEFORE any `gh` call; verified by the T02 gate's PATH-shim assertion.
- **Knowledge-Layer Boundary (D014)**: no knowledge/spec/ writes, no KNOWLEDGE-INDEX.md, no rebuild-index.sh changes.
- **Bash 3.2**: no `declare -A`, no `mapfile`, no `<(...)`/`>(...)` (including in gate scripts — use temp-file + diff pattern), no `&>`/`|&`, no `${var^^}`/`${var,,}`.
- **AD-19 `Check:` shape**: gate commands are single-script-file invocations. No inline compound bash, no plain subshells, no `$()` containing pipes, no process substitution.
- **Integer-minutes duration** in T02-SUMMARY.md.
- **No modifications to prior-phase deliverables**: `github-init.sh` stays byte-identical. `github-common.sh` gains no new helpers in T02 (T01 authored the three P04 helpers; T03 may add rate-limit-specific helpers).
- **No JSONL emission yet**: T02 scaffolds `emit_tier1_record` usage sites but does not wire them (T03 owns observability emission).

## Expected Output

```
PASS: github-sync.sh present + executable
PASS: github-common.sh sourced
PASS: updateProjectV2ItemFieldValue mutation shape present
PASS: FR-5 lint green with new mutation
PASS: lock-manager.sh invoked
PASS: EXIT trap releases lock
PASS: auto-mode short-circuit present
PASS: --dry-run in help
PASS: auto-mode emits pending-sentinel
PASS: zero gh calls under auto-mode
PASS: dry-run manifest header emitted
PASS: UPSERT rows present
PASS: footer has P02 3-field shape
PASS: manifest byte-identical to expected snapshot
SUMMARY: m013-p04-github-sync.sh pass=14 fail=0
PASS: m013-p04-github-sync.sh

PASS: DRY-RUN: header
PASS: ≥3 UPSERT rows shape-match
PASS: footer P02 3-field shape
PASS: manifest byte-identical
SUMMARY: m013-p04-dry-run-manifest.sh pass=4 fail=0
PASS: m013-p04-dry-run-manifest.sh
```

Estimated duration: 75 integer minutes.
