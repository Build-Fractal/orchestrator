#!/usr/bin/env bash
# tools/verify/m029-p01-headline-shape-contract.sh -- M029 P01 FR-2 / SC-2 gate verifier.
#
# Asserts references/status-headline-shape.md exists and carries the
# canonical Principle III design contract sections, the headline-regex
# fenced block, the five field names, and the FR-2 / SC-2 / CON-5
# spec references. T03's headline implementation reads this contract;
# this verifier ensures the contract cannot drift silently.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
CONTRACT="$PROJECT_ROOT/references/status-headline-shape.md"

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
if [ -f "$CONTRACT" ]; then
    check "references/status-headline-shape.md exists" 0
else
    printf 'FAIL: references/status-headline-shape.md missing\n'
    fail=$((fail + 1))
    printf 'SUMMARY: m029-p01-headline-shape-contract.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Required H1 + H2 headers present.
for header in \
    '# Status Headline Shape' \
    '## Purpose' \
    '## Field Set' \
    '## Line Packing' \
    '## Embedded Footer' \
    '## Regex' \
    '## CON-5 Suppression Matrix' \
    '## Cross-References' ; do
    if grep -F -q -- "$header" "$CONTRACT"; then
        check "header present: $header" 0
    else
        check "header present: $header" 1
    fi
done

# 3. headline-regex fenced block present (literal token).
if grep -F -q 'headline-regex' "$CONTRACT"; then
    check "headline-regex fenced block token present" 0
else
    check "headline-regex fenced block token present" 1
fi

# 4. Five field names appear (verbatim tokens).
for field in milestone phase_index lock_state last_dispatch last_verify; do
    if grep -F -q -- "$field" "$CONTRACT"; then
        check "field name present: $field" 0
    else
        check "field name present: $field" 1
    fi
done

# 5. Spec references appear (FR-2 / SC-2 / CON-5).
for ref in FR-2 SC-2 CON-5; do
    if grep -F -q -- "$ref" "$CONTRACT"; then
        check "spec reference present: $ref" 0
    else
        check "spec reference present: $ref" 1
    fi
done

# 6. Cross-reference to the JSON schema companion contract.
if grep -F -q 'references/status-json-schema.md' "$CONTRACT"; then
    check "cross-reference to references/status-json-schema.md present" 0
else
    check "cross-reference to references/status-json-schema.md present" 1
fi

# 7. Cross-reference to the M027 efficiency-footer helper.
if grep -F -q 'scripts/diagnostics/efficiency-footer.sh' "$CONTRACT"; then
    check "cross-reference to scripts/diagnostics/efficiency-footer.sh present" 0
else
    check "cross-reference to scripts/diagnostics/efficiency-footer.sh present" 1
fi

printf 'SUMMARY: m029-p01-headline-shape-contract.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
