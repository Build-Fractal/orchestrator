#!/usr/bin/env bash
# m033-p03-constitution-shape-lint-shape.sh
#
# T01 verifier: shape + functional smoke test for
# scripts/verify/constitution-shape-lint.sh (FR-5).
#
# Asserts:
#   - Script exists and is executable.
#   - Script body contains load-bearing tokens.
#   - Positive smoke test: a valid fixture exits 0 + emits PASS.
#   - Negative smoke test: a {{ leak fixture exits non-zero + emits
#     line numbers to stderr.
#
# Bash 3.2 compatible (MEM001). Single-script invocation shape (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/verify/constitution-shape-lint.sh"

pass=0
fail=0

if [ -f "$target" ]; then
    pass=$((pass + 1))
    echo "PASS: constitution-shape-lint.sh exists at $target"
else
    fail=$((fail + 1))
    echo "FAIL: constitution-shape-lint.sh missing at $target" >&2
    echo "SUMMARY: m033-p03-constitution-shape-lint-shape.sh pass=$pass fail=$fail"
    exit 1
fi

if [ -x "$target" ]; then
    pass=$((pass + 1))
    echo "PASS: constitution-shape-lint.sh executable"
else
    fail=$((fail + 1))
    echo "FAIL: constitution-shape-lint.sh not executable" >&2
fi

for tok in "Constitution Check" "Principle" "{{" "PASS:" "FAIL:" "SUMMARY:"; do
    if grep -F -q -- "$tok" "$target"; then
        pass=$((pass + 1))
        echo "PASS: token present: $tok"
    else
        fail=$((fail + 1))
        echo "FAIL: token missing: $tok" >&2
    fi
done

# --- Positive smoke test: valid fixture exits 0. ---
stage="$(mktemp -d 2>/dev/null || mktemp -d -t shape-lint)"
positive="$stage/positive.md"
cat > "$positive" <<'POS_EOF'
# Constitution — Test Project

## Constitution Check

Every plan and review references this section.

## Core Principles

### Principle I. Context Minimization

Body line one for I. Real prose, not a placeholder.

### Principle II. Evidence Before Claims

Body line one for II. Real prose, not a placeholder.

### Principle III. Design Before Code

Body line one for III.

### Principle IV. Plans Assume Zero Context

Body line one for IV.

### Principle V. State On Disk Is Truth

Body line one for V.

### Principle VI. Knowledge Compounds

Body line one for VI.
POS_EOF

positive_out="$stage/positive.out"
positive_err="$stage/positive.err"
bash "$target" "$positive" >"$positive_out" 2>"$positive_err"
positive_rc=$?

if [ "$positive_rc" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS: positive smoke test exits 0"
else
    fail=$((fail + 1))
    echo "FAIL: positive smoke test exited $positive_rc" >&2
fi

if grep -F -q "PASS:" "$positive_out"; then
    pass=$((pass + 1))
    echo "PASS: positive smoke test emitted PASS: line"
else
    fail=$((fail + 1))
    echo "FAIL: positive smoke test missing PASS: line" >&2
fi

# --- Negative smoke test: {{ leak fixture exits non-zero. ---
negative="$stage/negative.md"
cat > "$negative" <<'NEG_EOF'
# Constitution — Test Project

## Constitution Check

Every plan and review references this section.

## Core Principles

### Principle I. Context Minimization

Body line referencing {{unresolved_placeholder}} which must trigger fail.

### Principle II. Evidence Before Claims

Body line one for II.

### Principle III. Design Before Code

Body line one for III.

### Principle IV. Plans Assume Zero Context

Body line one for IV.

### Principle V. State On Disk Is Truth

Body line one for V.

### Principle VI. Knowledge Compounds

Body line one for VI.
NEG_EOF

negative_out="$stage/negative.out"
negative_err="$stage/negative.err"
bash "$target" "$negative" >"$negative_out" 2>"$negative_err"
negative_rc=$?

if [ "$negative_rc" -ne 0 ]; then
    pass=$((pass + 1))
    echo "PASS: negative smoke test exits non-zero"
else
    fail=$((fail + 1))
    echo "FAIL: negative smoke test exited 0 (expected non-zero)" >&2
fi

if grep -F -q "{{" "$negative_err"; then
    pass=$((pass + 1))
    echo "PASS: negative smoke test echoed {{ line numbers to stderr"
else
    fail=$((fail + 1))
    echo "FAIL: negative smoke test missing {{ in stderr" >&2
fi

# Cleanup.
rm -rf "$stage"

echo "SUMMARY: m033-p03-constitution-shape-lint-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
