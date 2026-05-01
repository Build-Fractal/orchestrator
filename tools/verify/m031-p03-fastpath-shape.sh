#!/usr/bin/env bash
# tools/verify/m031-p03-fastpath-shape.sh
#
# M031/P03/T01 shape verifier (project-owned, slug-bearing under
# tools/verify/) for the Tier A degenerate fast-path branch in
# scripts/intake/do-entry.sh (FR-12).
#
# Asserts:
#   1) the file contains the literal substring `build-context.sh --profile=quick`
#      (the FR-12 fast-path invocation).
#   2) the file contains the literal substring `doing:` followed somewhere
#      later by `MEMs` and `tokens` (FR-12 stderr summary line shape).
#   3) the file contains the literal substrings `mem_count` AND
#      `total_tokens` (sidecar field reads).
#   4) the file contains a function definition `run_tier_a_degenerate`.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/intake/do-entry.sh"

pass=0
fail=0

ok() {
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$1"
}
ng() {
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n' "$1"
}

# 0) File exists.
if [ -f "$target" ]; then
    ok "do-entry.sh exists at $target"
else
    ng "do-entry.sh missing at $target"
    printf 'SUMMARY: m031-p03-fastpath-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 1) build-context.sh --profile=quick invocation.
if grep -qF "build-context.sh --profile=quick" "$target"; then
    ok "build-context.sh --profile=quick invocation present"
else
    ng "build-context.sh --profile=quick invocation missing"
fi

# 2) `doing:` line shape with MEMs + tokens later in the file.
if grep -qF "doing:" "$target"; then
    ok "doing: literal present"
else
    ng "doing: literal missing"
fi
if grep -qF "MEMs" "$target"; then
    ok "MEMs literal present"
else
    ng "MEMs literal missing"
fi
if grep -qF "tokens" "$target"; then
    ok "tokens literal present"
else
    ng "tokens literal missing"
fi

# 2b) Order: `doing:` line appears before `MEMs` / `tokens` reference (sanity
# check the FR-12 line shape -- doing: <task> -- knowledge: <N> MEMs / <X> tokens).
doing_line=$(grep -n -F "doing:" "$target" | head -1 | sed 's/:.*//')
mems_line=$(grep -n -F "MEMs" "$target" | head -1 | sed 's/:.*//')
if [ -n "$doing_line" ] && [ -n "$mems_line" ]; then
    if [ "$doing_line" -le "$mems_line" ]; then
        ok "doing: literal precedes (or equals) MEMs literal line"
    else
        ng "doing: literal at line $doing_line follows MEMs literal at line $mems_line"
    fi
fi

# 3) Sidecar field reads.
if grep -qF "mem_count" "$target"; then
    ok "mem_count sidecar field read present"
else
    ng "mem_count sidecar field read missing"
fi
if grep -qF "total_tokens" "$target"; then
    ok "total_tokens sidecar field read present"
else
    ng "total_tokens sidecar field read missing"
fi

# 4) run_tier_a_degenerate function definition.
if grep -qE '^run_tier_a_degenerate[[:space:]]*\(\)' "$target"; then
    ok "run_tier_a_degenerate function definition present"
else
    ng "run_tier_a_degenerate function definition missing"
fi

printf 'SUMMARY: m031-p03-fastpath-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
