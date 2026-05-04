#!/usr/bin/env bash
# tests/m033-acceptance/p08-with-github-passthrough.sh
# SC-10: FR-16 --with-github passthrough acceptance + ordering rule when both flags.
#
# Two-mode test contract per MIT-001 (mirrors SC-9 shape):
#   - Stub mode (M033_GHINIT_STUB=1) produces PASS not SKIP.
#   - Both-flags ordering rule (FR-16): when --with-wiki AND --with-github
#     are both passed, wiki-init MUST fire before github-init. Asserted
#     via stdout line-number ordering of the STUB tokens.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

seed_post_onboarding() {
    local stage="$1"
    mkdir -p "$stage/.orchestrator/start-state"
    for sf in init-invoked subflow-started subflow-completed; do
        date -u +%Y-%m-%dT%H:%M:%SZ > "$stage/.orchestrator/start-state/$sf.complete"
    done
    # Seed config.yml so invoke_init short-circuits.
    mkdir -p "$stage/.orchestrator"
    printf 'project_name: test\nruntime: claude-code\n' > "$stage/.orchestrator/config.yml"
}

# --- Test 1: stub rc=0.
STAGE1=$(mktemp -d)
seed_post_onboarding "$STAGE1"
M033_GHINIT_STUB=1 M033_GHINIT_STUB_EXIT_CODE=0 \
    bash scripts/lifecycle/start.sh --project-dir "$STAGE1" --branch greenfield-empty \
    --with-github --yes --dry-run \
    > "$STAGE1/stdout" 2> "$STAGE1/stderr"
RC1=$?
if [ "$RC1" -eq 0 ]; then
    pass "T1 stub rc=0"
else
    fail "T1 rc=$RC1"
fi
if grep -qF 'STUB: github-init invoked' "$STAGE1/stdout"; then
    pass "T1 STUB token"
else
    fail "T1 STUB token absent"
fi
if grep -qF '"github_init_invoked"' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null; then
    pass "T1 JSONL record"
else
    fail "T1 JSONL absent"
fi
if grep -qF '"stub_mode":true' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null; then
    pass "T1 stub_mode:true"
else
    fail "T1 stub_mode wrong"
fi
if grep -qF '"exit_code":0' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null; then
    pass "T1 exit_code:0"
else
    fail "T1 exit_code wrong"
fi
if [ -f "$STAGE1/.orchestrator/start-state/init-invoked.complete" ]; then
    pass "T1 markers preserved"
else
    fail "T1 markers cleared"
fi

# --- Test 2: stub rc=17.
STAGE2=$(mktemp -d)
seed_post_onboarding "$STAGE2"
M033_GHINIT_STUB=1 M033_GHINIT_STUB_EXIT_CODE=17 \
    bash scripts/lifecycle/start.sh --project-dir "$STAGE2" --branch greenfield-empty \
    --with-github --yes --dry-run \
    > "$STAGE2/stdout" 2> "$STAGE2/stderr"
RC2=$?
if [ "$RC2" -eq 17 ]; then
    pass "T2 stub rc=17 propagation"
else
    fail "T2 rc=$RC2 expected 17"
fi
if grep -qF 'github-init failed' "$STAGE2/stdout"; then
    pass "T2 failure diagnostic"
else
    fail "T2 diagnostic absent"
fi
if grep -qF 'all other onboarding outputs preserved' "$STAGE2/stdout"; then
    pass "T2 preservation diagnostic"
else
    fail "T2 preservation absent"
fi
if grep -qF '"exit_code":17' "$STAGE2/.orchestrator/execution-log.jsonl" 2>/dev/null; then
    pass "T2 exit_code:17"
else
    fail "T2 exit_code wrong"
fi
if [ -f "$STAGE2/.orchestrator/start-state/init-invoked.complete" ]; then
    pass "T2 markers preserved on failure"
else
    fail "T2 markers cleared on failure"
fi

# --- Test 3: --with-wiki --with-github ordering rule.
# When both flags are present, wiki-init MUST fire before github-init.
# Asserted via stdout line-number ordering of the STUB tokens.
STAGE3=$(mktemp -d)
seed_post_onboarding "$STAGE3"
M033_FR15_STUB=1 M033_GHINIT_STUB=1 \
    bash scripts/lifecycle/start.sh --project-dir "$STAGE3" --branch greenfield-empty \
    --with-wiki --with-github --yes --dry-run \
    > "$STAGE3/stdout" 2> "$STAGE3/stderr"
WIKI_LINE=$(grep -nF 'STUB: wiki-init invoked' "$STAGE3/stdout" | head -1 | cut -d: -f1)
GH_LINE=$(grep -nF 'STUB: github-init invoked' "$STAGE3/stdout" | head -1 | cut -d: -f1)
if [ -n "$WIKI_LINE" ] && [ -n "$GH_LINE" ] && [ "$WIKI_LINE" -lt "$GH_LINE" ]; then
    pass "T3 ordering: wiki ($WIKI_LINE) before github ($GH_LINE)"
else
    fail "T3 ordering violated: wiki=$WIKI_LINE github=$GH_LINE"
fi

# Cleanup.
rm -rf "$STAGE1" "$STAGE2" "$STAGE3"

printf 'SUMMARY: p08-with-github-passthrough.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
