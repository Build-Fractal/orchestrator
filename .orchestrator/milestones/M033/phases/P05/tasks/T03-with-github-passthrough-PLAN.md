---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M033"
name: "FR-16 --with-github passthrough additive extension to scripts/lifecycle/start.sh"
depends_on: ["T02"]
---

## Prerequisites

T03 ships the FR-16 surface: the `--with-github` flag handler + the post-onboarding-and-post-wiki-init github-init invocation gate + stub-mode dispatch + `github_init_invoked` JSONL emit, all as an **additive extension** to `scripts/lifecycle/start.sh`. T03 depends on T02 because both edit `scripts/lifecycle/start.sh` and T02 establishes the stub-mode + post-onboarding-gate scaffolding T03 inherits (a single-file serial-edit dependency, not a behavioral dependency).

Files that MUST exist on disk at task-start (verified via `ls -la`):

- `scripts/lifecycle/start.sh` (T02-extended) — contains `WITH_WIKI`, `wiki_init_passthrough`, `--with-wiki` parser case, post-onboarding wiki-init gate, `wiki_init_invoked` emit
- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — `bash <path> emit github_init_invoked <payload>`; `github_init_invoked` is in the closed enum per the spec FR-22 (verify at task-start by `grep -F 'github_init_invoked' scripts/util/jsonl-event-emitter.sh`)
- `tools/verify/m033-p05-with-wiki-passthrough-shape.sh` (T02) — re-run as a regression gate inside T03's verifier
- `tests/m033-acceptance/p01-start-branch-routing.sh` (P01/T05) — SC-1 acceptance script; T03 MUST NOT regress it

P02-shipped API summary (zero-context surface T03 calls):
- `bash scripts/util/jsonl-event-emitter.sh emit github_init_invoked '{"project_dir":"<path>","exit_code":<N>,"stub_mode":true|false}'`
- The closed enum contains 12 event types; `github_init_invoked` is one of them.

T02-shipped surface (zero-context for T03):
- `WITH_WIKI` global variable initialized at top-of-script
- `wiki_init_passthrough()` function near `migrate_routing()`
- Post-onboarding gate in `main()` invoking `wiki_init_passthrough` when `WITH_WIKI=1`, with `exit "$WIKI_RC"` on non-zero
- `--with-wiki`, `--with-giscus`, `--deploy` flag parsing

T03 inserts the github gate **AFTER** T02's wiki gate in `main()`, so github-init naturally fires only when wiki-init succeeded or wasn't requested.

## Description

T03 ships TWO deliverables:

1. **Additive extension to `scripts/lifecycle/start.sh`** — adds `--with-github` flag handler + a `github_init_passthrough` function + a post-wiki-init invocation gate that fires `github_init_passthrough` after the wiki gate has completed (or was never invoked). Extends the argument parser, adds the function, threads the call into `main()` post-wiki-gate.

2. **`tools/verify/m033-p05-with-github-passthrough-shape.sh`** — shape verifier asserting the additive extension is present with the load-bearing tokens.

## Steps

### 1. Additively extend `scripts/lifecycle/start.sh` for FR-16

**Argument parser extension** — add one case to the while-case loop (alongside T02's three cases):

```bash
        --with-github) WITH_GITHUB=1; shift ;;
```

Initialize variable at top-of-script (alongside T02's `WITH_WIKI`, `WITH_GISCUS`, `DEPLOY`):
```bash
WITH_GITHUB=0
```

**`github_init_passthrough` function** — add as a new function near `wiki_init_passthrough`:

```bash
github_init_passthrough() {
    # FR-16 paired-launch contract -- mirrors FR-15's failure-propagation
    # discipline. Must fire AFTER wiki-init (when --with-wiki --with-github
    # are combined) per the post-wiki-init ordering rule.
    local project_dir="$1"

    local rc=0
    local stub_mode="false"
    if [ "${M033_GHINIT_STUB:-0}" -eq 1 ]; then
        stub_mode="true"
        printf 'STUB: github-init invoked --project-dir=%s\n' "$project_dir"
        rc="${M033_GHINIT_STUB_EXIT_CODE:-0}"
    elif [ -f "scripts/lifecycle/github-init.sh" ]; then
        # Real-mode: M013 has shipped github-init.sh.
        bash scripts/lifecycle/github-init.sh --project-dir "$project_dir"
        rc=$?
    else
        # M013 absent AND no stub mode -- genuine failure (not skip).
        printf 'github-init.sh not found -- M013 must be installed before --with-github real-mode can fire\n' >&2
        rc=1
    fi

    # Emit FR-22 JSONL event with downstream exit code.
    local payload
    payload=$(printf '{"project_dir":"%s","exit_code":%d,"stub_mode":%s}' \
        "$project_dir" "$rc" "$stub_mode")
    bash scripts/util/jsonl-event-emitter.sh emit github_init_invoked "$payload" || true

    if [ "$rc" -ne 0 ]; then
        printf 'github-init failed; re-run "orchestrator:github-init" independently to complete; all other onboarding outputs preserved\n'
        return "$rc"
    fi
    return 0
}
```

**Thread the call into `main()` post-wiki-gate** — insert IMMEDIATELY AFTER T02's wiki gate (so github runs only when wiki succeeded or wasn't requested):

```bash
# FR-16 github-init paired-launch passthrough (post-wiki-init gate).
if [ "$WITH_GITHUB" -eq 1 ]; then
    github_init_passthrough "$PROJECT_DIR"
    GH_RC=$?
    if [ "$GH_RC" -ne 0 ]; then
        exit "$GH_RC"
    fi
fi
```

The natural code ordering enforces the FR-16 ordering rule: T02's gate exits on wiki failure (`exit "$WIKI_RC"`), so T03's gate is unreachable when wiki failed. When both flags are passed and wiki succeeds, T03's gate fires next (after T02's gate `return 0`'s and falls through). The acceptance test (T04 / SC-10) verifies the token ordering: `STUB: wiki-init invoked` appears on stdout before `STUB: github-init invoked`.

### 2. Author `tools/verify/m033-p05-with-github-passthrough-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m033-p05-with-github-passthrough-shape.sh
# Asserts scripts/lifecycle/start.sh FR-16 additive extension shape.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

START="scripts/lifecycle/start.sh"
[ -f "$START" ] && pass "start.sh exists" || fail "start.sh missing"

for tok in '--with-github' 'WITH_GITHUB' \
           'M033_GHINIT_STUB' 'M033_GHINIT_STUB_EXIT_CODE' \
           'github_init_invoked' 'github-init failed' 'github-init.sh' \
           'STUB: github-init invoked' 'all other onboarding outputs preserved' \
           'github-init.sh not found' 'github_init_passthrough'; do
    grep -qF -- "$tok" "$START" && pass "token present: $tok" || fail "token absent: $tok"
done

# Functional smoke: stub-mode invocation under mktemp staging.
STAGE=$(mktemp -d)
mkdir -p "$STAGE/.orchestrator/start-state"
touch "$STAGE/.orchestrator/start-state/init-invoked.complete"
M033_GHINIT_STUB=1 M033_GHINIT_STUB_EXIT_CODE=0 \
    bash "$START" --project-dir "$STAGE" --branch greenfield-empty --with-github --yes --dry-run \
    > "$STAGE/stdout" 2> "$STAGE/stderr"
RC=$?
if grep -qF 'STUB: github-init invoked' "$STAGE/stdout"; then
    pass "stub-mode emits STUB token"
else
    fail "stub-mode did not emit STUB token"
fi
[ "$RC" -eq 0 ] && pass "stub-mode rc=0 propagation" || fail "stub-mode rc=$RC expected 0"

# Functional smoke: stub-mode non-zero exit propagation.
STAGE2=$(mktemp -d)
mkdir -p "$STAGE2/.orchestrator/start-state"
touch "$STAGE2/.orchestrator/start-state/init-invoked.complete"
M033_GHINIT_STUB=1 M033_GHINIT_STUB_EXIT_CODE=17 \
    bash "$START" --project-dir "$STAGE2" --branch greenfield-empty --with-github --yes --dry-run \
    > "$STAGE2/stdout" 2> "$STAGE2/stderr"
RC2=$?
[ "$RC2" -eq 17 ] && pass "stub-mode exit-code propagation rc=17" || fail "stub-mode rc=$RC2 expected 17"
if grep -qF 'github-init failed' "$STAGE2/stdout"; then
    pass "stub-mode emits failure diagnostic"
else
    fail "stub-mode did not emit failure diagnostic"
fi

# Functional smoke: --with-wiki + --with-github ordering rule (wiki before github).
STAGE3=$(mktemp -d)
mkdir -p "$STAGE3/.orchestrator/start-state"
touch "$STAGE3/.orchestrator/start-state/init-invoked.complete"
M033_FR15_STUB=1 M033_GHINIT_STUB=1 \
    bash "$START" --project-dir "$STAGE3" --branch greenfield-empty --with-wiki --with-github --yes --dry-run \
    > "$STAGE3/stdout" 2> "$STAGE3/stderr"
WIKI_LINE=$(grep -nF 'STUB: wiki-init invoked' "$STAGE3/stdout" | head -1 | cut -d: -f1)
GH_LINE=$(grep -nF 'STUB: github-init invoked' "$STAGE3/stdout" | head -1 | cut -d: -f1)
if [ -n "$WIKI_LINE" ] && [ -n "$GH_LINE" ] && [ "$WIKI_LINE" -lt "$GH_LINE" ]; then
    pass "ordering rule: wiki-init before github-init"
else
    fail "ordering rule violated: wiki=$WIKI_LINE github=$GH_LINE"
fi

# Cross-phase regression: T02's verifier still passes.
if [ -f "tools/verify/m033-p05-with-wiki-passthrough-shape.sh" ]; then
    bash tools/verify/m033-p05-with-wiki-passthrough-shape.sh > /dev/null 2>&1
    T02_RC=$?
    [ "$T02_RC" -eq 0 ] && pass "T02 verifier preserved" || fail "T02 regressed (rc=$T02_RC)"
fi

# Cross-phase regression: P01 SC-1 acceptance still passes.
if [ -f "tests/m033-acceptance/p01-start-branch-routing.sh" ]; then
    bash tests/m033-acceptance/p01-start-branch-routing.sh > /dev/null 2>&1
    SC1_RC=$?
    [ "$SC1_RC" -eq 0 ] && pass "SC-1 cross-phase regression preserved" \
        || fail "SC-1 regressed (rc=$SC1_RC)"
fi

rm -rf "$STAGE" "$STAGE2" "$STAGE3"

printf 'SUMMARY: m033-p05-with-github-passthrough-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

## Must-Haves

This task addresses these P05 must-haves:

- `scripts/lifecycle/start.sh` is extended additively for FR-16 `--with-github` passthrough (Truth #5)
- Driver-extension artifact: `scripts/lifecycle/start.sh` (modify, T03 portion)
- Verifier artifact: `tools/verify/m033-p05-with-github-passthrough-shape.sh`

## Verification

```bash
bash tools/verify/m033-p05-with-github-passthrough-shape.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/start.sh` (T02-extended)
  - Key API: `wiki_init_passthrough <project-dir>`; `WITH_WIKI` global; post-onboarding wiki gate in `main()`
  - Key types: bash globals; bash function with rc semantics

- `tools/verify/m033-p05-with-wiki-passthrough-shape.sh` (T02)
  - Key API: shape verifier emitting `SUMMARY: m033-p05-with-wiki-passthrough-shape.sh pass=N fail=M`
  - Re-run by T03's verifier as a regression gate

### From Disk (Pre-existing)

- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — `github_init_invoked` is in the 12-event closed enum
- `tests/m033-acceptance/p01-start-branch-routing.sh` (P01/T05) — SC-1 acceptance; cross-phase regression check

## Constraints

- Bash 3.2 compatibility (MEM001)
- AD-19 single-script-file shape — Verification commands MUST be `bash <path>` invocations only
- AD-15 cross-phase regression — T03's modification MUST be additive; T02's verifier + P01/P02/P04 phase-suites MUST still exit 0 against the post-T03 tree
- FR-16 ordering rule — github-init MUST fire AFTER wiki-init when both flags are present (enforced by code ordering: T03's gate is inserted after T02's gate in `main()`)
- Stub-mode discipline — `M033_GHINIT_STUB=1` produces pass-not-skip; no `EXIT 77`, no `SKIP:` token
- Same failure-propagation contract as T02 — sequential-atomicity preserves all upstream sub-flow markers (and wiki-init marker if present) on github failure
- T03 MUST NOT introduce any speckit.* references (CON-3 / Principle XVI)

## Expected Output

T03 modifies 1 existing file and creates 1 new file:
- `scripts/lifecycle/start.sh` (modify, +50 net lines added — 1 flag-parser case + 1 function ~40 lines + 1 main()-block invocation gate ~8 lines + variable initialization + comment block; on top of T02's +80)
- `tools/verify/m033-p05-with-github-passthrough-shape.sh` (create, ≥30 lines, executable)

After T03 lands, `bash tools/verify/m033-p05-with-github-passthrough-shape.sh` emits `SUMMARY: m033-p05-with-github-passthrough-shape.sh pass=N fail=0` and the cross-phase regression checks (T02 verifier + SC-1) inside the verifier pass.

## Notes

### Ordering rule enforcement (FR-16)

Per the spec, "github-init MUST NOT fire before wiki-init when both flags are present." T02's gate exits on wiki failure (`exit "$WIKI_RC"`) and falls through (returns 0) on wiki success. T03's gate is inserted IMMEDIATELY AFTER T02's gate in `main()`. Therefore:
- `--with-wiki --with-github` (wiki succeeds): wiki gate runs and returns 0, github gate runs.
- `--with-wiki --with-github` (wiki fails): wiki gate exits with `WIKI_RC`, github gate never runs.
- `--with-github` only: wiki gate is skipped (`WITH_WIKI=0`), github gate runs.
- `--with-wiki` only: wiki gate runs, github gate is skipped (`WITH_GITHUB=0`).

The acceptance script (T04 / SC-10) verifies the token ordering by `grep -n` for the two `STUB:` tokens and asserting the wiki line number is less than the github line number.

### `github_init_invoked` already in the closed JSONL enum

P02/T01 shipped the FR-22 emitter with `github_init_invoked` as one of the 11 documented event types; P03/T04 additively extended to 12. T03 calls `emit github_init_invoked` directly — no enum extension required. Verify at task-start by `grep -F 'github_init_invoked' scripts/util/jsonl-event-emitter.sh`; if absent, T03 includes a 1-line additive enum extension matching the P03/T04 precedent.

### Path-collision check (Plan-Time Discipline rule 6)

- `tools/verify/m033-p05-with-github-passthrough-shape.sh` — verified absent at planning time
- `scripts/lifecycle/start.sh` — present (T02-extended); declared as `modify`, NOT `create`

### Verifier-availability cross-check (Plan-Time Discipline rule 2)

`bash tools/verify/m033-p05-with-github-passthrough-shape.sh` is co-authored in step 2 of this task. The cross-phase regression checks for `tools/verify/m033-p05-with-wiki-passthrough-shape.sh` and `tests/m033-acceptance/p01-start-branch-routing.sh` are guarded with `[ -f ... ]` so they do not fail T03 if those files are not yet on disk (they ARE on disk at T03 task-start per Prerequisites — the guards are defensive against re-run scenarios).

### Argument-parser extension is non-overlapping

T03's new flag `--with-github` does not overlap with P01's flags (`--project-dir`, `--yes`, `--branch`, `--stack`, `--dry-run`), P02's flag (`--no-resume`), or T02's flags (`--with-wiki`, `--with-giscus`, `--deploy`).

### Real-mode compatibility (Assumption A-2)

Per spec Assumption A-2, M013's `orchestrator:github-init` is closed and accepts (or can be wrapped to accept) `--project-dir <path>`. T03's real-mode invocation calls `bash scripts/lifecycle/github-init.sh --project-dir <project-dir>`. If M013's existing entry point does not accept this flag, T03 includes a one-line wrapper (e.g., extending `scripts/lifecycle/github-init.sh` to translate `--project-dir` to M013's internal flag form) — implementation choice at execution time.
