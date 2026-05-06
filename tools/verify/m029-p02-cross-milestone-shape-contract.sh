#!/usr/bin/env bash
# tools/verify/m029-p02-cross-milestone-shape-contract.sh -- M029 P02 FR-13 / AD-6 / #Q-5 / #Q-G8 gate verifier.
#
# Asserts references/cross-milestone-feature-shape.md exists and
# carries the canonical Principle III design contract sections, the
# AD-6 frontmatter schema rule (exactly-one-of), the reverse-lookup
# advisory, the #Q-5 inactive-render shape, and the #Q-G8 canonical
# `▽ saved Nk` marker form. T03 (render-position.sh), T04 (mixed-
# state golden fixtures), and T05 (phase-suite gate 1) all consume
# this contract; this verifier ensures the contract cannot drift
# silently.
#
# Bash 3.2 compatible. Straight-line, no inline compound chains, no
# plain subshells, no $() with pipes. Each grep -F is a separate
# invocation; pass/fail tracked via simple counters (MEM001 / MEM002).

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
CONTRACT="$PROJECT_ROOT/references/cross-milestone-feature-shape.md"

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
    check "references/cross-milestone-feature-shape.md exists" 0
else
    printf 'FAIL: references/cross-milestone-feature-shape.md missing\n'
    fail=$((fail + 1))
    printf 'SUMMARY: m029-p02-cross-milestone-shape-contract.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Required H1 + H2 headers present.
for header in \
    '# Cross-Milestone Feature Shape' \
    '## Purpose' \
    '## Frontmatter Schema' \
    '## Reverse-Lookup Advisory Validation' \
    '## Inactive Milestone Render Shape' \
    '## Marker Glyph Set' \
    '## Cross-References' ; do
    if grep -F -q -- "$header" "$CONTRACT"; then
        check "header present: $header" 0
    else
        check "header present: $header" 1
    fi
done

# 3. Schema literal tokens appear.
for token in 'milestone:' 'milestones:' 'M###' 'feature_ref' ; do
    if grep -F -q -- "$token" "$CONTRACT"; then
        check "schema token present: $token" 0
    else
        check "schema token present: $token" 1
    fi
done

# 4. Canonical glyphs appear literally.
for glyph in '✓' '▶' '◇' '✗' '▽' ; do
    if grep -F -q -- "$glyph" "$CONTRACT"; then
        check "glyph present: $glyph" 0
    else
        check "glyph present: $glyph" 1
    fi
done

# 5. Canonical compact savings form `saved Nk` is present.
if grep -F -q -- 'saved Nk' "$CONTRACT"; then
    check "canonical compact savings form present: saved Nk" 0
else
    check "canonical compact savings form present: saved Nk" 1
fi

# 6. Forbidden verbose savings form must NOT appear.
if grep -F -q -- 'via tier1 cache reuse' "$CONTRACT"; then
    check "forbidden verbose savings form absent: via tier1 cache reuse" 1
else
    check "forbidden verbose savings form absent: via tier1 cache reuse" 0
fi

# 7. Spec/decision references present.
for ref in 'AD-6' 'FR-13' '#Q-5' '#Q-G8' ; do
    if grep -F -q -- "$ref" "$CONTRACT"; then
        check "reference present: $ref" 0
    else
        check "reference present: $ref" 1
    fi
done

# 8. The --expand-all flag is named.
if grep -F -q -- '--expand-all' "$CONTRACT"; then
    check "flag named: --expand-all" 0
else
    check "flag named: --expand-all" 1
fi

# 9. The WARN: advisory token is documented.
if grep -F -q -- 'WARN:' "$CONTRACT"; then
    check "advisory token documented: WARN:" 0
else
    check "advisory token documented: WARN:" 1
fi

# 10. Cross-references to the named consumers.
for consumer in \
    'commands/where.md' \
    'scripts/diagnostics/render-position.sh' \
    'scripts/diagnostics/summarize-milestone.sh' \
    'scripts/state/find-active-milestone.sh' ; do
    if grep -F -q -- "$consumer" "$CONTRACT"; then
        check "cross-reference present: $consumer" 0
    else
        check "cross-reference present: $consumer" 1
    fi
done

printf 'SUMMARY: m029-p02-cross-milestone-shape-contract.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
