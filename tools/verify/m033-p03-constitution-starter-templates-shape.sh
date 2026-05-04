#!/usr/bin/env bash
# m033-p03-constitution-starter-templates-shape.sh
#
# T01 verifier: shape of templates/constitution-starters/{web-saas,
# cli-tool,library}.md (FR-4).
#
# For each starter, asserts:
#   - File exists and is non-empty.
#   - Frontmatter contains schema_version: "1.0", type: constitution-starter,
#     and the matching stack: <name>.
#   - Body contains ## Constitution Check, >=6 ### Principle <Roman>
#     sub-headers, the stack-specific tokens, and the placeholder
#     vocabulary.
#
# Bash 3.2 compatible (MEM001). Single-script invocation shape (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

# Per-stack: stack name, file path, stack-specific signature token.
check_starter() {
    stack="$1"
    starter_path="$2"
    signature_token="$3"

    if [ ! -f "$starter_path" ]; then
        fail=$((fail + 1))
        echo "FAIL: $stack starter missing at $starter_path" >&2
        return
    fi
    pass=$((pass + 1))
    echo "PASS: $stack starter exists"

    if [ -s "$starter_path" ]; then
        pass=$((pass + 1))
        echo "PASS: $stack starter non-empty"
    else
        fail=$((fail + 1))
        echo "FAIL: $stack starter empty" >&2
        return
    fi

    # Frontmatter assertions.
    if grep -F -q 'schema_version: "1.0"' "$starter_path"; then
        pass=$((pass + 1))
        echo "PASS: $stack frontmatter schema_version: \"1.0\""
    else
        fail=$((fail + 1))
        echo "FAIL: $stack frontmatter schema_version: \"1.0\" missing" >&2
    fi

    if grep -F -q 'type: constitution-starter' "$starter_path"; then
        pass=$((pass + 1))
        echo "PASS: $stack frontmatter type: constitution-starter"
    else
        fail=$((fail + 1))
        echo "FAIL: $stack frontmatter type: constitution-starter missing" >&2
    fi

    if grep -F -q "stack: $stack" "$starter_path"; then
        pass=$((pass + 1))
        echo "PASS: $stack frontmatter stack: $stack"
    else
        fail=$((fail + 1))
        echo "FAIL: $stack frontmatter stack: $stack missing" >&2
    fi

    # Body assertions.
    if grep -q '^## Constitution Check' "$starter_path"; then
        pass=$((pass + 1))
        echo "PASS: $stack ## Constitution Check section header"
    else
        fail=$((fail + 1))
        echo "FAIL: $stack ## Constitution Check section header missing" >&2
    fi

    principle_count=$(grep -cE '^### Principle [IVX]+' "$starter_path")
    if [ "$principle_count" -ge 6 ]; then
        pass=$((pass + 1))
        echo "PASS: $stack has $principle_count principle sub-headers (>= 6)"
    else
        fail=$((fail + 1))
        echo "FAIL: $stack has only $principle_count principle sub-headers (need >= 6)" >&2
    fi

    if grep -F -q -- "$signature_token" "$starter_path"; then
        pass=$((pass + 1))
        echo "PASS: $stack stack-specific token present: $signature_token"
    else
        fail=$((fail + 1))
        echo "FAIL: $stack stack-specific token missing: $signature_token" >&2
    fi

    for placeholder in "{{project_type}}" "{{primary_constraint}}" "{{target_user}}"; do
        if grep -F -q -- "$placeholder" "$starter_path"; then
            pass=$((pass + 1))
            echo "PASS: $stack placeholder present: $placeholder"
        else
            fail=$((fail + 1))
            echo "FAIL: $stack placeholder missing: $placeholder" >&2
        fi
    done
}

check_starter "web-saas" "$PROJECT_ROOT/templates/constitution-starters/web-saas.md" "Idempotent Deploys"
check_starter "cli-tool" "$PROJECT_ROOT/templates/constitution-starters/cli-tool.md" "Composable Default Exit Codes"
check_starter "library" "$PROJECT_ROOT/templates/constitution-starters/library.md" "Stable API Surface"

echo "SUMMARY: m033-p03-constitution-starter-templates-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
