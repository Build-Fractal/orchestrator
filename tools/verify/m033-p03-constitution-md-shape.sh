#!/usr/bin/env bash
# m033-p03-constitution-md-shape.sh
#
# T02 verifier: shape verification for `commands/constitution.md`.
#
# Asserts:
#   - File exists.
#   - YAML frontmatter contains `description:` (MEM012).
#   - Body contains the load-bearing tokens via `grep -F`.
#   - Negative grep: zero `speckit` substring matches (Principle XVI).
#
# Bash 3.2 compatible (MEM001). Single-script invocation shape (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/commands/constitution.md"

pass=0
fail=0

if [ -f "$target" ]; then
    pass=$((pass + 1))
    echo "PASS: commands/constitution.md exists"
else
    fail=$((fail + 1))
    echo "FAIL: commands/constitution.md missing at $target" >&2
    echo "SUMMARY: m033-p03-constitution-md-shape.sh pass=$pass fail=$fail"
    exit 1
fi

# YAML frontmatter description per MEM012.
if grep -E -q '^description:[[:space:]]*"' "$target"; then
    pass=$((pass + 1))
    echo "PASS: YAML frontmatter description: present"
else
    fail=$((fail + 1))
    echo "FAIL: YAML frontmatter description: missing" >&2
fi

# Load-bearing tokens (per T02 plan).
for tok in \
    "orchestrator:constitution" \
    "FR-3" \
    "constitution-author.sh" \
    "web-saas" \
    "cli-tool" \
    "library" \
    "standalone-gate.sh" \
    "Idempotent Deploys" \
    "Composable Default Exit Codes" \
    "Stable API Surface"
do
    if grep -F -q -- "$tok" "$target"; then
        pass=$((pass + 1))
        echo "PASS: token present: $tok"
    else
        fail=$((fail + 1))
        echo "FAIL: token missing: $tok" >&2
    fi
done

# Negative grep — Principle XVI: zero `speckit` substring matches
# (case-insensitive).
spk_count=0
spk_count=$(grep -ic 'speckit' "$target" || true)
if [ "$spk_count" = "0" ]; then
    pass=$((pass + 1))
    echo "PASS: zero case-insensitive speckit substring matches in commands/constitution.md"
else
    fail=$((fail + 1))
    echo "FAIL: $spk_count case-insensitive speckit substring matches in commands/constitution.md" >&2
fi

echo "SUMMARY: m033-p03-constitution-md-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
