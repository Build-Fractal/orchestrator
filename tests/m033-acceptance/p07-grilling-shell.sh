#!/usr/bin/env bash
# tests/m033-acceptance/p07-grilling-shell.sh
#
# SC-11 acceptance — exercises the full FR-17 / FR-18 / MIT-007 surface
# of scripts/lifecycle/grilling-shell.sh end-to-end against synthetic
# `mktemp -d` staging.
#
# References:
#   - SC-11 (acceptance: grilling shell + glossary writer + contradiction)
#   - FR-17 (ask_one public API: recommendation-not-interrogation)
#   - FR-18 (inline glossary writer at <PROJECT_DIR>/wiki/glossary.md)
#   - MIT-007 (live contradiction detection vs accumulator)
#
# Load-bearing tokens asserted:
#   - recommendation: <value>
#   - answer: <value>
#   - contradiction: <qkey> prior=<a> new=<b>
#   - attestation: <reason>
#   - <PROJECT_DIR>/wiki/glossary.md alphabetized-insert
#
# Bash 3.2 compatible. No declare -A, no process substitution.
#
# Usage:
#   bash tests/m033-acceptance/p07-grilling-shell.sh
#
# Output:
#   stdout per-test PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODULE="$PROJECT_ROOT/scripts/lifecycle/grilling-shell.sh"

pass=0
fail=0

check_pass() {
    pass=$((pass + 1))
    echo "PASS: $1"
}

check_fail() {
    fail=$((fail + 1))
    echo "FAIL: $1"
}

if [ ! -f "$MODULE" ]; then
    check_fail "scripts/lifecycle/grilling-shell.sh missing — cannot run SC-11"
    echo "SUMMARY: p07-grilling-shell.sh pass=$pass fail=$fail"
    exit 1
fi

STAGING=""
STAGING=$(mktemp -d)
cleanup() {
    if [ -n "$STAGING" ] && [ -d "$STAGING" ]; then
        rm -rf "$STAGING"
    fi
}
trap cleanup EXIT

# ----------------------------------------------------------------------------
# Test 1: recommendation-not-interrogation ordering. y-path accepts the
# recommendation. Assert recommendation: precedes answer: in stdout.
# ----------------------------------------------------------------------------
T1_OUT="$STAGING/t1.out"
PROJECT_DIR="$STAGING" \
_GRILLING_CURRENT_QKEY="stack" \
bash -c ". \"$MODULE\" && ask_one 'What stack?' 'web-saas' ''" \
    < <(printf 'y\n') \
    > "$T1_OUT" 2>/dev/null \
    || true

if grep -qF 'recommendation: web-saas' "$T1_OUT"; then
    check_pass "Test 1: recommendation: web-saas appears"
else
    check_fail "Test 1: recommendation: web-saas missing (got: $(cat "$T1_OUT"))"
fi

if grep -qF 'answer: web-saas' "$T1_OUT"; then
    check_pass "Test 1: answer: web-saas appears"
else
    check_fail "Test 1: answer: web-saas missing (got: $(cat "$T1_OUT"))"
fi

t1_rec=$(grep -nF 'recommendation:' "$T1_OUT" | head -1 | cut -d: -f1)
t1_ans=$(grep -nF 'answer:' "$T1_OUT" | head -1 | cut -d: -f1)
if [ -n "$t1_rec" ] && [ -n "$t1_ans" ] && [ "$t1_rec" -lt "$t1_ans" ]; then
    check_pass "Test 1: recommendation: precedes answer: (FR-17 ordering)"
else
    check_fail "Test 1: ordering broken (rec=$t1_rec ans=$t1_ans)"
fi

# ----------------------------------------------------------------------------
# Test 2: explicit answer (n/N path). User rejects recommendation, supplies
# 'fastify'. Assert answer: fastify appears.
# ----------------------------------------------------------------------------
T2_OUT="$STAGING/t2.out"
PROJECT_DIR="$STAGING" \
_GRILLING_CURRENT_QKEY="stack-explicit" \
bash -c ". \"$MODULE\" && ask_one 'What stack?' 'web-saas' ''" \
    < <(printf 'n\nfastify\n') \
    > "$T2_OUT" 2>/dev/null \
    || true

if grep -qF 'answer: fastify' "$T2_OUT"; then
    check_pass "Test 2: explicit answer fastify resolved via n-branch"
else
    check_fail "Test 2: answer: fastify missing (got: $(cat "$T2_OUT"))"
fi

# ----------------------------------------------------------------------------
# Test 3: contradiction detection fires (MIT-007).
# Pre-populate accumulator with target-user: consumer. Then ask_one with the
# recommendation 'enterprise' under qkey target-user against the accumulator.
# stdin: 'y' to accept enterprise, then '!still-the-right-call' to reconcile
# via attestation.
# Expected stdout (in order): contradiction:..., attestation:..., answer: enterprise
# ----------------------------------------------------------------------------
ACCUM="$STAGING/partial-answers.yml"
printf 'target-user: consumer\n' > "$ACCUM"

T3_OUT="$STAGING/t3.out"
PROJECT_DIR="$STAGING" \
_GRILLING_CURRENT_QKEY="target-user" \
bash -c ". \"$MODULE\" && ask_one 'Refine target user?' 'enterprise' '$ACCUM'" \
    < <(printf 'y\n!still-the-right-call\n') \
    > "$T3_OUT" 2>/dev/null \
    || true

if grep -qF 'contradiction: target-user prior=consumer new=enterprise' "$T3_OUT"; then
    check_pass "Test 3: contradiction: target-user prior=consumer new=enterprise on stdout"
else
    check_fail "Test 3: contradiction: line missing (got: $(cat "$T3_OUT"))"
fi

if grep -qF 'attestation: still-the-right-call' "$T3_OUT"; then
    check_pass "Test 3: attestation: still-the-right-call on stdout"
else
    check_fail "Test 3: attestation: line missing (got: $(cat "$T3_OUT"))"
fi

if grep -qF 'answer: enterprise' "$T3_OUT"; then
    check_pass "Test 3: answer: enterprise appears after attestation"
else
    check_fail "Test 3: answer: enterprise missing (got: $(cat "$T3_OUT"))"
fi

t3_con=$(grep -nF 'contradiction:' "$T3_OUT" | head -1 | cut -d: -f1)
t3_ans=$(grep -nF 'answer:' "$T3_OUT" | head -1 | cut -d: -f1)
if [ -n "$t3_con" ] && [ -n "$t3_ans" ] && [ "$t3_con" -lt "$t3_ans" ]; then
    check_pass "Test 3: contradiction: precedes answer: (MIT-007 ordering)"
else
    check_fail "Test 3: contradiction did not precede answer (con=$t3_con ans=$t3_ans)"
fi

# ----------------------------------------------------------------------------
# Test 4: glossary trigger writes alphabetized.
# Pre-populate <staging>/wiki/glossary.md with two entries: alpha, gamma.
# Trigger qkey framework-chosen with answer 'beta' — must insert between.
# ----------------------------------------------------------------------------
mkdir -p "$STAGING/wiki"
GLOSSARY="$STAGING/wiki/glossary.md"
printf 'alpha: first entry\ngamma: third entry\n' > "$GLOSSARY"

T4_OUT="$STAGING/t4.out"
PROJECT_DIR="$STAGING" \
_GRILLING_CURRENT_QKEY="framework-chosen" \
bash -c ". \"$MODULE\" && ask_one 'Which framework?' 'beta' ''" \
    < <(printf 'y\n') \
    > "$T4_OUT" 2>/dev/null \
    || true

# Capture line ordering of beta entry.
t4_alpha=$(grep -nF 'alpha:' "$GLOSSARY" | head -1 | cut -d: -f1)
t4_beta=$(grep -nF 'beta:' "$GLOSSARY" | head -1 | cut -d: -f1)
t4_gamma=$(grep -nF 'gamma:' "$GLOSSARY" | head -1 | cut -d: -f1)

if [ -n "$t4_alpha" ] && [ -n "$t4_beta" ] && [ -n "$t4_gamma" ] \
   && [ "$t4_alpha" -lt "$t4_beta" ] && [ "$t4_beta" -lt "$t4_gamma" ]; then
    check_pass "Test 4: beta inserted between alpha and gamma (alphabetized-insert)"
else
    check_fail "Test 4: alphabetized order broken (alpha=$t4_alpha beta=$t4_beta gamma=$t4_gamma) file=$(cat "$GLOSSARY")"
fi

if grep -qE '^beta: ' "$GLOSSARY"; then
    check_pass "Test 4: beta entry written in <term>: <def> shape"
else
    check_fail "Test 4: beta entry shape wrong (got: $(grep '^beta' "$GLOSSARY"))"
fi

# Save snapshot for idempotency check.
GLOSSARY_T4_SNAPSHOT="$STAGING/glossary.t4.snapshot"
cp "$GLOSSARY" "$GLOSSARY_T4_SNAPSHOT"

# ----------------------------------------------------------------------------
# Test 5: glossary idempotent on identical input. Re-run same trigger, same
# answer; assert byte-identical to Test 4 snapshot.
# ----------------------------------------------------------------------------
T5_OUT="$STAGING/t5.out"
PROJECT_DIR="$STAGING" \
_GRILLING_CURRENT_QKEY="framework-chosen" \
bash -c ". \"$MODULE\" && ask_one 'Which framework?' 'beta' ''" \
    < <(printf 'y\n') \
    > "$T5_OUT" 2>/dev/null \
    || true

if cmp -s "$GLOSSARY" "$GLOSSARY_T4_SNAPSHOT"; then
    check_pass "Test 5: glossary byte-identical after re-trigger (FR-18 idempotency)"
else
    check_fail "Test 5: glossary changed on identical re-trigger"
    diff "$GLOSSARY_T4_SNAPSHOT" "$GLOSSARY" || true
fi

# ----------------------------------------------------------------------------
# Test 6: non-trigger qkey produces no glossary entry. qkey 'stack' is NOT in
# _GRILLING_GLOSSARY_TRIGGERS; the glossary file must be unchanged from Test 5.
# ----------------------------------------------------------------------------
T6_OUT="$STAGING/t6.out"
PROJECT_DIR="$STAGING" \
_GRILLING_CURRENT_QKEY="stack" \
bash -c ". \"$MODULE\" && ask_one 'What stack?' 'web-saas' ''" \
    < <(printf 'y\n') \
    > "$T6_OUT" 2>/dev/null \
    || true

if cmp -s "$GLOSSARY" "$GLOSSARY_T4_SNAPSHOT"; then
    check_pass "Test 6: non-trigger qkey produces no glossary write"
else
    check_fail "Test 6: glossary mutated by non-trigger qkey"
fi

echo ""
echo "SUMMARY: p07-grilling-shell.sh pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
