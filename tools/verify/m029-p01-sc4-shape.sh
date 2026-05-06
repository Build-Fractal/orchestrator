#!/usr/bin/env bash
# tools/verify/m029-p01-sc4-shape.sh -- M029 P01 SC-4 acceptance-script verifier.
#
# Asserts tests/m029-acceptance/p01-sc4-context.sh exists, is executable,
# names FR-4 / SC-4 in its header, invokes orchestrator:context, greps for
# the six required field labels, implements the sentinel-file read-only
# precursor check (m029-p01-sc4-sentinel + find -newer), and runs green
# end-to-end (exit 0).
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SC4="$PROJECT_ROOT/tests/m029-acceptance/p01-sc4-context.sh"

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

# 1. File exists.
if [ -f "$SC4" ]; then
    check "tests/m029-acceptance/p01-sc4-context.sh exists" 0
else
    printf 'FAIL: tests/m029-acceptance/p01-sc4-context.sh missing\n'
    fail=$((fail + 1))
    printf 'SUMMARY: m029-p01-sc4-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Executable.
if [ -x "$SC4" ]; then
    check "SC-4 script is executable" 0
else
    check "SC-4 script is executable" 1
fi

# 3. Header references SC-4 AND FR-4.
if grep -F -q -- 'SC-4' "$SC4"; then
    check "header references SC-4" 0
else
    check "header references SC-4" 1
fi
if grep -F -q -- 'FR-4' "$SC4"; then
    check "header references FR-4" 0
else
    check "header references FR-4" 1
fi

# 4. Invokes orchestrator:context (literal token; the embedded reference
#    renderer is named m029_render_context per the SC-2 precedent, and the
#    contract document is named in comments + assertion descriptions).
if grep -F -q -- 'orchestrator:context' "$SC4"; then
    check "script invokes orchestrator:context (literal token present)" 0
else
    check "script invokes orchestrator:context (literal token present)" 1
fi

# 5. Greps for the six required field labels.
for label in \
    'resolved root:' \
    'runtime:' \
    'capability profile:' \
    'intensity defaults:' \
    'active milestone:' \
    'lock state:' ; do
    if grep -F -q -- "$label" "$SC4"; then
        check "field label asserted: '$label'" 0
    else
        check "field label asserted: '$label'" 1
    fi
done

# 6. Implements the sentinel-file read-only check.
if grep -F -q -- 'm029-p01-sc4-sentinel' "$SC4"; then
    check "sentinel-file token present (m029-p01-sc4-sentinel)" 0
else
    check "sentinel-file token present (m029-p01-sc4-sentinel)" 1
fi
if grep -F -q -- 'find ' "$SC4"; then
    check "find invocation present" 0
else
    check "find invocation present" 1
fi
if grep -F -q -- '-newer' "$SC4"; then
    check "-newer flag present (sentinel mtime check)" 0
else
    check "-newer flag present (sentinel mtime check)" 1
fi

# 7. Run the SC-4 script and assert exit 0.
if bash "$SC4" >/dev/null 2>&1; then
    check "SC-4 script runs green (exit 0)" 0
else
    check "SC-4 script runs green (exit 0)" 1
fi

printf 'SUMMARY: m029-p01-sc4-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
