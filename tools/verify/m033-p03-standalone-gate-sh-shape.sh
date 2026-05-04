#!/usr/bin/env bash
# m033-p03-standalone-gate-sh-shape.sh
#
# T01 verifier: shape + functional smoke for
# scripts/verify/standalone-gate.sh (FR-6 / Principle XVI).
#
# Asserts:
#   - Script exists and is executable.
#   - Body contains load-bearing tokens.
#   - Fenced SSOT block markers (open + close) present.
#   - Closed surface file set enumerated inside the SSOT block.
#   - Functional smoke: `bash standalone-gate.sh constitution` exits 0
#     against the M033 working tree, emits PASS or SKIP, no FAIL.
#
# Bash 3.2 compatible (MEM001). Single-script invocation shape (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/verify/standalone-gate.sh"

pass=0
fail=0

if [ -f "$target" ]; then
    pass=$((pass + 1))
    echo "PASS: standalone-gate.sh exists at $target"
else
    fail=$((fail + 1))
    echo "FAIL: standalone-gate.sh missing at $target" >&2
    echo "SUMMARY: m033-p03-standalone-gate-sh-shape.sh pass=$pass fail=$fail"
    exit 1
fi

if [ -x "$target" ]; then
    pass=$((pass + 1))
    echo "PASS: standalone-gate.sh executable"
else
    fail=$((fail + 1))
    echo "FAIL: standalone-gate.sh not executable" >&2
fi

for tok in "constitution" "speckit" "constitution-surface-files" "PASS:" "FAIL:" "SUMMARY:"; do
    if grep -F -q -- "$tok" "$target"; then
        pass=$((pass + 1))
        echo "PASS: token present: $tok"
    else
        fail=$((fail + 1))
        echo "FAIL: token missing: $tok" >&2
    fi
done

# Fenced SSOT markers.
if grep -F -q '# >>> constitution-surface-files >>>' "$target"; then
    pass=$((pass + 1))
    echo "PASS: open marker '# >>> constitution-surface-files >>>' present"
else
    fail=$((fail + 1))
    echo "FAIL: open marker '# >>> constitution-surface-files >>>' missing" >&2
fi
if grep -F -q '# <<< constitution-surface-files <<<' "$target"; then
    pass=$((pass + 1))
    echo "PASS: close marker '# <<< constitution-surface-files <<<' present"
else
    fail=$((fail + 1))
    echo "FAIL: close marker '# <<< constitution-surface-files <<<' missing" >&2
fi

# Surface file enumeration (subset check — at least these four MUST appear).
for surface in "commands/constitution.md" "templates/constitution-starters/web-saas.md" "references/constitution-starter-format.md" "scripts/verify/constitution-shape-lint.sh"; do
    if grep -F -q -- "$surface" "$target"; then
        pass=$((pass + 1))
        echo "PASS: surface enumerated: $surface"
    else
        fail=$((fail + 1))
        echo "FAIL: surface NOT enumerated: $surface" >&2
    fi
done

# --- Functional smoke: invoke against M033 working tree. ---
smoke_out="$(mktemp 2>/dev/null || mktemp -t smoke-out)"
smoke_err="$(mktemp 2>/dev/null || mktemp -t smoke-err)"
bash "$target" constitution >"$smoke_out" 2>"$smoke_err"
smoke_rc=$?

if [ "$smoke_rc" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS: functional smoke exits 0"
else
    fail=$((fail + 1))
    echo "FAIL: functional smoke exited $smoke_rc" >&2
fi

# At T01 land time, expect either PASS (some surfaces in place) or SKIP
# (others not yet landed); FAIL must NOT appear.
if grep -F -q "PASS:" "$smoke_out"; then
    pass=$((pass + 1))
    echo "PASS: functional smoke emitted PASS: line"
else
    if grep -F -q "SKIP:" "$smoke_out"; then
        pass=$((pass + 1))
        echo "PASS: functional smoke emitted SKIP: line (partial surface tolerated)"
    else
        fail=$((fail + 1))
        echo "FAIL: functional smoke emitted neither PASS: nor SKIP:" >&2
    fi
fi

if grep -F -q "FAIL:" "$smoke_err"; then
    fail=$((fail + 1))
    echo "FAIL: functional smoke emitted FAIL: line (speckit reference detected)" >&2
else
    pass=$((pass + 1))
    echo "PASS: functional smoke emitted no FAIL: lines"
fi

rm -f "$smoke_out" "$smoke_err"

echo "SUMMARY: m033-p03-standalone-gate-sh-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
