#!/usr/bin/env bash
# tools/verify/m032-p01-acceptance-shape-sc1.sh -- M032 P01 T04.
#
# Asserts the SC-1 acceptance script (tests/m032-acceptance/p01-managed-bundle-shape.sh)
# exists, references SC-1 / FR-1 / FR-2 / FR-4 by string, contains sha256 /
# `cmp -s` idempotency comparison logic, and exits 0 against the staged
# fresh-project fixture.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
SC1="$PROJECT_ROOT/tests/m032-acceptance/p01-managed-bundle-shape.sh"

pass=0
fail=0

check() {
    desc="$1"
    rc="$2"
    if [ "$rc" -eq 0 ]; then
        printf 'PASS: %s\n' "$desc"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s\n' "$desc"
        fail=$((fail + 1))
    fi
}

# 1. SC-1 script exists.
if [ -f "$SC1" ]; then
    check "SC-1 script exists at $SC1" 0
else
    check "SC-1 script exists at $SC1" 1
    printf 'SUMMARY: m032-p01-acceptance-shape-sc1.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. References SC-1.
if grep -qE 'SC-1\b' "$SC1"; then
    check "SC-1 script references 'SC-1'" 0
else
    check "SC-1 script references 'SC-1'" 1
fi

# 3. References FR-1 / FR-2 / FR-4.
for fr in FR-1 FR-2 FR-4; do
    if grep -qE "${fr}\b" "$SC1"; then
        check "SC-1 script references ${fr}" 0
    else
        check "SC-1 script references ${fr}" 1
    fi
done

# 4. Contains sha256 / shasum / `cmp -s` idempotency comparison.
sha_ok=1
if grep -qE 'shasum|sha256sum|sha256' "$SC1"; then
    sha_ok=0
fi
check "SC-1 script invokes a sha256 tool (shasum/sha256sum/sha256)" "$sha_ok"

if grep -q 'cmp -s' "$SC1"; then
    check "SC-1 script uses 'cmp -s' for byte-equality comparison" 0
else
    check "SC-1 script uses 'cmp -s' for byte-equality comparison" 1
fi

# 5. Exits 0 against the staged fixture.
sc1_out="$( bash "$SC1" 2>&1 )"
sc1_rc=$?
if [ "$sc1_rc" -eq 0 ]; then
    check "SC-1 script exits 0 against the staged fixture" 0
else
    check "SC-1 script exits 0 against the staged fixture" 1
    printf '%s\n' "$sc1_out" >&2
fi

# 6. Emits RESULT: ok line on success.
if printf '%s\n' "$sc1_out" | grep -qE '^RESULT: ok p01-managed-bundle-shape\.sh$'; then
    check "SC-1 script emits RESULT: ok line" 0
else
    check "SC-1 script emits RESULT: ok line" 1
fi

printf 'SUMMARY: m032-p01-acceptance-shape-sc1.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
