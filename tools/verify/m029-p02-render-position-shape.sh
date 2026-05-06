#!/usr/bin/env bash
# tools/verify/m029-p02-render-position-shape.sh -- M029 P02 / FR-5 renderer-shape gate verifier.
#
# Asserts scripts/diagnostics/render-position.sh exists, is executable,
# declares the canonical glyph alphabet (✓ ▶ ◇ ✗ ▽), declares the
# read-only contract token, declares the no-GitHub-API contract token,
# never references the M013 sidecar path /integrations/github, sources
# the AD-1 resolver (detect-invocation-context.sh), invokes
# metrics-rollup.sh + carries the FR-6 detection probe (literal
# 'dispatch_usage'), and declares Bash 3.2 / MEM001 compatibility.
#
# T03 deliverable; T04 fixtures + SC-5 byte-identity acceptance assert
# behavioral conformance against the mixed-state golden render. T03's
# verifiers are SHAPE checks; T04's verifiers are BEHAVIORAL.
#
# Bash 3.2 compatible. Straight-line, no inline compound chains, no plain
# subshells, no $() with pipes (AD-19 single-script-file shape rule for
# verifier code -- the metrics-rollup.sh MEM004 carve-out applies inside
# the renderer body, not inside this verifier).

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
RENDERER="$PROJECT_ROOT/scripts/diagnostics/render-position.sh"

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
if [ -f "$RENDERER" ]; then
    check "scripts/diagnostics/render-position.sh exists" 0
else
    printf 'FAIL: scripts/diagnostics/render-position.sh missing\n'
    fail=$((fail + 1))
    printf 'SUMMARY: m029-p02-render-position-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. File is executable.
if [ -x "$RENDERER" ]; then
    check "scripts/diagnostics/render-position.sh is executable" 0
else
    check "scripts/diagnostics/render-position.sh is executable" 1
fi

# 3. Canonical glyphs literal-present in the script body.
if grep -F -q -- '✓' "$RENDERER"; then
    check "glyph present: ✓ (complete)" 0
else
    check "glyph present: ✓ (complete)" 1
fi
if grep -F -q -- '▶' "$RENDERER"; then
    check "glyph present: ▶ (executing)" 0
else
    check "glyph present: ▶ (executing)" 1
fi
if grep -F -q -- '◇' "$RENDERER"; then
    check "glyph present: ◇ (pending)" 0
else
    check "glyph present: ◇ (pending)" 1
fi
if grep -F -q -- '✗' "$RENDERER"; then
    check "glyph present: ✗ (failed)" 0
else
    check "glyph present: ✗ (failed)" 1
fi

# 4. The ▽ savings glyph is referenced (in a comment naming P03 live-mode
#    use); the at-rest renderer never EMITS ▽, but it must DOCUMENT the
#    glyph alphabet completely.
if grep -F -q -- '▽' "$RENDERER"; then
    check "glyph referenced: ▽ (savings, P03 --live only)" 0
else
    check "glyph referenced: ▽ (savings, P03 --live only)" 1
fi

# 5. The forbidden v1 verbose-suffix form does NOT appear (#Q-G8).
if grep -F -q -- 'via tier1 cache reuse' "$RENDERER"; then
    check "forbidden verbose form 'via tier1 cache reuse' absent" 1
else
    check "forbidden verbose form 'via tier1 cache reuse' absent" 0
fi

# 6. Read-only contract token (Read-only / CON-1 / FR-14) appears.
_ro=1
if grep -F -q -- 'Read-only' "$RENDERER"; then _ro=0
elif grep -F -q -- 'CON-1' "$RENDERER"; then _ro=0
elif grep -F -q -- 'FR-14' "$RENDERER"; then _ro=0
fi
check "header declares read-only contract (Read-only / CON-1 / FR-14)" "$_ro"

# 7. No-GitHub-API contract token (No GitHub API / CON-4 / FR-11) appears.
_ng=1
if grep -F -q -- 'No GitHub API' "$RENDERER"; then _ng=0
elif grep -F -q -- 'CON-4' "$RENDERER"; then _ng=0
elif grep -F -q -- 'FR-11' "$RENDERER"; then _ng=0
fi
check "header declares no-GitHub-API contract (No GitHub API / CON-4 / FR-11)" "$_ng"

# 8. Anti-coupling enforcement: the M013 sidecar path /integrations/github
#    MUST NOT appear anywhere in the renderer body. Complements SC-13's
#    cross-tree anti-coupling guard.
if grep -F -q -- '/integrations/github' "$RENDERER"; then
    check "anti-coupling: /integrations/github absent" 1
else
    check "anti-coupling: /integrations/github absent" 0
fi

# 9. Renderer invokes the AD-1 resolver detect-invocation-context.sh.
if grep -F -q -- 'detect-invocation-context.sh' "$RENDERER"; then
    check "invokes AD-1 resolver: detect-invocation-context.sh" 0
else
    check "invokes AD-1 resolver: detect-invocation-context.sh" 1
fi

# 10. Renderer invokes the M027 cost-column source metrics-rollup.sh.
if grep -F -q -- 'metrics-rollup.sh' "$RENDERER"; then
    check "invokes M027 cost source: metrics-rollup.sh" 0
else
    check "invokes M027 cost source: metrics-rollup.sh" 1
fi

# 11. FR-6 detection probe: the literal 'dispatch_usage' token appears
#     (as the M019 Tier 1 record-type probe used to gate the cost column).
if grep -F -q -- 'dispatch_usage' "$RENDERER"; then
    check "FR-6 detection probe: literal 'dispatch_usage' present" 0
else
    check "FR-6 detection probe: literal 'dispatch_usage' present" 1
fi

# 12. Bash 3.2 compatibility token (Bash 3.2 / MEM001) appears.
_b32=1
if grep -F -q -- 'Bash 3.2' "$RENDERER"; then _b32=0
elif grep -F -q -- 'MEM001' "$RENDERER"; then _b32=0
fi
check "header declares bash 3.2 compatibility (Bash 3.2 / MEM001)" "$_b32"

# 13. AD-6 cross-milestone schema reference is present in the header.
if grep -F -q -- 'AD-6' "$RENDERER"; then
    check "header references AD-6 cross-milestone data model" 0
else
    check "header references AD-6 cross-milestone data model" 1
fi

# 14. Renderer's --milestone / --expand-all / --no-cost / --root flags are
#     parsed (basic CLI surface presence check).
if grep -F -q -- '--milestone' "$RENDERER"; then
    check "flag documented: --milestone" 0
else
    check "flag documented: --milestone" 1
fi
if grep -F -q -- '--expand-all' "$RENDERER"; then
    check "flag documented: --expand-all" 0
else
    check "flag documented: --expand-all" 1
fi
if grep -F -q -- '--no-cost' "$RENDERER"; then
    check "flag documented: --no-cost" 0
else
    check "flag documented: --no-cost" 1
fi
if grep -F -q -- '--root' "$RENDERER"; then
    check "flag documented: --root" 0
else
    check "flag documented: --root" 1
fi

printf 'SUMMARY: m029-p02-render-position-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
