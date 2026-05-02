#!/usr/bin/env bash
# p00-pre-stub-shape.sh
#
# Verifier for M031/P00/T02 pre-M031 stub: asserts pre-m031-stub.sh
# exists, is executable, freezes the pre-M031 dispatch path semantics
# by NOT calling scripts/dispatch/build-context.sh (AD-14 single-window
# discipline), declares the JSONL emission keys, and produces valid
# JSONL when invoked against task-01.txt.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no
# process substitution. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/p00-pre-stub-shape.sh
#   bash tools/verify/p00-pre-stub-shape.sh path/to/pre-m031-stub.sh
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

file="${1:-tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh}"
fixture_dir="$(dirname "$file")"

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

# Check 1: file exists
if [ ! -f "$file" ]; then
    echo "FAIL: pre-m031-stub.sh missing at $file"
    echo "SUMMARY: p00-pre-stub-shape.sh pass=0 fail=1"
    exit 1
fi
check_pass "pre-m031-stub.sh exists at $file"

# Check 2: file is executable
if [ -x "$file" ]; then
    check_pass "pre-m031-stub.sh is executable"
else
    check_fail "pre-m031-stub.sh is not executable (chmod +x missing)"
fi

# Check 3: AD-14 discipline — stub MUST NOT call build-context.sh.
# The literal "scripts/dispatch/build-context.sh" string in the body
# is the trigger; documentation comments mentioning the bare filename
# "build-context.sh" without the path prefix are allowed.
if grep -q 'scripts/dispatch/build-context.sh' "$file"; then
    # The header documents that we MUST NOT call it; it's allowed in
    # comment context. Distinguish: any non-comment occurrence fails.
    # A simple proxy: every occurrence-line must start with `#` after
    # optional leading whitespace.
    bad_count=0
    tmp_g=$(mktemp -t p00-pre-stub-shape.XXXXXX)
    grep -n 'scripts/dispatch/build-context.sh' "$file" > "$tmp_g"
    while IFS= read -r line; do
        # line is "<lineno>:<content>"; strip up to first ':'
        content="${line#*:}"
        # Trim leading whitespace.
        while [ -n "$content" ] && [ "${content# }" != "$content" ]; do
            content="${content# }"
        done
        # If the line does not start with '#', it's a real call.
        case "$content" in
            \#*) ;;
            *) bad_count=$((bad_count + 1)) ;;
        esac
    done < "$tmp_g"
    rm -f "$tmp_g"
    if [ "$bad_count" -eq 0 ]; then
        check_pass "AD-14 discipline: build-context.sh referenced only in comments"
    else
        check_fail "AD-14 violation: $bad_count non-comment reference(s) to scripts/dispatch/build-context.sh"
    fi
else
    check_pass "AD-14 discipline: no reference to scripts/dispatch/build-context.sh"
fi

# Check 4: file declares the pre-M031 JSONL emission keys
keys_missing=""
if ! grep -q '"path":"pre-m031"' "$file"; then keys_missing="$keys_missing [path]"; fi
if ! grep -q 'knowledge_section_tokens' "$file"; then keys_missing="$keys_missing [knowledge_section_tokens]"; fi
if [ -z "$keys_missing" ]; then
    check_pass "pre-M031 JSONL emission keys present"
else
    check_fail "JSONL emission keys missing:$keys_missing"
fi

# Check 5: stub is invokable — runs against task-01.txt and emits
# the expected JSONL shape on stdout.
fixture="$fixture_dir/task-01.txt"
if [ -f "$fixture" ]; then
    tmp_out=$(mktemp -t p00-pre-stub-shape.XXXXXX)
    if bash "$file" "$fixture" > "$tmp_out" 2>/dev/null; then
        if grep -q '"task_id":"task-01"' "$tmp_out"; then
            check_pass "stub invocation against task-01.txt emits valid JSONL"
        else
            check_fail "stub invocation produced output without expected task_id key"
        fi
    else
        check_fail "stub invocation against task-01.txt exited non-zero"
    fi
    rm -f "$tmp_out"
else
    check_fail "fixture task-01.txt missing at $fixture; cannot run invocation check"
fi

# Final summary
echo "SUMMARY: p00-pre-stub-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
