#!/usr/bin/env bash
# m033-p02-fr21-convention-shape.sh
#
# T05 verifier: shape of references/m033-fr21-dual-write-convention.md.
#
# Asserts:
#   - The convention reference exists.
#   - The fenced fr-21-dual-write-callsites markers appear (open + close).
#   - The five FR IDs appear: FR-3, FR-7, FR-9, FR-10, FR-13.
#   - The five command basenames appear: constitution, ingest-codebase,
#     materials-intake, ideation, customblock-draft.
#   - The cross-reference to scripts/util/dual-write-runtime-md.sh
#     appears.
#   - The dual_write_agents config-flag token appears.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/references/m033-fr21-dual-write-convention.md"

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

if [ ! -f "$target" ]; then
    echo "FAIL: FR-21 convention reference missing at $target"
    echo "SUMMARY: m033-p02-fr21-convention-shape.sh pass=0 fail=1"
    exit 1
fi
check_pass "FR-21 convention reference exists at $target"

# Fenced markers (open + close).
if grep -F -q '# >>> fr-21-dual-write-callsites >>>' "$target"; then
    check_pass "open marker '# >>> fr-21-dual-write-callsites >>>' present"
else
    check_fail "open marker '# >>> fr-21-dual-write-callsites >>>' missing"
fi
if grep -F -q '# <<< fr-21-dual-write-callsites <<<' "$target"; then
    check_pass "close marker '# <<< fr-21-dual-write-callsites <<<' present"
else
    check_fail "close marker '# <<< fr-21-dual-write-callsites <<<' missing"
fi

# FR IDs.
for fr in FR-3 FR-7 FR-9 FR-10 FR-13; do
    if grep -F -q "$fr" "$target"; then
        check_pass "FR ID $fr present"
    else
        check_fail "FR ID $fr missing"
    fi
done

# Command basenames.
for cmd in constitution ingest-codebase materials-intake ideation customblock-draft; do
    if grep -F -q "$cmd" "$target"; then
        check_pass "command name '$cmd' present"
    else
        check_fail "command name '$cmd' missing"
    fi
done

# Cross-reference to dual-write helper.
if grep -F -q 'scripts/util/dual-write-runtime-md.sh' "$target"; then
    check_pass "cross-reference to scripts/util/dual-write-runtime-md.sh present"
else
    check_fail "cross-reference to scripts/util/dual-write-runtime-md.sh missing"
fi

# dual_write_agents config-flag token.
if grep -F -q 'dual_write_agents' "$target"; then
    check_pass "'dual_write_agents' config-flag token present"
else
    check_fail "'dual_write_agents' config-flag token missing"
fi

echo "SUMMARY: m033-p02-fr21-convention-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
