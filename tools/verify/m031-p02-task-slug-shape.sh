#!/usr/bin/env bash
# m031-p02-task-slug-shape.sh
#
# Verifier for M031/P02/T02: asserts that scripts/intake/lib/task-slug.sh
# exists, contains the required literal substrings, sources cleanly,
# exposes a callable `derive_task_slug` function, and that the function
# returns AD-10-shaped slugs against representative inputs.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no process
# substitution. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m031-p02-task-slug-shape.sh
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

slug_lib="$PROJECT_ROOT/scripts/intake/lib/task-slug.sh"

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

# Check 1: task-slug.sh exists.
if [ ! -f "$slug_lib" ]; then
    echo "FAIL: task-slug.sh missing at $slug_lib"
    echo "SUMMARY: m031-p02-task-slug-shape.sh pass=0 fail=1"
    exit 1
fi
check_pass "task-slug.sh exists at $slug_lib"

# Check 2: file is non-empty.
if [ -s "$slug_lib" ]; then
    check_pass "task-slug.sh is non-empty"
else
    check_fail "task-slug.sh is empty"
fi

# Check 3: literal substring derive_task_slug present.
if grep -q 'derive_task_slug' "$slug_lib"; then
    check_pass "task-slug.sh contains literal derive_task_slug"
else
    check_fail "task-slug.sh missing literal derive_task_slug"
fi

# Check 4: literal substring sha1 present.
if grep -q 'sha1' "$slug_lib"; then
    check_pass "task-slug.sh contains literal sha1"
else
    check_fail "task-slug.sh missing literal sha1"
fi

# Check 5: literal substring 40 present (truncation length).
if grep -q '40' "$slug_lib"; then
    check_pass "task-slug.sh contains literal 40"
else
    check_fail "task-slug.sh missing literal 40"
fi

# Check 6: sourcing the file produces no stderr output.
src_stderr="/tmp/m031-p02-t02-source-stderr.txt"
rm -f "$src_stderr"
( . "$slug_lib" ) 2> "$src_stderr"
if [ -s "$src_stderr" ]; then
    check_fail "sourcing task-slug.sh produced stderr output (see $src_stderr)"
else
    check_pass "sourcing task-slug.sh produced no stderr output"
fi
rm -f "$src_stderr"

# Check 7: derive_task_slug against a normal description returns a slug
# composed of [a-z0-9-] characters only and <= 40 characters.
slug_out_normal="/tmp/m031-p02-t02-slug-normal.txt"
rm -f "$slug_out_normal"
( . "$slug_lib"; derive_task_slug "Add a flag to script X with three tests" ) > "$slug_out_normal" 2>/dev/null
slug_normal=$(cat "$slug_out_normal")
slug_normal_len=${#slug_normal}
if [ -z "$slug_normal" ]; then
    check_fail "derive_task_slug normal-input returned empty"
elif [ "$slug_normal_len" -gt 40 ]; then
    check_fail "derive_task_slug normal-input slug length $slug_normal_len > 40"
elif printf '%s' "$slug_normal" | grep -qE '^[a-z0-9-]+$'; then
    check_pass "derive_task_slug normal-input returns [a-z0-9-]+ slug (<= 40 chars): $slug_normal"
else
    check_fail "derive_task_slug normal-input slug contains disallowed chars: $slug_normal"
fi
rm -f "$slug_out_normal"

# Check 8: derive_task_slug against an empty input returns a non-empty
# fallback slug.
slug_out_empty="/tmp/m031-p02-t02-slug-empty.txt"
rm -f "$slug_out_empty"
( . "$slug_lib"; derive_task_slug "" ) > "$slug_out_empty" 2>/dev/null
slug_empty=$(cat "$slug_out_empty")
if [ -n "$slug_empty" ]; then
    check_pass "derive_task_slug empty-input returns non-empty fallback: $slug_empty"
else
    check_fail "derive_task_slug empty-input returned empty"
fi
rm -f "$slug_out_empty"

# Check 9: long input gets truncated to <= 40 characters.
slug_out_long="/tmp/m031-p02-t02-slug-long.txt"
rm -f "$slug_out_long"
( . "$slug_lib"; derive_task_slug "This is a deliberately verbose feature request with many words to test that the forty character truncation actually fires" ) > "$slug_out_long" 2>/dev/null
slug_long=$(cat "$slug_out_long")
slug_long_len=${#slug_long}
if [ "$slug_long_len" -gt 0 ] && [ "$slug_long_len" -le 40 ]; then
    check_pass "derive_task_slug long-input truncates to $slug_long_len <= 40 chars: $slug_long"
else
    check_fail "derive_task_slug long-input length $slug_long_len out of range (1..40)"
fi
rm -f "$slug_out_long"

# Check 10: determinism. Calling twice on the same input yields the
# same slug (collision discipline only fires when an unrelated
# research.md exists on disk under <base-slug>; the verifier asserts
# the no-collision happy path here).
slug_out_a="/tmp/m031-p02-t02-slug-det-a.txt"
slug_out_b="/tmp/m031-p02-t02-slug-det-b.txt"
rm -f "$slug_out_a" "$slug_out_b"
( . "$slug_lib"; derive_task_slug "Deterministic check input" ) > "$slug_out_a" 2>/dev/null
( . "$slug_lib"; derive_task_slug "Deterministic check input" ) > "$slug_out_b" 2>/dev/null
slug_a=$(cat "$slug_out_a")
slug_b=$(cat "$slug_out_b")
if [ -n "$slug_a" ] && [ "$slug_a" = "$slug_b" ]; then
    check_pass "derive_task_slug deterministic on repeated input: $slug_a"
else
    check_fail "derive_task_slug NOT deterministic: a=$slug_a b=$slug_b"
fi
rm -f "$slug_out_a" "$slug_out_b"

echo "SUMMARY: m031-p02-task-slug-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
