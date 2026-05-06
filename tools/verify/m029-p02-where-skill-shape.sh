#!/usr/bin/env bash
# tools/verify/m029-p02-where-skill-shape.sh -- M029 P02 / FR-5 where-skill-shape gate verifier.
#
# Asserts commands/where.md exists, declares every required H2 section
# (canonical 8-section command-doc shape mirrored from commands/context.md),
# embeds the canonical glyph alphabet (✓ ▶ ◇ ✗ ▽), references
# render-position.sh + detect-invocation-context.sh +
# cross-milestone-feature-shape.md, declares the read-only contract token
# and the no-GitHub-API contract token, never names the M013 sidecar path
# /integrations/github, embeds the canonical compact savings form
# `▽ saved Nk` (#Q-G8) and DOES NOT carry the forbidden verbose form
# `via tier1 cache reuse`.
#
# T03 deliverable; T04 fixtures + SC-5 byte-identity acceptance assert
# behavioral conformance against the mixed-state golden render. T03's
# verifiers are SHAPE checks; T04's verifiers are BEHAVIORAL.
#
# Bash 3.2 compatible. Straight-line, no inline compound chains, no plain
# subshells, no $() with pipes (AD-19 single-script-file shape rule).

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
SKILL="$PROJECT_ROOT/commands/where.md"

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
if [ -f "$SKILL" ]; then
    check "commands/where.md exists" 0
else
    printf 'FAIL: commands/where.md missing\n'
    fail=$((fail + 1))
    printf 'SUMMARY: m029-p02-where-skill-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Required H2 sections (canonical 8-section command-doc shape).
if grep -F -q -- '## Prerequisites' "$SKILL"; then
    check "section present: ## Prerequisites" 0
else
    check "section present: ## Prerequisites" 1
fi
if grep -F -q -- '## Core Workflow' "$SKILL"; then
    check "section present: ## Core Workflow" 0
else
    check "section present: ## Core Workflow" 1
fi
if grep -F -q -- '## Glyph Legend' "$SKILL"; then
    check "section present: ## Glyph Legend" 0
else
    check "section present: ## Glyph Legend" 1
fi
if grep -F -q -- '## Flags' "$SKILL"; then
    check "section present: ## Flags" 0
else
    check "section present: ## Flags" 1
fi
if grep -F -q -- '## Output' "$SKILL"; then
    check "section present: ## Output" 0
else
    check "section present: ## Output" 1
fi
if grep -F -q -- '## Idempotency' "$SKILL"; then
    check "section present: ## Idempotency" 0
else
    check "section present: ## Idempotency" 1
fi
if grep -F -q -- '## Error Handling' "$SKILL"; then
    check "section present: ## Error Handling" 0
else
    check "section present: ## Error Handling" 1
fi
if grep -F -q -- '## Constraints' "$SKILL"; then
    check "section present: ## Constraints" 0
else
    check "section present: ## Constraints" 1
fi
if grep -F -q -- '## Referenced Scripts' "$SKILL"; then
    check "section present: ## Referenced Scripts" 0
else
    check "section present: ## Referenced Scripts" 1
fi
if grep -F -q -- '## Reference Files' "$SKILL"; then
    check "section present: ## Reference Files" 0
else
    check "section present: ## Reference Files" 1
fi

# 3. Canonical glyphs literal-present in the skill body.
if grep -F -q -- '✓' "$SKILL"; then
    check "glyph present: ✓ (complete)" 0
else
    check "glyph present: ✓ (complete)" 1
fi
if grep -F -q -- '▶' "$SKILL"; then
    check "glyph present: ▶ (executing)" 0
else
    check "glyph present: ▶ (executing)" 1
fi
if grep -F -q -- '◇' "$SKILL"; then
    check "glyph present: ◇ (pending)" 0
else
    check "glyph present: ◇ (pending)" 1
fi
if grep -F -q -- '✗' "$SKILL"; then
    check "glyph present: ✗ (failed)" 0
else
    check "glyph present: ✗ (failed)" 1
fi
if grep -F -q -- '▽' "$SKILL"; then
    check "glyph present: ▽ (savings, FR-8 / P03 --live)" 0
else
    check "glyph present: ▽ (savings, FR-8 / P03 --live)" 1
fi

# 4. Renderer + resolver + contract references.
if grep -F -q -- 'scripts/diagnostics/render-position.sh' "$SKILL"; then
    check "references scripts/diagnostics/render-position.sh" 0
else
    check "references scripts/diagnostics/render-position.sh" 1
fi
if grep -F -q -- 'scripts/state/detect-invocation-context.sh' "$SKILL"; then
    check "references scripts/state/detect-invocation-context.sh (AD-1)" 0
else
    check "references scripts/state/detect-invocation-context.sh (AD-1)" 1
fi
if grep -F -q -- 'references/cross-milestone-feature-shape.md' "$SKILL"; then
    check "references references/cross-milestone-feature-shape.md (AD-6)" 0
else
    check "references references/cross-milestone-feature-shape.md (AD-6)" 1
fi

# 5. Read-only contract token (Read-only / CON-1 / FR-14) appears.
_ro=1
if grep -F -q -- 'Read-only' "$SKILL"; then _ro=0
elif grep -F -q -- 'read-only' "$SKILL"; then _ro=0
elif grep -F -q -- 'CON-1' "$SKILL"; then _ro=0
elif grep -F -q -- 'FR-14' "$SKILL"; then _ro=0
fi
check "declares read-only contract (Read-only / CON-1 / FR-14)" "$_ro"

# 6. No-GitHub-API contract token (No GitHub API / CON-4 / FR-11) appears.
_ng=1
if grep -F -q -- 'No GitHub API' "$SKILL"; then _ng=0
elif grep -F -q -- 'no GitHub API' "$SKILL"; then _ng=0
elif grep -F -q -- 'CON-4' "$SKILL"; then _ng=0
elif grep -F -q -- 'FR-11' "$SKILL"; then _ng=0
fi
check "declares no-GitHub-API contract (No GitHub API / CON-4 / FR-11)" "$_ng"

# 7. Anti-coupling enforcement: the M013 sidecar path /integrations/github
#    MUST NOT appear anywhere in commands/where.md. Complements SC-13's
#    cross-tree anti-coupling guard.
if grep -F -q -- '/integrations/github' "$SKILL"; then
    check "anti-coupling: /integrations/github absent" 1
else
    check "anti-coupling: /integrations/github absent" 0
fi

# 8. Canonical compact savings form `▽ saved Nk` (#Q-G8) is documented.
if grep -F -q -- '▽ saved Nk' "$SKILL"; then
    check "canonical savings form '▽ saved Nk' present (#Q-G8)" 0
else
    check "canonical savings form '▽ saved Nk' present (#Q-G8)" 1
fi

# 9. Forbidden verbose savings form 'via tier1 cache reuse' is absent.
if grep -F -q -- 'via tier1 cache reuse' "$SKILL"; then
    check "forbidden verbose form 'via tier1 cache reuse' absent" 1
else
    check "forbidden verbose form 'via tier1 cache reuse' absent" 0
fi

printf 'SUMMARY: m029-p02-where-skill-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
