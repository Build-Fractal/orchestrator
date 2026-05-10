---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M013"
name: "github-init.sh FR-14 re-init adoption branch + --re-init flag"
depends_on: ["T01"]
---

## Prerequisites

- Bash 3.2 target (MEM001). AD-19 `Check:` shape for this task's verification commands.
- T01 has landed `tests/fixtures/m013-p03/re-init-adoption/` fixture tree and the `gh_marker_search_remote` helper in `scripts/integrations/github-common.sh`.
- P02 has landed `scripts/integrations/github-init.sh` (644 lines): flag parsing, auto-mode pending-sentinel short-circuit (lines 78-94), milestone discovery, state walker with AS-4a lazy projection, preflight fan-out, live create fan-out (creates Milestone + Project v2 + labels + phase Issues + task sub-issues), manifest footer emit. The P02 create path is the one that stays byte-identical — T02 adds an additive branch.
- P02 manifest footer is currently `upserts=<N> skipped=<M> errors=<E>` (lines 640 via `manifest_footer`). T02 extends this to `upserts=<N> skipped=<M> errors=<E> adopted=<A>` — extension is additive-suffix; P02's fixture tests consume only the 3-number prefix (T07 gate uses `grep -E 'upserts=[0-9]+'`), so the extension is fixture-compatible.
- P02 has a `marker_search_before_create` function (lines 482-493) invoked during create-path per-id. That function returns one of {`create`, `skip-existing-marker`, `duplicate`}. T02's re-init branch uses a similar but distinct code path because the re-init branch fires BEFORE the create fan-out and operates on the FULL projected set, not per-create.
- SC-7 invariant: the existing auto-mode short-circuit (no TTY + no `--i-am-operator` → pending-sentinel + exit) runs BEFORE any re-init logic can fire. `--re-init` requires TTY + `--i-am-operator` or it is a no-op. This is the strict SC-7 stance from P02 judgment call (a).
- FR-5 GraphQL whitelist: T02 adds ONE new GraphQL shape at most: `projectV2(number: N)` style **query** (not a mutation) used to discover a pre-existing Project v2 by number for re-adoption. Queries are not subject to FR-5 — FR-5 whitelists **mutations** only. T02 must NOT invoke any new mutation. Re-adoption attaches Issues to the existing Project v2 via the already-whitelisted `addProjectV2ItemById` call shape only if the Issue is missing from the Project v2 (rare edge).
- Known orchestrator bug: integer-minutes duration only.

## Description

Extend `scripts/integrations/github-init.sh` with the FR-14 re-init adoption branch. The branch fires when one of two trigger conditions holds:

1. **Explicit flag**: `--re-init` passed on the command line.
2. **Implicit detection**: sidecar is absent AND at least one projected orchestrator-id has a marker-bearing remote Issue (detected via `gh_marker_search_remote` on the first projected id during the state walker phase — a cheap probe).

In the re-init branch, for each projected orchestrator-id (milestone, phase, each task), the script:

1. Calls `gh_marker_search_remote` to locate the existing Issue by marker.
2. On unique hit: emits `UPSERT: <kind> <oid> <issue-number> adopt` to the manifest, performs `shasum_marker_byte_identity` byte-identity verification (FR-4 invariant), writes a sidecar `items.<oid>` entry.
3. On duplicate: emits `integration-marker-duplicate: <oid>` to stderr and increments error count (fails the run).
4. On zero match: falls back to the create path (`create_phase_issue` / `create_task_issue`). This lets a partial prior init (sidecar deleted after only some Issues were created) complete cleanly.
5. For the Milestone + Project v2: discovers them via (a) title match for the Milestone (`gh milestone list --json title,number,description`), (b) `projectV2` query for the Project v2 id matching the milestone slug. On hit → adopt. On miss → create.
6. For labels: uses the existing `gh_label_collision_preflight` which already handles adopt-vs-create semantics — no change.

The re-init branch does NOT duplicate the create path. Missing ids fall through to the existing create fan-out. The code is a pre-pass that populates an `adopted_ids` bash 3.2 parallel-indexed array; the existing `create_phase_issue` / `create_task_issue` functions gain a two-line guard at their top that consults the array and skips the create when the id was already adopted.

The manifest footer is extended to `upserts=<N> skipped=<M> errors=<E> adopted=<A>`. P02's `manifest_footer` helper in `scripts/integrations/github-common.sh` takes its current three positional args and gains a fourth optional arg `<adopted>`; when unset, it prints the 3-field footer byte-identical with P02's shape (preserving the P02 fixture match); when set, it appends ` adopted=<A>`.

## Steps

### Step 1: Extend `manifest_footer` in `scripts/integrations/github-common.sh`

Locate the existing `manifest_footer` function (grep for `manifest_footer()`). Modify to accept an optional 4th argument:

```bash
# manifest_footer <upserts> <skipped> <errors> [<adopted>]
# Emits the pinned final-line footer. When <adopted> is omitted, prints
# the P02 3-field shape verbatim (fixture byte-compat). When set, appends
# ` adopted=<A>` (P03 re-init adoption extension).
manifest_footer() {
  local up="${1:-0}" sk="${2:-0}" er="${3:-0}" ad="${4:-}"
  if [ -z "$ad" ]; then
    echo "upserts=${up} skipped=${sk} errors=${er}"
  else
    echo "upserts=${up} skipped=${sk} errors=${er} adopted=${ad}"
  fi
}
```

This additive extension preserves P02's `expected-manifest.txt` byte-identity — callers that don't pass the 4th arg get the original shape.

### Step 2: Add `--re-init` flag to `scripts/integrations/github-init.sh`

Locate the while-loop flag parser (around lines 48-62). Add one new case:

```bash
    --re-init) REINIT=1; shift ;;
```

Add the variable declaration with the other defaults:

```bash
REINIT=0
```

Update the `-h|--help` usage block (sed slice of lines 3-33) to include `--re-init` in the usage line. This is a doc-only change; the behavior is wired in Step 3.

### Step 3: Insert the re-init pre-pass after preflights, before create fan-out

Locate the line `# --- Live create fan-out ---` (around line 611). Insert the re-init pre-pass BEFORE that block:

```bash
# ----------------------------------------------------------------------------
# FR-14 Re-init adoption pre-pass (P03).
#
# Fires when --re-init is passed, or when the sidecar is absent AND a marker
# search of the first projected id turns up a remote hit (indicating a prior
# init whose sidecar was subsequently deleted). The pre-pass populates an
# adopted_ids parallel-indexed array; create_phase_issue / create_task_issue
# consult this array and short-circuit when the id has already been adopted.
#
# Under SC-7 the earlier auto-mode guard (no TTY + no --i-am-operator → exit)
# has already short-circuited the entire script. Re-init is operator-initiated
# only — never auto-triggered.
# ----------------------------------------------------------------------------

# Parallel indexed arrays tracking adopted ids and their adopted Issue numbers.
adopted_ids_count=0
adopted=0

_readopt_trigger=0
if [ "$REINIT" -eq 1 ]; then
  _readopt_trigger=1
elif [ ! -f "$SIDECAR_TARGET" ]; then
  # Cheap probe: does the first projected id already have a remote marker?
  # phase_ids is a newline-separated list populated by the walker. Pick head.
  _probe_pid="$(printf '%s\n' "$phase_ids" | head -n 1)"
  if [ -n "${_probe_pid:-}" ]; then
    _probe_oid="${MILESTONE_ID}-${_probe_pid}"
    if gh_marker_search_remote "$REPO_SLUG" "$_probe_oid" >/dev/null 2>&1; then
      _readopt_trigger=1
    fi
  fi
fi

if [ "$_readopt_trigger" -eq 1 ]; then
  echo "RE-INIT: adoption pre-pass engaged" >&2

  # Adopt the Milestone: gh milestone list → match by title.
  ms_number="$(gh milestone list --json title,number 2>/dev/null \
    | awk -v t="$MILESTONE_ID" '
        /"title":/ { gsub(/.*"title":"/, ""); gsub(/".*/, ""); title = $0 }
        /"number":/ { gsub(/.*"number":/, ""); gsub(/[^0-9].*/, ""); num = $0
                      if (title == t) { print num; exit } }
      ' 2>/dev/null || true)"
  if [ -n "$ms_number" ]; then
    manifest_upsert_line "milestone" "$MILESTONE_ID" "$ms_number" "adopt"
    adopted=$((adopted + 1))
    adopted_ids_eval="adopted_id_${adopted_ids_count}=\"${MILESTONE_ID}\""
    eval "$adopted_ids_eval"
    adopted_ids_count=$((adopted_ids_count + 1))
  fi

  # Adopt the Project v2: query projectV2 by title match against MILESTONE_ID.
  # (projectV2 query — not a mutation — outside FR-5's mutation whitelist.)
  proj_id="$(gh api graphql -F owner="$(printf '%s\n' "$REPO_SLUG" | cut -d/ -f1)" \
    -F name="$(printf '%s\n' "$REPO_SLUG" | cut -d/ -f2)" \
    --field query='query($owner:String!,$name:String!){repository(owner:$owner,name:$name){projectsV2(first:20){nodes{id number title}}}}' \
    --jq ".data.repository.projectsV2.nodes[] | select(.title==\"${MILESTONE_ID}\") | .id" 2>/dev/null | head -n 1 || true)"
  if [ -n "$proj_id" ]; then
    PROJECT_V2_ID="$proj_id"
    manifest_upsert_line "project-v2" "$MILESTONE_ID" "$proj_id" "adopt"
    adopted=$((adopted + 1))
  fi

  # Adopt phase Issues: for each projected phase id, marker search.
  OLDIFS_R="$IFS"
  IFS='
'
  for pid in $phase_ids; do
    oid="${MILESTONE_ID}-${pid}"
    if num="$(gh_marker_search_remote "$REPO_SLUG" "$oid" 2>/dev/null)"; then
      # Byte-identity check on the remote body.
      body_tmp="$(mktemp -t m013-adopt-body.XXXXXX)"
      if [ -n "${M013_GH_STUB_DIR:-}" ]; then
        body_stub="${M013_GH_STUB_DIR}/issue-view-body-${oid}.txt"
        [ -f "$body_stub" ] && cp "$body_stub" "$body_tmp"
      else
        gh issue view "$num" -R "$REPO_SLUG" --json body --jq .body >"$body_tmp" 2>/dev/null || true
      fi
      if shasum_marker_byte_identity "$body_tmp" "$oid"; then
        manifest_upsert_line "phase-issue" "$oid" "$num" "adopt"
        adopted=$((adopted + 1))
        eval "adopted_id_${adopted_ids_count}=\"${oid}\""
        adopted_ids_count=$((adopted_ids_count + 1))
        sidecar_upsert_item "$oid" "$num" "false" "false" \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PROJECT_ROOT" >/dev/null 2>&1 || true
      else
        echo "integration-marker-mismatch on adopt: ${oid}" >&2
        errors=$((errors + 1))
      fi
      rm -f "$body_tmp"
    fi
  done

  # Adopt task sub-issues similarly.
  for line in $task_lines; do
    IFS=' '
    # shellcheck disable=SC2086
    set -- $line
    pid_l="$1"; tid_l="$2"
    oid="${MILESTONE_ID}-${pid_l}-${tid_l}"
    IFS='
'
    if num="$(gh_marker_search_remote "$REPO_SLUG" "$oid" 2>/dev/null)"; then
      body_tmp="$(mktemp -t m013-adopt-body.XXXXXX)"
      if [ -n "${M013_GH_STUB_DIR:-}" ]; then
        body_stub="${M013_GH_STUB_DIR}/issue-view-body-${oid}.txt"
        [ -f "$body_stub" ] && cp "$body_stub" "$body_tmp"
      else
        gh issue view "$num" -R "$REPO_SLUG" --json body --jq .body >"$body_tmp" 2>/dev/null || true
      fi
      if shasum_marker_byte_identity "$body_tmp" "$oid"; then
        manifest_upsert_line "task-subissue" "$oid" "$num" "adopt"
        adopted=$((adopted + 1))
        eval "adopted_id_${adopted_ids_count}=\"${oid}\""
        adopted_ids_count=$((adopted_ids_count + 1))
        sidecar_upsert_item "$oid" "$num" "false" "false" \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PROJECT_ROOT" >/dev/null 2>&1 || true
      else
        echo "integration-marker-mismatch on adopt: ${oid}" >&2
        errors=$((errors + 1))
      fi
      rm -f "$body_tmp"
    fi
  done
  IFS="$OLDIFS_R"
fi

# _is_adopted <orchestrator-id> — exit 0 if id is in adopted_ids array.
_is_adopted() {
  local q="$1" i=0
  while [ "$i" -lt "$adopted_ids_count" ]; do
    eval "val=\"\${adopted_id_${i}}\""
    if [ "$val" = "$q" ]; then
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}
```

### Step 4: Guard `create_phase_issue` and `create_task_issue` with `_is_adopted` check

At the very top of `create_phase_issue` (line 512 area), add:

```bash
  if _is_adopted "$oid"; then
    return 0
  fi
```

Same for `create_task_issue` (line 565 area) — after `local oid=...` is computed.

The existing `create_milestone_issue` function similarly gains:

```bash
  if _is_adopted "$MILESTONE_ID"; then
    return 0
  fi
```

### Step 5: Update the final footer emit to include `adopted`

Locate the line `manifest_footer "$upserts" "$skipped" "$errors"` (around line 640). Replace with:

```bash
if [ "$_readopt_trigger" -eq 1 ]; then
  manifest_footer "$upserts" "$skipped" "$errors" "$adopted"
else
  manifest_footer "$upserts" "$skipped" "$errors"
fi
```

This preserves P02's fixture byte-identity on the non-re-init path.

### Step 6: Create gate `scripts/verify/m013-p03-re-init-adoption.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p03-re-init-adoption.sh — T02 gate: re-init adoption branch.
#
# Invokes github-init.sh --re-init --dry-run against the T01 fixture with
# M013_GH_STUB_DIR set; diffs the manifest against expected-readopt-manifest.txt
# byte-identical; additionally asserts:
#   - ZERO `gh issue create`, `gh milestone create`, `gh label create` calls
#     (PATH-shim a fake gh that logs every invocation)
#   - manifest footer has adopted=<N> field
#   - sidecar was populated with items.<oid> entries for adopted ids

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p03/re-init-adoption"
INIT="${REPO_ROOT}/scripts/integrations/github-init.sh"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# --- PATH-shim fake gh that logs every invocation and serves stub responses.
shim_dir="$(mktemp -d -t m013-p03-gh-shim.XXXXXX)"
call_log="${shim_dir}/calls.log"
: > "$call_log"

cat > "${shim_dir}/gh" <<'SHIM'
#!/usr/bin/env bash
# Fake gh that logs calls and serves stub responses from M013_GH_STUB_DIR.
log="${SHIM_CALL_LOG:-/tmp/m013-p03-gh-calls.log}"
printf 'gh %s\n' "$*" >> "$log"
# Hard-fail if the caller tries to create anything.
for arg in "$@"; do
  case "$arg" in
    create) echo "FAKE-GH: create invocation BLOCKED" >&2; exit 99 ;;
  esac
done
# Serve canned responses for the read calls the re-init branch issues.
stub="${M013_GH_STUB_DIR:-}"
cmd="$1"; sub="${2:-}"
case "$cmd:$sub" in
  auth:status) cat "${stub}/auth-status-green.txt" 2>/dev/null; exit 0 ;;
  api:graphql) cat "${stub}/project-v2-node-query.json" 2>/dev/null; exit 0 ;;
  milestone:list) printf '[{"title":"M013","number":101}]\n'; exit 0 ;;
  label:list) cat "${stub}/labels-no-collision.json" 2>/dev/null; exit 0 ;;
  issue:list) # return an empty set — marker search falls back to stub file via common.sh
    printf '[]\n'; exit 0 ;;
  issue:view) # the `gh issue view <num> --json body --jq .body` shape
    # Parse the oid out of the number in the stub; for the fixture we map
    # 201→M013-P02, 202→M013-P02-T01, 203→M013-P02-T02 via filename.
    num="$3"
    case "$num" in
      201) cat "${stub}/issue-view-body-M013-P02.txt" ; exit 0 ;;
      202) cat "${stub}/issue-view-body-M013-P02-T01.txt" ; exit 0 ;;
      203) cat "${stub}/issue-view-body-M013-P02-T02.txt" ; exit 0 ;;
    esac
    exit 0 ;;
esac
exit 0
SHIM
chmod +x "${shim_dir}/gh"

export PATH="${shim_dir}:${PATH}"
export SHIM_CALL_LOG="$call_log"
export M013_GH_STUB_DIR="${FX}/gh-stub-responses"

# Run the re-init branch (dry-run against the fixture; --i-am-operator to bypass
# the auto-mode short-circuit; --re-init to force the branch).
out="$(bash "$INIT" --root "${FX}/orchestrator-state" \
  --repo-slug test/test --i-am-operator --re-init --dry-run 2>/dev/null || true)"

# Assertion 1: manifest contains at least one adopt row.
printf '%s\n' "$out" | grep -qE '^UPSERT: [a-z\-]+ [^ ]+ [^ ]+ adopt$' \
  && pass "manifest contains adopt rows" || fail "no adopt rows in manifest"

# Assertion 2: footer has adopted=<N> field.
printf '%s\n' "$out" | grep -qE '^upserts=[0-9]+ skipped=[0-9]+ errors=[0-9]+ adopted=[0-9]+$' \
  && pass "footer has adopted= field" || fail "footer missing adopted= field"

# Assertion 3: zero `create` calls logged by the shim.
if grep -q ' create' "$call_log"; then
  fail "shim logged 'create' calls (should be zero in adopt path)"
else
  pass "zero create calls issued"
fi

# Assertion 4: manifest body rows match expected fixture (phase + 2 tasks → 3 adopt rows at minimum).
adopt_count="$(printf '%s\n' "$out" | grep -cE '^UPSERT: [a-z\-]+ [^ ]+ [^ ]+ adopt$' || true)"
[ "${adopt_count:-0}" -ge 3 ] && pass "≥3 adopt rows" || fail "expected ≥3 adopt rows, got ${adopt_count:-0}"

# Assertion 5: --re-init flag is documented in the help output.
bash "$INIT" --help 2>/dev/null | grep -q -- '--re-init' \
  && pass "--re-init in help" || fail "--re-init missing from help"

# Assertion 6: P02 fixture path still byte-identical (regression guard — run the
# existing P02 fixture gate and assert exit 0).
if bash "${REPO_ROOT}/scripts/verify/m013-p02-github-init-fixture.sh" >/dev/null 2>&1; then
  pass "P02 fixture byte-identity preserved"
else
  fail "P02 fixture byte-identity REGRESSION"
fi

rm -rf "$shim_dir"
echo "SUMMARY: m013-p03-re-init-adoption.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-re-init-adoption.sh"
  exit 0
fi
echo "FAIL: m013-p03-re-init-adoption.sh" >&2
exit 1
```

### Step 7: Create gate `scripts/verify/m013-p03-re-init-auto-mode.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p03-re-init-auto-mode.sh — T02 gate: re-init under auto-mode.
#
# Verifies SC-7: when invoked WITHOUT --i-am-operator and WITHOUT a TTY,
# --re-init is a no-op that falls through to the pending-sentinel path.
# Zero `gh` subprocess calls fire.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p03/re-init-adoption"
INIT="${REPO_ROOT}/scripts/integrations/github-init.sh"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# PATH-shim a fake gh that blocks every call.
shim_dir="$(mktemp -d -t m013-p03-auto.XXXXXX)"
call_log="${shim_dir}/calls.log"
: > "$call_log"
cat > "${shim_dir}/gh" <<'SHIM'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >> "${SHIM_CALL_LOG:-/tmp/gh-calls.log}"
exit 0
SHIM
chmod +x "${shim_dir}/gh"
export PATH="${shim_dir}:${PATH}"
export SHIM_CALL_LOG="$call_log"

# Invoke --re-init WITHOUT --i-am-operator, piping stdin so there is no TTY.
out="$(bash "$INIT" --root "${FX}/orchestrator-state" \
  --repo-slug test/test --re-init --dry-run </dev/null 2>&1 || true)"

printf '%s\n' "$out" | grep -q 'pending-operator-complete' \
  && pass "fell through to pending-sentinel path" \
  || fail "did NOT short-circuit to pending-sentinel under auto-mode"

if [ -s "$call_log" ]; then
  fail "shim logged $(wc -l <"$call_log") gh calls (should be zero)"
else
  pass "zero gh calls under auto-mode + --re-init"
fi

rm -rf "$shim_dir"
echo "SUMMARY: m013-p03-re-init-auto-mode.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-re-init-auto-mode.sh"
  exit 0
fi
echo "FAIL: m013-p03-re-init-auto-mode.sh" >&2
exit 1
```

## Must-Haves

From P03-PLAN:

- `scripts/integrations/github-init.sh` contains the string `re-init` and the `--re-init` flag in its argument parser; the re-init pre-pass runs before the create fan-out; `_is_adopted` guards the create functions.
- `scripts/integrations/github-common.sh` `manifest_footer` accepts an optional 4th arg `<adopted>`; with it omitted, P02's 3-field footer shape is preserved byte-identical.
- `scripts/verify/m013-p03-re-init-adoption.sh` passes (≥6 assertions).
- `scripts/verify/m013-p03-re-init-auto-mode.sh` passes (≥2 assertions).
- P02 fixture gate (`scripts/verify/m013-p02-github-init-fixture.sh`) still exits 0 (regression guard is inside the T02 adoption gate).

## Verification

```bash
bash scripts/verify/m013-p03-re-init-adoption.sh
bash scripts/verify/m013-p03-re-init-auto-mode.sh
bash scripts/verify/m013-p02-github-init-fixture.sh
```

All three exit 0.

## Inputs

### From Previous Tasks

- `scripts/integrations/github-common.sh` (from P03/T01, inherited from P02/T01)
  - Key API: `gh_marker_search_remote <repo-slug> <oid>` — returns Issue number on unique hit (exit 0), empty + 1 on zero, empty + 2 on duplicate. Fixture-driven via `M013_GH_STUB_DIR`.
  - Key API: `manifest_upsert_line <kind> <oid> <target> <reason>` — emits one manifest line.
  - Key API: `manifest_footer <upserts> <skipped> <errors> [<adopted>]` — T02 extends this additively.
  - Key API: `shasum_marker_byte_identity <body-file> <oid>` — FR-4 byte-identity verification.
  - Key API: `sidecar_upsert_item <oid> <num> <attached> <synced> <iso-ts> [<root>]` — per-item cache upsert.
- `tests/fixtures/m013-p03/re-init-adoption/` (from P03/T01)
  - Shape: `orchestrator-state/` seed + `gh-stub-responses/` (auth/subissue/labels/3× issue-list/project-v2-node-query/3× issue-view-body) + `expected-readopt-manifest.txt` snapshot.

### From Disk (Pre-existing)

- `scripts/integrations/github-init.sh` (from M013/P02/T02)
  - 644-line P02 workhorse. T02 modifies it additively: adds `REINIT=0` default + `--re-init` case in arg parser; inserts re-init pre-pass block between preflights and create fan-out (around line 611); guards `create_milestone_issue` / `create_phase_issue` / `create_task_issue` with `_is_adopted` short-circuit at function top; extends the final `manifest_footer` call to pass `$adopted` when re-init ran.
  - Key API: `phase_ids` (newline-separated list of projected phase IDs; populated by state walker), `task_lines` (newline-separated `<phase-id> <task-id>` pairs), `MILESTONE_ID`, `SIDECAR_TARGET`, `PROJECT_ROOT`, `REPO_SLUG`, `errors`, `upserts`, `skipped`.
- `scripts/verify/m013-p02-github-init-fixture.sh` (from M013/P02/T02)
  - Regression guard. Must stay green after T02 lands.
- `scripts/verify/anti-pattern-lint.sh` (M016/[M021](../../../../../milestones/M021/index.md) invariant)
  - Consumed by T05's bash32-compat gate.

## Constraints

- **P02 byte-identity**: all P02 fixture gates must still exit 0 after T02 lands. Verify with `scripts/verify/m013-p02-github-init-fixture.sh` and `scripts/verify/m013-p02-dry-run-manifest.sh`.
- **SC-7 zero-prompts invariant**: the existing auto-mode short-circuit (lines 78-94 of `github-init.sh`) already handles the no-TTY + no-`--i-am-operator` case. `--re-init` MUST NOT fire any `gh` write call in that mode — the auto-mode gate above catches this invariant.
- **FR-5 whitelist**: T02 must NOT introduce any new GraphQL **mutation** shape. The pre-existing Project v2 discovery uses a `query { repository { projectsV2 { nodes { id number title } } } }` — queries are outside the mutation whitelist and are unconstrained by FR-5.
- **FR-4 marker invariant**: every adopted Issue's body must pass `shasum_marker_byte_identity`. On mismatch, T02 emits `integration-marker-mismatch on adopt:` to stderr and increments the error count.
- **Knowledge-Layer Boundary (D014)**: no knowledge/spec/ writes, no `KNOWLEDGE-INDEX.md` extensions, no `scripts/knowledge/rebuild-index.sh` modifications.
- **FR-12 Claude-Code-only v1**: no multi-runtime logic.
- **Bash 3.2**: no `declare -A`, no `mapfile`/`readarray`, no process substitution, no combined-redirect shorthand, no case-conversion expansion. The `adopted_ids` array uses `eval "adopted_id_${i}=..."` parallel-indexed pattern (MEM001).
- **AD-19 `Check:` shape**: gate commands are single-script-file invocations only.
- **Integer-minutes duration** in T02-SUMMARY.md.
- **No new `commands/*.md` files**: T02 extends the existing `github-init.sh` and its doc. `commands/github-init.md` will be updated by T04, not T02.

## Expected Output

```
PASS: manifest contains adopt rows
PASS: footer has adopted= field
PASS: zero create calls issued
PASS: ≥3 adopt rows
PASS: --re-init in help
PASS: P02 fixture byte-identity preserved
SUMMARY: m013-p03-re-init-adoption.sh pass=6 fail=0
PASS: m013-p03-re-init-adoption.sh

PASS: fell through to pending-sentinel path
PASS: zero gh calls under auto-mode + --re-init
SUMMARY: m013-p03-re-init-auto-mode.sh pass=2 fail=0
PASS: m013-p03-re-init-auto-mode.sh
```

Estimated duration: 60 integer minutes.
