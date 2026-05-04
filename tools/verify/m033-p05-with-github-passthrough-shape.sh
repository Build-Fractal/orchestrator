#!/usr/bin/env bash
# tools/verify/m033-p05-with-github-passthrough-shape.sh
# Asserts scripts/lifecycle/start.sh FR-16 additive extension shape +
# functional smoke (stub-mode, exit-code propagation, ordering rule) +
# cross-phase regression (T02 verifier + P01 SC-1 acceptance).
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
