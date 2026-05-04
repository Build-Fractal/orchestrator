#!/usr/bin/env bash
# tools/verify/m033-p05-with-wiki-passthrough-shape.sh
#
# M033/P05/T02 — FR-15 --with-wiki paired-launch passthrough shape verifier.
#
# Asserts scripts/lifecycle/start.sh has been additively extended with the
# FR-15 surface (flag handlers, wiki_init_passthrough function, post-onboarding
# invocation gate, stub-mode dispatch, FR-22 wiki_init_invoked emit) AND that
# the SC-1 cross-phase regression (P01 acceptance) still passes.
#
# Spec ref: FR-15 / spec 035 FR-11 / CON-1 / MIT-001 two-mode test contract.

set -u
PASS=0
FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

START="scripts/lifecycle/start.sh"
if [ -f "$START" ]; then
    pass "start.sh exists"
else
    fail "start.sh missing"
    printf 'SUMMARY: m033-p05-with-wiki-passthrough-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
    exit 1
fi

# ---------------------------------------------------------------------------
# Token-presence shape assertions: load-bearing tokens that prove the
# additive-extension contract is intact.
# ---------------------------------------------------------------------------
for tok in '--with-wiki' '--with-giscus' '--deploy' \
           'WITH_WIKI' 'WITH_GISCUS' 'DEPLOY' \
           'M033_FR15_STUB' 'M033_FR15_STUB_EXIT_CODE' \
           'wiki_init_invoked' 'wiki-init failed' 'wiki-init.sh' \
           'STUB: wiki-init invoked' 'all other onboarding outputs preserved' \
           'wiki-init.sh not found' 'wiki_init_passthrough'; do
    if grep -qF -- "$tok" "$START"; then
        pass "token present: $tok"
    else
        fail "token absent: $tok"
    fi
done

# ---------------------------------------------------------------------------
# Functional smoke: stub-mode invocation under mktemp staging (rc=0 path).
# ---------------------------------------------------------------------------
STAGE=$(mktemp -d)
mkdir -p "$STAGE/.orchestrator/start-state"
touch "$STAGE/.orchestrator/start-state/init-invoked.complete"
SMOKE_RC=0
M033_FR15_STUB=1 M033_FR15_STUB_EXIT_CODE=0 \
    bash "$START" --project-dir "$STAGE" --branch greenfield-empty --with-wiki --yes --dry-run \
    > "$STAGE/stdout" 2> "$STAGE/stderr" || SMOKE_RC=$?
if grep -qF 'STUB: wiki-init invoked' "$STAGE/stdout"; then
    pass "stub-mode emits STUB token"
else
    fail "stub-mode did not emit STUB token"
fi
if [ "$SMOKE_RC" -eq 0 ]; then
    pass "stub-mode rc=0 propagation"
else
    fail "stub-mode rc=$SMOKE_RC expected 0"
fi

# ---------------------------------------------------------------------------
# Functional smoke: stub-mode non-zero exit propagation (rc=42).
# ---------------------------------------------------------------------------
STAGE2=$(mktemp -d)
mkdir -p "$STAGE2/.orchestrator/start-state"
touch "$STAGE2/.orchestrator/start-state/init-invoked.complete"
SMOKE_RC2=0
M033_FR15_STUB=1 M033_FR15_STUB_EXIT_CODE=42 \
    bash "$START" --project-dir "$STAGE2" --branch greenfield-empty --with-wiki --yes --dry-run \
    > "$STAGE2/stdout" 2> "$STAGE2/stderr" || SMOKE_RC2=$?
if [ "$SMOKE_RC2" -eq 42 ]; then
    pass "stub-mode exit-code propagation rc=42"
else
    fail "stub-mode rc=$SMOKE_RC2 expected 42"
fi
if grep -qF 'wiki-init failed' "$STAGE2/stdout"; then
    pass "stub-mode emits failure diagnostic"
else
    fail "stub-mode did not emit failure diagnostic"
fi

# ---------------------------------------------------------------------------
# Cross-phase regression: P01 SC-1 acceptance MUST still pass.
# AD-15 cross-phase regression discipline.
# ---------------------------------------------------------------------------
if [ -f "tests/m033-acceptance/p01-start-branch-routing.sh" ]; then
    SC1_RC=0
    bash tests/m033-acceptance/p01-start-branch-routing.sh > /dev/null 2>&1 || SC1_RC=$?
    if [ "$SC1_RC" -eq 0 ]; then
        pass "SC-1 cross-phase regression preserved"
    else
        fail "SC-1 regressed (rc=$SC1_RC)"
    fi
fi

rm -rf "$STAGE" "$STAGE2"

printf 'SUMMARY: m033-p05-with-wiki-passthrough-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
