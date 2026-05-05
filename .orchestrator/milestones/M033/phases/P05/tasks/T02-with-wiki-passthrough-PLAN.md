---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M033"
name: "FR-15 --with-wiki paired-launch passthrough additive extension to scripts/lifecycle/start.sh (CON-1 / MIT-001 two-mode test contract)"
depends_on: []
---

## Prerequisites

T02 ships the FR-15 surface: the `--with-wiki [--with-giscus] [--deploy]` flag handlers + the post-onboarding wiki-init invocation gate + stub-mode dispatch + `wiki_init_invoked` JSONL emit, all as an **additive extension** to `scripts/lifecycle/start.sh`. T02 has no intra-phase prerequisites.

Files that MUST exist on disk at task-start (verified via `ls -la`):

- `scripts/lifecycle/start.sh` (P01/T01, P02/T02 resume extension, P04/T04 migrate-routing extension) — the file T02 modifies additively
- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — `bash <path> emit wiki_init_invoked <payload>`; `wiki_init_invoked` is in the closed enum per the spec FR-22 (verify at task-start by `grep -F 'wiki_init_invoked' scripts/util/jsonl-event-emitter.sh`)
- `scripts/util/start-state-markers.sh` (P02/T02) — used to verify US-1..US-7 sub-flow markers are preserved on wiki-init failure
- `tests/m033-acceptance/p01-start-branch-routing.sh` (P01/T05) — SC-1 acceptance script; T02 MUST NOT regress it

P02-shipped API summary (zero-context surface T02 calls):
- `bash scripts/util/jsonl-event-emitter.sh emit wiki_init_invoked '{"project_dir":"<path>","exit_code":<N>,"stub_mode":true|false,"with_giscus":true|false,"deploy":true|false}'`
- The closed enum contains 12 event types (P03/T04 added `imported_context_loaded`); `wiki_init_invoked` is one of them.

`scripts/lifecycle/start.sh` shape summary at task-start (zero-context):
- Argument parser: while-case loop handling `--project-dir`, `--yes`, `--branch`, `--stack`, `--dry-run`, `--no-resume` (P01/T01 + P02/T02). T02 adds `--with-wiki`, `--with-giscus`, `--deploy` cases.
- `main()` function: branch detection → init invocation → branch sub-flow dispatch → resume-detection block → exit. T02 inserts the wiki-init gate BETWEEN sub-flow dispatch completion AND exit (post-onboarding).
- P04/T04 added `migrate_routing` function and `--dry-run` gate; T02 must coexist with both (no overlap).

## Description

T02 ships TWO deliverables:

1. **Additive extension to `scripts/lifecycle/start.sh`** — adds `--with-wiki`, `--with-giscus`, `--deploy` flag handlers + a `wiki_init_passthrough` function + a post-onboarding invocation gate that fires `wiki_init_passthrough` after all sub-flows have completed. Extends the argument parser, adds the function, threads the call into `main()` post-sub-flow-dispatch.

2. **`tools/verify/m033-p05-with-wiki-passthrough-shape.sh`** — shape verifier asserting the additive extension is present with the load-bearing tokens.

## Steps

### 1. Additively extend `scripts/lifecycle/start.sh` for FR-15

**Argument parser extension** — add three cases to the while-case loop:

```bash
        --with-wiki) WITH_WIKI=1; shift ;;
        --with-giscus) WITH_GISCUS=1; shift ;;
        --deploy) DEPLOY=1; shift ;;
```

Initialize variables at top-of-script:
```bash
WITH_WIKI=0
WITH_GISCUS=0
DEPLOY=0
```

**`wiki_init_passthrough` function** — add as a new function near the existing `migrate_routing` function:

```bash
wiki_init_passthrough() {
    # FR-15 / spec 035 FR-11 paired-launch contract.
    # CON-1 / MIT-001 two-mode test contract: stub mode under M033_FR15_STUB=1
    # produces pass-not-skip; real mode invokes scripts/lifecycle/wiki-init.sh
    # (M032/P02 surface) when present.
    local project_dir="$1"
    local with_giscus_flag=""
    local deploy_flag=""
    [ "$WITH_GISCUS" -eq 1 ] && with_giscus_flag="--with-giscus"
    [ "$DEPLOY" -eq 1 ] && deploy_flag="--deploy"

    local rc=0
    local stub_mode="false"
    if [ "${M033_FR15_STUB:-0}" -eq 1 ]; then
        stub_mode="true"
        printf 'STUB: wiki-init invoked --project-dir=%s %s %s\n' \
            "$project_dir" "$with_giscus_flag" "$deploy_flag"
        rc="${M033_FR15_STUB_EXIT_CODE:-0}"
    elif [ -f "scripts/lifecycle/wiki-init.sh" ]; then
        # Real-mode: M032/P02 has shipped wiki-init.sh.
        bash scripts/lifecycle/wiki-init.sh \
            --project-dir "$project_dir" $with_giscus_flag $deploy_flag
        rc=$?
    else
        # M032/P02 not closed AND no stub mode -- genuine failure (not skip).
        printf 'wiki-init.sh not found -- M032/P02 must close before --with-wiki real-mode can fire\n' >&2
        rc=1
    fi

    # Emit FR-22 JSONL event with downstream exit code.
    local with_giscus_bool="false"
    local deploy_bool="false"
    [ "$WITH_GISCUS" -eq 1 ] && with_giscus_bool="true"
    [ "$DEPLOY" -eq 1 ] && deploy_bool="true"
    local payload
    payload=$(printf '{"project_dir":"%s","exit_code":%d,"stub_mode":%s,"with_giscus":%s,"deploy":%s}' \
        "$project_dir" "$rc" "$stub_mode" "$with_giscus_bool" "$deploy_bool")
    bash scripts/util/jsonl-event-emitter.sh emit wiki_init_invoked "$payload" || true

    # Sequential-atomicity model: on non-zero, surface as wiki-init failure
    # (NOT a start failure); preserve all US-1..US-7 sub-flow markers; propagate
    # the underlying exit code verbatim (FR-15 / spec 035 CON-3).
    if [ "$rc" -ne 0 ]; then
        printf 'wiki-init failed; re-run "orchestrator:wiki-init" independently to complete; all other onboarding outputs preserved\n'
        return "$rc"
    fi
    return 0
}
```

**Thread the call into `main()` post-sub-flow-dispatch** — after the existing branch sub-flow dispatch block (after `migrate_routing` for the migrating branch / sub-flow stubs for other branches) AND after their `<sub-flow>.complete` markers are written, insert:

```bash
# FR-15 wiki-init paired-launch passthrough (post-onboarding gate).
if [ "$WITH_WIKI" -eq 1 ]; then
    wiki_init_passthrough "$PROJECT_DIR"
    WIKI_RC=$?
    if [ "$WIKI_RC" -ne 0 ]; then
        # Propagate the underlying exit code verbatim per FR-15.
        # T03 will handle the --with-github passthrough below this gate.
        # When T03 ships, the github gate must NOT fire if wiki failed;
        # T03's gate will check WIKI_RC.
        exit "$WIKI_RC"
    fi
fi
```

### 2. Author `tools/verify/m033-p05-with-wiki-passthrough-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-with-wiki-passthrough-shape.sh
# Asserts scripts/lifecycle/start.sh FR-15 additive extension shape.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

START="scripts/lifecycle/start.sh"
[ -f "$START" ] && pass "start.sh exists" || fail "start.sh missing"

for tok in '--with-wiki' '--with-giscus' '--deploy' \
           'WITH_WIKI' 'WITH_GISCUS' 'DEPLOY' \
           'M033_FR15_STUB' 'M033_FR15_STUB_EXIT_CODE' \
           'wiki_init_invoked' 'wiki-init failed' 'wiki-init.sh' \
           'STUB: wiki-init invoked' 'all other onboarding outputs preserved' \
           'wiki-init.sh not found' 'wiki_init_passthrough'; do
    grep -qF -- "$tok" "$START" && pass "token present: $tok" || fail "token absent: $tok"
done

# Functional smoke: stub-mode invocation under mktemp staging.
STAGE=$(mktemp -d)
mkdir -p "$STAGE/.orchestrator/start-state"
touch "$STAGE/.orchestrator/start-state/init-invoked.complete"
M033_FR15_STUB=1 M033_FR15_STUB_EXIT_CODE=0 \
    bash "$START" --project-dir "$STAGE" --branch greenfield-empty --with-wiki --yes --dry-run \
    > "$STAGE/stdout" 2> "$STAGE/stderr"
RC=$?
if grep -qF 'STUB: wiki-init invoked' "$STAGE/stdout"; then
    pass "stub-mode emits STUB token"
else
    fail "stub-mode did not emit STUB token"
fi
[ "$RC" -eq 0 ] && pass "stub-mode rc=0 propagation" || fail "stub-mode rc=$RC expected 0"

# Functional smoke: stub-mode non-zero exit propagation.
STAGE2=$(mktemp -d)
mkdir -p "$STAGE2/.orchestrator/start-state"
touch "$STAGE2/.orchestrator/start-state/init-invoked.complete"
M033_FR15_STUB=1 M033_FR15_STUB_EXIT_CODE=42 \
    bash "$START" --project-dir "$STAGE2" --branch greenfield-empty --with-wiki --yes --dry-run \
    > "$STAGE2/stdout" 2> "$STAGE2/stderr"
RC2=$?
[ "$RC2" -eq 42 ] && pass "stub-mode exit-code propagation rc=42" || fail "stub-mode rc=$RC2 expected 42"
if grep -qF 'wiki-init failed' "$STAGE2/stdout"; then
    pass "stub-mode emits failure diagnostic"
else
    fail "stub-mode did not emit failure diagnostic"
fi

# Cross-phase regression: P01 SC-1 acceptance must still pass.
if [ -f "tests/m033-acceptance/p01-start-branch-routing.sh" ]; then
    bash tests/m033-acceptance/p01-start-branch-routing.sh > /dev/null 2>&1
    SC1_RC=$?
    [ "$SC1_RC" -eq 0 ] && pass "SC-1 cross-phase regression preserved" \
        || fail "SC-1 regressed (rc=$SC1_RC)"
fi

rm -rf "$STAGE" "$STAGE2"

printf 'SUMMARY: m033-p05-with-wiki-passthrough-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

## Must-Haves

This task addresses these P05 must-haves:

- `scripts/lifecycle/start.sh` is extended additively for FR-15 `--with-wiki` real-mode passthrough (Truth #4)
- Driver-extension artifact: `scripts/lifecycle/start.sh` (modify)
- Verifier artifact: `tools/verify/m033-p05-with-wiki-passthrough-shape.sh`

## Verification

```bash
bash tools/verify/m033-p05-with-wiki-passthrough-shape.sh
```

## Inputs

### From Previous Tasks

None (T02 has no intra-phase prerequisites).

### From Disk (Pre-existing)

- `scripts/lifecycle/start.sh` (P01/T01 + P02/T02 + P04/T04) — argument parser, branch-detection, init invocation, sub-flow dispatch, resume-detection block, `migrate_routing` function. T02 extends additively WITHOUT touching the existing P01/P02/P04 code paths.
- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — `wiki_init_invoked` is in the 12-event closed enum
- `scripts/util/start-state-markers.sh` (P02/T02) — used to verify US-1..US-7 sub-flow markers are preserved
- `tests/m033-acceptance/p01-start-branch-routing.sh` (P01/T05) — SC-1 acceptance; cross-phase regression check inside this task's verifier

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no command-substitution-with-pipes
- AD-19 single-script-file shape — Verification commands MUST be `bash <path>` invocations only
- AD-15 cross-phase regression — T02's modification MUST be additive; P01/P02/P04 phase-suites MUST still exit 0 against the post-T02 tree (verified by T05's cross-phase regression verifier)
- CON-1 paired-launch contract — exit code propagation MUST match spec 035 FR-11; sequential-atomicity model preserves US-1..US-7 sub-flow markers on wiki-init failure
- MIT-001 two-mode contract — stub mode MUST produce pass not skip (no `EXIT 77`, no `SKIP:` token)
- T02 MUST NOT introduce any speckit.* references (CON-3 / Principle XVI)
- T02 MUST NOT modify P02's grilling-shell, P03's constitution-author, P03's ingest-codebase, P04's materials-intake, P04's ideation, or P04's migrate-routing — only `start.sh` is modified, and only additively

## Expected Output

T02 modifies 1 existing file and creates 1 new file:
- `scripts/lifecycle/start.sh` (modify, +80 net lines added — 3 flag-parser cases + 1 function ~50 lines + 1 main()-block invocation gate ~10 lines + variable initialization + comment block)
- `tools/verify/m033-p05-with-wiki-passthrough-shape.sh` (create, ≥30 lines, executable)

After T02 lands, `bash tools/verify/m033-p05-with-wiki-passthrough-shape.sh` emits `SUMMARY: m033-p05-with-wiki-passthrough-shape.sh pass=N fail=0` and the SC-1 cross-phase regression check inside the verifier passes.

## Notes

### Sequential-atomicity model (FR-15 / spec 035 CON-3)

On wiki-init non-zero exit, the wiki gate:
1. Surfaces the failure as a wiki-init failure (NOT a start failure) — the diagnostic explicitly names wiki-init.
2. Preserves US-1..US-7 sub-flow markers under `<project-dir>/.orchestrator/start-state/` — does NOT call any cleanup or rollback path.
3. Propagates the underlying exit code verbatim — `start.sh` exits with the same code as `wiki-init.sh` (or the synthetic stub code under `M033_FR15_STUB_EXIT_CODE`).
4. Emits the canonical diagnostic `wiki-init failed; re-run "orchestrator:wiki-init" independently to complete; all other onboarding outputs preserved` to stdout.

### Stub-mode discipline (MIT-001 two-mode test contract)

The `M033_FR15_STUB=1` env var triggers stub mode. In stub mode:
- The driver does NOT invoke `wiki-init.sh` (even if it exists on disk).
- The driver emits `STUB: wiki-init invoked --project-dir=<path> [--with-giscus] [--deploy]` to stdout.
- The driver returns `M033_FR15_STUB_EXIT_CODE` (default 0; tests set non-zero to exercise failure-propagation).
- The JSONL record's `stub_mode` field is `true`.

In real mode (no `M033_FR15_STUB`), the driver checks for `scripts/lifecycle/wiki-init.sh`:
- If present, invokes it (M032/P02 has closed).
- If absent, emits the `wiki-init.sh not found` diagnostic and returns rc=1 (genuine failure, NOT skip — SC-14 `skip=0` invariant).

### Coexistence with T03 (`--with-github`)

T03 will add the `--with-github` flag and the `github_init_passthrough` function in a similar shape. Per the FR-16 contract, github-init MUST NOT fire before wiki-init when both flags are present. T02's gate exits on wiki-init failure (lines `exit "$WIKI_RC"`); T03's gate is inserted AFTER T02's gate in `main()`, so the natural code ordering enforces the rule (github-init runs only if wiki-init succeeded or wasn't requested).

### Path-collision check (Plan-Time Discipline rule 6)

- `tools/verify/m033-p05-with-wiki-passthrough-shape.sh` — verified absent at planning time
- `scripts/lifecycle/start.sh` — present (P01/T01 + P02/T02 + P04/T04 deliverable); declared as `modify`, NOT `create`

### Verifier-availability cross-check (Plan-Time Discipline rule 2)

`bash tools/verify/m033-p05-with-wiki-passthrough-shape.sh` is co-authored in step 2 of this task — no cross-task dependency.

### `wiki_init_invoked` already in the closed JSONL enum

P02/T01 shipped the FR-22 emitter with `wiki_init_invoked` as one of the 11 documented event types; P03/T04 additively extended to 12 (added `imported_context_loaded`). T02 calls `emit wiki_init_invoked` directly — no enum extension required. Verify at task-start by `grep -F 'wiki_init_invoked' scripts/util/jsonl-event-emitter.sh`; if absent, T02 includes a 1-line additive enum extension matching the P03/T04 precedent.

### Argument-parser extension is non-overlapping

Existing flags handled by `start.sh`: `--project-dir`, `--yes`, `--branch`, `--stack`, `--dry-run`, `--no-resume` (P01/T01 + P02/T02). New flags T02 adds: `--with-wiki`, `--with-giscus`, `--deploy`. Zero overlap. T03 will add `--with-github` (also non-overlapping).
