#!/usr/bin/env bash
# m033-p03-constitution-starter-format-ref-shape.sh
#
# T01 verifier: shape of references/constitution-starter-format.md
# (FR-4 / US-2 AS-4).
#
# Asserts:
#   - The reference exists.
#   - Body carries load-bearing tokens via grep -F.
#
# Bash 3.2 compatible (MEM001). Single-script invocation shape (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/references/constitution-starter-format.md"

pass=0
fail=0

if [ -f "$target" ]; then
    pass=$((pass + 1))
    echo "PASS: constitution-starter-format.md exists"
else
    fail=$((fail + 1))
    echo "FAIL: constitution-starter-format.md missing at $target" >&2
    echo "SUMMARY: m033-p03-constitution-starter-format-ref-shape.sh pass=$pass fail=$fail"
    exit 1
fi

for tok in "schema_version" "Roman-numeral" "Constitution Check" "Principle" "{{" "web-saas" "cli-tool" "library" "#Q-2"; do
    if grep -F -q -- "$tok" "$target"; then
        pass=$((pass + 1))
        echo "PASS: token present: $tok"
    else
        fail=$((fail + 1))
        echo "FAIL: token missing: $tok" >&2
    fi
done

echo "SUMMARY: m033-p03-constitution-starter-format-ref-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
