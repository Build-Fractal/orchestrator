#!/usr/bin/env bash
# tools/verify/m029-p01-json-schema-contract.sh -- M029 P01 FR-3 / SC-3 gate verifier.
#
# Asserts references/status-json-schema.md exists and carries the
# canonical Principle III design contract sections, schema_version
# "1.0", every required top-level key, the AD-2 degraded-state keys,
# and the AD-7 / AD-2 / FR-3 / SC-3 spec references. T04's JSON
# renderer reads this contract; this verifier ensures the contract
# cannot drift silently.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
CONTRACT="$PROJECT_ROOT/references/status-json-schema.md"

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
    check "references/status-json-schema.md exists" 0
else
    printf 'FAIL: references/status-json-schema.md missing\n'
    fail=$((fail + 1))
    printf 'SUMMARY: m029-p01-json-schema-contract.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Required H1 + H2 headers present.
for header in \
    '# Status JSON Schema' \
    '## schema_version' \
    '## Top-Level Keys' \
    '## sections' \
    '## Edge Cases' \
    '## ANSI Strip Primitive' \
    '## Versioning Policy' \
    '## Cross-References' ; do
    if grep -F -q -- "$header" "$CONTRACT"; then
        check "header present: $header" 0
    else
        check "header present: $header" 1
    fi
done

# 3. schema_version declared as "1.0" (both literal "1.0" and the
# field name schema_version must appear).
if grep -F -q 'schema_version' "$CONTRACT"; then
    check "schema_version field name present" 0
else
    check "schema_version field name present" 1
fi
if grep -F -q '"1.0"' "$CONTRACT"; then
    check 'schema_version literal "1.0" present' 0
else
    check 'schema_version literal "1.0" present' 1
fi

# 4. Every required top-level key name appears literally.
for key in \
    schema_version \
    milestone_id \
    milestone_name \
    phase_index \
    phase_count \
    phase_percent_complete \
    lock_state \
    last_dispatch_recency \
    last_verify_result \
    sections ; do
    if grep -F -q -- "$key" "$CONTRACT"; then
        check "top-level key present: $key" 0
    else
        check "top-level key present: $key" 1
    fi
done

# 5. AD-2 degraded-state keys (state, parse_errors) appear.
if grep -F -q 'state' "$CONTRACT"; then
    check "degraded-state key present: state" 0
else
    check "degraded-state key present: state" 1
fi
if grep -F -q 'parse_errors' "$CONTRACT"; then
    check "degraded-state key present: parse_errors" 0
else
    check "degraded-state key present: parse_errors" 1
fi
if grep -F -q '"degraded"' "$CONTRACT"; then
    check 'degraded-state literal "degraded" present' 0
else
    check 'degraded-state literal "degraded" present' 1
fi

# 6. Spec references appear (AD-7 / AD-2 / FR-3 / SC-3).
for ref in AD-7 AD-2 FR-3 SC-3; do
    if grep -F -q -- "$ref" "$CONTRACT"; then
        check "spec reference present: $ref" 0
    else
        check "spec reference present: $ref" 1
    fi
done

# 7. Cross-reference to the headline-shape companion contract.
if grep -F -q 'references/status-headline-shape.md' "$CONTRACT"; then
    check "cross-reference to references/status-headline-shape.md present" 0
else
    check "cross-reference to references/status-headline-shape.md present" 1
fi

# 8. Cross-reference to the renderer script.
if grep -F -q 'scripts/diagnostics/render-status-json.sh' "$CONTRACT"; then
    check "cross-reference to scripts/diagnostics/render-status-json.sh present" 0
else
    check "cross-reference to scripts/diagnostics/render-status-json.sh present" 1
fi

# 9. ANSI strip primitive regex documented.
if grep -F -q '[mGKHF]' "$CONTRACT"; then
    check "ANSI strip primitive regex documented (CSI terminator class)" 0
else
    check "ANSI strip primitive regex documented (CSI terminator class)" 1
fi

printf 'SUMMARY: m029-p01-json-schema-contract.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
