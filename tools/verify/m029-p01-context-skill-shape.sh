#!/usr/bin/env bash
# tools/verify/m029-p01-context-skill-shape.sh -- M029 P01 FR-4 / SC-4 gate verifier.
#
# Asserts commands/context.md exists and carries the canonical
# command-document shape required by FR-4: YAML frontmatter description,
# H1 (`# orchestrator:context`), all required H2 sections, every
# documented field label, the SC-4 single-screen tokens, and references
# to the resolver + composed scripts + companion design contracts.
#
# T05's orchestrator:context skill reads from this contract; this
# verifier ensures the skill cannot drift silently.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOC="$PROJECT_ROOT/commands/context.md"

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
if [ -f "$DOC" ]; then
    check "commands/context.md exists" 0
else
    printf 'FAIL: commands/context.md missing\n'
    fail=$((fail + 1))
    printf 'SUMMARY: m029-p01-context-skill-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. YAML frontmatter description: present.
if grep -E -q '^description:[[:space:]]*"' "$DOC"; then
    check "YAML frontmatter description: present" 0
else
    check "YAML frontmatter description: present" 1
fi

# 3. H1 present: # orchestrator:context.
if grep -F -q -- '# orchestrator:context' "$DOC"; then
    check "H1 present: # orchestrator:context" 0
else
    check "H1 present: # orchestrator:context" 1
fi

# 4. Required H2 sections present.
for header in \
    '## Output Format' \
    '## Single-Screen Constraint' \
    '## Resolution' \
    '## AD-1 Single-Resolve' \
    '## Read-Only Discipline' \
    '## Idempotency' \
    '## Error Handling' \
    '## Reference Files' ; do
    if grep -F -q -- "$header" "$DOC"; then
        check "header present: $header" 0
    else
        check "header present: $header" 1
    fi
done

# 5. Documented field labels appear (verbatim).
for label in \
    'resolved root:' \
    'runtime:' \
    'capability profile:' \
    'intensity defaults:' \
    'active milestone:' \
    'lock state:' ; do
    if grep -F -q -- "$label" "$DOC"; then
        check "field label present: '$label'" 0
    else
        check "field label present: '$label'" 1
    fi
done

# 6. FR-4 reference present.
if grep -F -q -- 'FR-4' "$DOC"; then
    check "spec reference present: FR-4" 0
else
    check "spec reference present: FR-4" 1
fi

# 7. SC-4 single-screen literal tokens.
if grep -F -q -- 'single-screen' "$DOC" || grep -F -q -- 'single screen' "$DOC"; then
    check "literal token present: single-screen / single screen" 0
else
    check "literal token present: single-screen / single screen" 1
fi

if grep -F -q -- '≤24' "$DOC"; then
    check "literal token present: ≤24" 0
else
    check "literal token present: ≤24" 1
fi

# 8. Composed-script references.
for ref in \
    'scripts/state/detect-invocation-context.sh' \
    'scripts/state/resolve-root.sh' \
    'scripts/state/find-active-milestone.sh' \
    'references/status-headline-shape.md' \
    'references/status-json-schema.md' ; do
    if grep -F -q -- "$ref" "$DOC"; then
        check "reference present: $ref" 0
    else
        check "reference present: $ref" 1
    fi
done

printf 'SUMMARY: m029-p01-context-skill-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
