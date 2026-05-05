#!/usr/bin/env bash
# m033-p02-start-state-markers-shape.sh
#
# T02 verifier: shape + functional smoke + negative-path coverage of
# scripts/util/start-state-markers.sh (FR-20 marker primitives).
#
# Asserts:
#   - The library exists and is executable.
#   - The four subcommand tokens (write, read, next, clear) appear.
#   - The fenced SSOT block markers appear.
#   - All 7 closed-enum sub-flow names appear.
#   - The `.orchestrator/start-state` path token appears.
#   - The `.complete` filename suffix appears.
#   - Functional smoke: write -> read -> next -> clear cycle works.
#   - Negative path: unknown sub-flow exits non-zero with enum echoed.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/util/start-state-markers.sh"

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

# Check 1: file exists.
if [ ! -f "$target" ]; then
    echo "FAIL: start-state-markers.sh missing at $target"
    echo "SUMMARY: m033-p02-start-state-markers-shape.sh pass=0 fail=1"
    exit 1
fi
check_pass "start-state-markers.sh exists at $target"

# Check 2: executable.
if [ ! -x "$target" ]; then
    check_fail "start-state-markers.sh not executable: $target"
else
    check_pass "start-state-markers.sh is executable"
fi

# Check 3-6: four subcommand tokens.
for tok in write read next clear; do
    if grep -F -q -- "$tok" "$target"; then
        check_pass "subcommand token present: $tok"
    else
        check_fail "subcommand token missing: $tok"
    fi
done

# Check 7-8: fenced SSOT block markers.
if grep -F -q '# >>> subflow-names >>>' "$target"; then
    check_pass 'fenced SSOT opening marker present'
else
    check_fail 'fenced SSOT opening marker missing: # >>> subflow-names >>>'
fi
if grep -F -q '# <<< subflow-names <<<' "$target"; then
    check_pass 'fenced SSOT closing marker present'
else
    check_fail 'fenced SSOT closing marker missing: # <<< subflow-names <<<'
fi

# Check 9-15: all 7 closed-enum sub-flow names.
for name in init-invoked ideation materials-intake ingest-codebase migrate-routed constitution-authored customblock-drafted; do
    if grep -F -q -- "$name" "$target"; then
        check_pass "sub-flow enum token present: $name"
    else
        check_fail "sub-flow enum token missing: $name"
    fi
done

# Check 16: marker dir path token.
if grep -F -q '.orchestrator/start-state' "$target"; then
    check_pass "marker path token '.orchestrator/start-state' present"
else
    check_fail "marker path token '.orchestrator/start-state' missing"
fi

# Check 17: .complete suffix token.
if grep -F -q '.complete' "$target"; then
    check_pass "marker filename suffix '.complete' present"
else
    check_fail "marker filename suffix '.complete' missing"
fi

# --- Functional smoke test ---

staging="$(mktemp -d 2>/dev/null)"
if [ -z "$staging" ] || [ ! -d "$staging" ]; then
    check_fail "could not create mktemp -d staging dir for smoke test"
    echo "SUMMARY: m033-p02-start-state-markers-shape.sh pass=$pass fail=$fail"
    if [ "$fail" -gt 0 ]; then
        exit 1
    fi
    exit 0
fi

# write ideation
bash "$target" write ideation "$staging"
write_rc=$?
if [ "$write_rc" -eq 0 ]; then
    check_pass "write ideation exited 0"
else
    check_fail "write ideation exited $write_rc"
fi

if [ -f "$staging/.orchestrator/start-state/ideation.complete" ]; then
    check_pass "marker file created at expected path"
else
    check_fail "marker file NOT created at .orchestrator/start-state/ideation.complete"
fi

# Idempotent re-write preserves first timestamp.
first_body=$(cat "$staging/.orchestrator/start-state/ideation.complete" 2>/dev/null)
sleep 1
bash "$target" write ideation "$staging"
second_body=$(cat "$staging/.orchestrator/start-state/ideation.complete" 2>/dev/null)
if [ "$first_body" = "$second_body" ]; then
    check_pass "idempotent re-write preserves first-completion timestamp"
else
    check_fail "re-write changed timestamp from '$first_body' to '$second_body'"
fi

# read returns single line "ideation"
read_out="$staging/read.out"
bash "$target" read "$staging" > "$read_out"
read_content=$(cat "$read_out")
if [ "$read_content" = "ideation" ]; then
    check_pass "read returns single line 'ideation'"
else
    check_fail "read returned '$read_content' (expected 'ideation')"
fi

# With only 'ideation' written, the first absent in execution order is
# 'init-invoked' (predecessor of ideation). Verify that.
next_out=$(bash "$target" next "$staging")
if [ "$next_out" = "init-invoked" ]; then
    check_pass "next returns 'init-invoked' (first absent in execution order)"
else
    check_fail "next returned '$next_out' (expected 'init-invoked')"
fi

# Now write init-invoked. Next should advance to 'materials-intake'
# (the first absent after init-invoked + ideation are present).
bash "$target" write init-invoked "$staging"
next_out2=$(bash "$target" next "$staging")
if [ "$next_out2" = "materials-intake" ]; then
    check_pass "next after init-invoked+ideation returns 'materials-intake'"
else
    check_fail "next after init-invoked+ideation returned '$next_out2' (expected 'materials-intake')"
fi

# clear ideation (init-invoked stays present).
bash "$target" clear ideation "$staging"
if [ ! -f "$staging/.orchestrator/start-state/ideation.complete" ]; then
    check_pass "clear removed ideation marker"
else
    check_fail "clear did not remove ideation.complete"
fi

# After clearing only ideation, the first absent in execution order
# is 'ideation' (init-invoked still present).
next_after_clear=$(bash "$target" next "$staging")
if [ "$next_after_clear" = "ideation" ]; then
    check_pass "next after partial clear returns 'ideation' (first absent)"
else
    check_fail "next after partial clear returned '$next_after_clear' (expected 'ideation')"
fi

# Clear all to verify clear is idempotent + verify all-cleared next.
bash "$target" clear init-invoked "$staging"
next_all_cleared=$(bash "$target" next "$staging")
if [ "$next_all_cleared" = "init-invoked" ]; then
    check_pass "next with all cleared returns 'init-invoked' (execution start)"
else
    check_fail "next with all cleared returned '$next_all_cleared' (expected 'init-invoked')"
fi

# --- Negative path: unknown sub-flow ---

neg_stderr="$staging/neg.stderr"
bash "$target" write unknown-flow "$staging" >/dev/null 2>"$neg_stderr"
neg_rc=$?
if [ "$neg_rc" -ne 0 ]; then
    check_pass "negative: write unknown-flow exits non-zero (rc=$neg_rc)"
else
    check_fail "negative: write unknown-flow exited 0 (expected non-zero)"
fi

if grep -F -q 'init-invoked' "$neg_stderr"; then
    check_pass "negative: stderr names init-invoked (closed-enum echo)"
else
    check_fail "negative: stderr missing init-invoked"
fi
if grep -F -q 'customblock-drafted' "$neg_stderr"; then
    check_pass "negative: stderr names customblock-drafted (closed-enum echo)"
else
    check_fail "negative: stderr missing customblock-drafted"
fi

rm -rf "$staging"

echo "SUMMARY: m033-p02-start-state-markers-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
