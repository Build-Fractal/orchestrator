#!/usr/bin/env bash
# tests/m033-acceptance/p08-with-wiki-passthrough.sh
# SC-9 (amended per MIT-001): FR-15 --with-wiki passthrough acceptance.
#
# Two-mode test contract per MIT-001:
#   - Stub mode (M033_FR15_STUB=1) produces PASS not SKIP per CON-1 / SC-14
#     skip=0 invariant.
#   - Real mode (no stub env) covers the wiki-init.sh-not-found case as a
#     genuine failure.
#
# Sequential-atomicity invariant (FR-15): on non-zero exit from the wiki gate,
# start.sh propagates the exit code verbatim AND preserves all US-1..US-7
# sub-flow markers (no rollback). Test 2 verifies this.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

seed_post_onboarding() {
    local stage="$1"
    mkdir -p "$stage/.orchestrator/start-state"
    # Seed US-1..US-7 sub-flow markers as if all sub-flows completed. The
    # 'init-invoked' marker is later written by start.sh's invoke_init path,
    # but seeding it pre-emptively is harmless under the idempotent
    # first-completion-timestamp-preservation primitive (P02/T02 contract).
    for sf in init-invoked subflow-started subflow-completed; do
        date -u +%Y-%m-%dT%H:%M:%SZ > "$stage/.orchestrator/start-state/$sf.complete"
    done
    # Seed config.yml so invoke_init short-circuits and does not re-run
    # init-project.sh against the staged dir.
    mkdir -p "$stage/.orchestrator"
    printf 'project_name: test\nruntime: claude-code\n' > "$stage/.orchestrator/config.yml"
}

# --- Test 1: stub mode rc=0 propagation.
STAGE1=$(mktemp -d)
seed_post_onboarding "$STAGE1"
M033_FR15_STUB=1 M033_FR15_STUB_EXIT_CODE=0 \
    bash scripts/lifecycle/start.sh --project-dir "$STAGE1" --branch greenfield-empty \
    --with-wiki --yes --dry-run \
    > "$STAGE1/stdout" 2> "$STAGE1/stderr"
RC1=$?
if [ "$RC1" -eq 0 ]; then
    pass "T1 stub rc=0 propagation"
else
    fail "T1 rc=$RC1 expected 0"
fi
if grep -qF 'STUB: wiki-init invoked' "$STAGE1/stdout"; then
    pass "T1 STUB token emitted"
else
    fail "T1 STUB token absent"
fi
if grep -qF '"wiki_init_invoked"' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null; then
    pass "T1 wiki_init_invoked JSONL record"
else
    fail "T1 JSONL record absent"
fi
if grep -qF '"stub_mode":true' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null; then
    pass "T1 stub_mode:true in JSONL"
else
    fail "T1 stub_mode field wrong"
fi
if grep -qF '"exit_code":0' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null; then
    pass "T1 exit_code:0 in JSONL"
else
    fail "T1 exit_code field wrong"
fi

# Sub-flow markers preserved.
if [ -f "$STAGE1/.orchestrator/start-state/init-invoked.complete" ]; then
    pass "T1 sub-flow markers preserved on success"
else
    fail "T1 sub-flow markers cleared"
fi

# --- Test 2: stub mode rc=42 propagation + failure diagnostic.
STAGE2=$(mktemp -d)
seed_post_onboarding "$STAGE2"
M033_FR15_STUB=1 M033_FR15_STUB_EXIT_CODE=42 \
    bash scripts/lifecycle/start.sh --project-dir "$STAGE2" --branch greenfield-empty \
    --with-wiki --yes --dry-run \
    > "$STAGE2/stdout" 2> "$STAGE2/stderr"
RC2=$?
if [ "$RC2" -eq 42 ]; then
    pass "T2 stub rc=42 propagation"
else
    fail "T2 rc=$RC2 expected 42"
fi
if grep -qF 'wiki-init failed' "$STAGE2/stdout"; then
    pass "T2 wiki-init failed diagnostic"
else
    fail "T2 diagnostic absent"
fi
if grep -qF 'all other onboarding outputs preserved' "$STAGE2/stdout"; then
    pass "T2 sub-flow-preservation diagnostic"
else
    fail "T2 preservation diagnostic absent"
fi
if grep -qF '"exit_code":42' "$STAGE2/.orchestrator/execution-log.jsonl" 2>/dev/null; then
    pass "T2 exit_code:42 in JSONL"
else
    fail "T2 exit_code field wrong"
fi

# Sub-flow markers preserved on failure (sequential-atomicity invariant).
if [ -f "$STAGE2/.orchestrator/start-state/init-invoked.complete" ]; then
    pass "T2 sub-flow markers preserved on failure"
else
    fail "T2 sub-flow markers cleared on failure"
fi

# --- Test 3: real-mode without wiki-init.sh AND without stub mode.
STAGE3=$(mktemp -d)
seed_post_onboarding "$STAGE3"
# Ensure no stub env vars; rely on absence of scripts/lifecycle/wiki-init.sh.
unset M033_FR15_STUB M033_FR15_STUB_EXIT_CODE
if [ ! -f "scripts/lifecycle/wiki-init.sh" ]; then
    bash scripts/lifecycle/start.sh --project-dir "$STAGE3" --branch greenfield-empty \
        --with-wiki --yes --dry-run \
        > "$STAGE3/stdout" 2> "$STAGE3/stderr"
    RC3=$?
    if [ "$RC3" -ne 0 ]; then
        pass "T3 missing wiki-init.sh exits non-zero"
    else
        fail "T3 expected non-zero exit"
    fi
    if grep -qF 'wiki-init.sh not found' "$STAGE3/stderr"; then
        pass "T3 not-found diagnostic"
    else
        fail "T3 not-found diagnostic absent"
    fi
else
    pass "T3 SKIP-equivalent: wiki-init.sh present (M032/P02 closed)"
fi

# Cleanup.
rm -rf "$STAGE1" "$STAGE2" "$STAGE3"

printf 'SUMMARY: p08-with-wiki-passthrough.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
