#!/usr/bin/env bash
# tools/verify/m033-p05-acceptance-shape-sc10.sh
# Wrapper for tests/m033-acceptance/p08-with-github-passthrough.sh.
#
# Asserts the SC-10 acceptance script exists, is executable, contains the
# load-bearing tokens (FR-16 + ordering rule), and exits 0 when run.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

SCRIPT="tests/m033-acceptance/p08-with-github-passthrough.sh"
if [ -f "$SCRIPT" ]; then
    pass "script exists"
else
    fail "script missing"
fi
if [ -x "$SCRIPT" ]; then
    pass "script executable"
else
    fail "script not executable"
fi

# Token-presence shape check. Defensive `grep -qF --` (double-dash) so tokens
# starting with '--' aren't interpreted as grep flags (P04 wrapper-verifier
# pattern).
for tok in 'SC-10' 'FR-16' 'M033_GHINIT_STUB' 'M033_GHINIT_STUB_EXIT_CODE' \
           'github_init_invoked' 'github-init failed' \
           'all other onboarding outputs preserved' \
           'stub_mode' 'exit_code' \
           '--with-github' '--with-wiki' 'STUB: github-init invoked' \
           'STUB: wiki-init invoked' 'ordering'; do
    if grep -qF -- "$tok" "$SCRIPT"; then
        pass "token present: $tok"
    else
        fail "token absent: $tok"
    fi
done

LINES=$(wc -l < "$SCRIPT")
if [ "$LINES" -ge 110 ]; then
    pass "min 110 lines (got $LINES)"
else
    fail "below 110 lines (got $LINES)"
fi

# Functional run + exit propagation.
bash "$SCRIPT" > /dev/null 2> /dev/null
RC=$?
if [ "$RC" -eq 0 ]; then
    pass "functional rc=0"
else
    fail "functional rc=$RC"
fi

printf 'SUMMARY: m033-p05-acceptance-shape-sc10.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
