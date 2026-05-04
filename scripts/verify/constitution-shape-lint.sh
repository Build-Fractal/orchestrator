#!/usr/bin/env bash
# constitution-shape-lint.sh
#
# FR-5: shape-lint a constitution file authored by `commands/constitution.md`
# (and downstream consumers). The lint asserts the structural invariants
# T02's `constitution-author.sh` is required to produce; without these
# invariants the constitution is not load-bearing for `commands/specify.md`
# cross-references and downstream gates.
#
# Assertions:
#   1. `## Constitution Check` section header is present.
#   2. At least 6 `### Principle <Roman>` sub-headers are present (the
#      Roman-numeral convention is the canonical principle anchor).
#   3. Every `### Principle` sub-header has at least one non-empty body
#      line before the next `### Principle` header or end-of-file. An
#      empty principle is a placeholder leak — the author flow asked for
#      content and produced nothing.
#   4. Zero literal `{{` placeholder strings remain. Every `{{...}}`
#      placeholder MUST be resolved before the file is written; an
#      un-substituted placeholder is a grilling-shell failure.
#
# Bash 3.2 compatible (MEM001). Single-script invocation shape (AD-19):
# no process substitution, no `$(...)` containing pipes, no `declare -A`.
#
# Usage:
#   bash scripts/verify/constitution-shape-lint.sh <path-to-constitution.md>
#
# Exit codes:
#   0  — all assertions pass
#   1  — one or more assertions failed (FAIL: lines emitted to stderr)
#   2  — usage error (no path given, or path does not exist)
#
# Output shape:
#   PASS: <description> (one per assertion that passed)
#   FAIL: <description> (one per assertion that failed; to stderr)
#   SUMMARY: constitution-shape-lint.sh path=<path> pass=N fail=M

set -u

target="${1:-}"

if [ -z "$target" ]; then
    echo "usage: constitution-shape-lint.sh <path-to-constitution.md>" >&2
    exit 2
fi

if [ ! -f "$target" ]; then
    echo "FAIL: constitution file not found at $target" >&2
    echo "SUMMARY: constitution-shape-lint.sh path=$target pass=0 fail=1"
    exit 2
fi

pass=0
fail=0

# --- Assertion 1: ## Constitution Check section header present. ---
if grep -q '^## Constitution Check' "$target"; then
    pass=$((pass + 1))
    echo "PASS: ## Constitution Check section header present"
else
    fail=$((fail + 1))
    echo "FAIL: ## Constitution Check section header missing" >&2
fi

# --- Assertion 2: at least 6 ### Principle <Roman> sub-headers. ---
principle_count=$(grep -cE '^### Principle [IVX]+' "$target")
if [ "$principle_count" -ge 6 ]; then
    pass=$((pass + 1))
    echo "PASS: $principle_count ### Principle <Roman> sub-headers present (>= 6)"
else
    fail=$((fail + 1))
    echo "FAIL: only $principle_count ### Principle <Roman> sub-headers (need >= 6)" >&2
fi

# --- Assertion 3: every Principle sub-header has a non-empty body. ---
# State machine: when we see a `### Principle ...` header, mark in_principle
# and remember its title. On any subsequent non-empty non-header line, mark
# the current principle satisfied. On the next `### Principle` or `## ` or
# EOF, if the current principle has no body, fail.
empty_principles=""
empty_count=0
current_principle=""
current_has_body=0

while IFS= read -r line; do
    case "$line" in
        '### Principle '*)
            # Closing the previous principle (if any).
            if [ -n "$current_principle" ] && [ "$current_has_body" -eq 0 ]; then
                empty_count=$((empty_count + 1))
                empty_principles="$empty_principles $current_principle"
            fi
            current_principle="$line"
            current_has_body=0
            ;;
        '## '*)
            # Closing the current principle on a new top-level section.
            if [ -n "$current_principle" ] && [ "$current_has_body" -eq 0 ]; then
                empty_count=$((empty_count + 1))
                empty_principles="$empty_principles $current_principle"
            fi
            current_principle=""
            current_has_body=0
            ;;
        '')
            : # blank line — does not count as body
            ;;
        *)
            if [ -n "$current_principle" ]; then
                current_has_body=1
            fi
            ;;
    esac
done < "$target"

# EOF flush — close the trailing principle.
if [ -n "$current_principle" ] && [ "$current_has_body" -eq 0 ]; then
    empty_count=$((empty_count + 1))
    empty_principles="$empty_principles $current_principle"
fi

if [ "$empty_count" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS: every ### Principle sub-header has a non-empty body"
else
    fail=$((fail + 1))
    echo "FAIL: $empty_count empty principle(s):$empty_principles" >&2
fi

# --- Assertion 4: zero literal {{ placeholder strings. ---
placeholder_lines=$(grep -nF '{{' "$target")
if [ -z "$placeholder_lines" ]; then
    pass=$((pass + 1))
    echo "PASS: zero {{ placeholder strings remain"
else
    fail=$((fail + 1))
    echo "FAIL: unresolved {{ placeholder(s) at:" >&2
    echo "$placeholder_lines" >&2
fi

if [ "$fail" -eq 0 ]; then
    echo "PASS: $target shape lint passed"
fi

echo "SUMMARY: constitution-shape-lint.sh path=$target pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
