#!/usr/bin/env bash
# m033-p04-ideation-md-shape.sh
#
# T02 verifier: shape verifier for commands/ideation.md (FR-10 doc surface).
#
# Asserts:
#   - File exists, ≥50 lines.
#   - YAML frontmatter description: field present.
#   - Title `# orchestrator:ideation` present.
#   - Load-bearing tokens present (FR-10, the 7 closed qkeys, etc.).
#
# Bash 3.2 compatible (MEM001). Single-script invocation shape (AD-19).
# PASS/FAIL/SUMMARY structured-output protocol.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/commands/ideation.md"

pass=0
fail=0

if [ -f "$target" ]; then
    pass=$((pass + 1))
    echo "PASS: commands/ideation.md exists at $target"
else
    fail=$((fail + 1))
    echo "FAIL: commands/ideation.md missing at $target" >&2
    echo "SUMMARY: m033-p04-ideation-md-shape.sh pass=$pass fail=$fail"
    exit 1
fi

# Line count assertion (≥50).
line_count=0
line_count=$(wc -l < "$target" | tr -d ' ')
if [ "$line_count" -ge 50 ]; then
    pass=$((pass + 1))
    echo "PASS: line count $line_count >= 50"
else
    fail=$((fail + 1))
    echo "FAIL: line count $line_count < 50" >&2
fi

# YAML frontmatter description: field.
if grep -E -q '^description: ' "$target"; then
    pass=$((pass + 1))
    echo "PASS: YAML frontmatter description: field present"
else
    fail=$((fail + 1))
    echo "FAIL: YAML frontmatter description: field missing" >&2
fi

# Title.
if grep -F -q '# orchestrator:ideation' "$target"; then
    pass=$((pass + 1))
    echo "PASS: title # orchestrator:ideation present"
else
    fail=$((fail + 1))
    echo "FAIL: title # orchestrator:ideation missing" >&2
fi

# Load-bearing tokens (per T02 plan).
for tok in \
    "orchestrator:ideation" \
    "FR-10" \
    "ideation.sh" \
    "problem-statement" \
    "target-user" \
    "mvp-boundary" \
    "top-user-stories" \
    "success-metric" \
    "top-risks" \
    "top-non-goals" \
    "partial-answers.yml" \
    "with-conversus-stress-test" \
    "MIT-007" \
    "ideation_completed" \
    "CON-6"
do
    if grep -F -q -- "$tok" "$target"; then
        pass=$((pass + 1))
        echo "PASS: token present: $tok"
    else
        fail=$((fail + 1))
        echo "FAIL: token missing: $tok" >&2
    fi
done

echo "SUMMARY: m033-p04-ideation-md-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
