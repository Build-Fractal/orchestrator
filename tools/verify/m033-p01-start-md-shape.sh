#!/usr/bin/env bash
# m033-p01-start-md-shape.sh
#
# T03 verifier: asserts commands/start.md exists in the canonical
# command-document shape (MEM012) and embeds the load-bearing tokens
# the FR-1 / FR-2 contract requires.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/commands/start.md"

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
    echo "FAIL: commands/start.md missing at $target"
    echo "SUMMARY: m033-p01-start-md-shape.sh pass=0 fail=1"
    exit 1
fi
check_pass "commands/start.md exists"

# Frontmatter: description: line that mentions orchestrator:start.
desc_line=$(grep -m1 '^description:' "$target" 2>/dev/null || true)
if [ -n "$desc_line" ]; then
    check_pass "frontmatter description: line present"
else
    check_fail "frontmatter description: line missing"
fi

if printf '%s\n' "$desc_line" | grep -qF 'orchestrator:start'; then
    check_pass "description: advertises orchestrator:start"
else
    check_fail "description: missing literal 'orchestrator:start' token"
fi

# Required content tokens.
required_tokens=(
    'orchestrator:start'
    'warm conversational front door'
    'scripts/lifecycle/start.sh'
    'references/branch-detection.md'
    'init-project.sh'
)
for tok in "${required_tokens[@]}"; do
    if grep -qF -- "$tok" "$target"; then
        check_pass "token present: '$tok'"
    else
        check_fail "token missing: '$tok'"
    fi
done

# Required MEM012 sections.
required_sections=(
    '## Prerequisites'
    '## Core Workflow'
    '## Output'
    '## Idempotency'
    '## Error Handling'
    '## Referenced Scripts'
)
for sec in "${required_sections[@]}"; do
    if grep -qF -- "$sec" "$target"; then
        check_pass "section present: '$sec'"
    else
        check_fail "section missing: '$sec'"
    fi
done

echo "SUMMARY: m033-p01-start-md-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
