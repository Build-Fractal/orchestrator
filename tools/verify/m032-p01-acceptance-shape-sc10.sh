#!/usr/bin/env bash
# tools/verify/m032-p01-acceptance-shape-sc10.sh -- M032 P01 T04.
#
# Asserts the SC-10 acceptance script
# (tests/m032-acceptance/p01-staged-dirs-collision.sh) exists, references
# SC-10 / FR-22 / MIT-006 / `staged-dirs-collision:` by string, exercises
# all three FR-22 oracle branches (no-collision / bootstrapping /
# operator-owned), and exits 0 against the staged fixtures.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
SC10="$PROJECT_ROOT/tests/m032-acceptance/p01-staged-dirs-collision.sh"

pass=0
fail=0

check() {
    desc="$1"
    rc="$2"
    if [ "$rc" -eq 0 ]; then
        printf 'PASS: %s\n' "$desc"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s\n' "$desc"
        fail=$((fail + 1))
    fi
}

# 1. SC-10 script exists.
if [ -f "$SC10" ]; then
    check "SC-10 script exists at $SC10" 0
else
    check "SC-10 script exists at $SC10" 1
    printf 'SUMMARY: m032-p01-acceptance-shape-sc10.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. References SC-10.
if grep -qE 'SC-10\b' "$SC10"; then
    check "SC-10 script references 'SC-10'" 0
else
    check "SC-10 script references 'SC-10'" 1
fi

# 3. References FR-22.
if grep -qE 'FR-22\b' "$SC10"; then
    check "SC-10 script references FR-22" 0
else
    check "SC-10 script references FR-22" 1
fi

# 4. References MIT-006.
if grep -q 'MIT-006' "$SC10"; then
    check "SC-10 script references MIT-006" 0
else
    check "SC-10 script references MIT-006" 1
fi

# 5. References `staged-dirs-collision:`.
if grep -q 'staged-dirs-collision:' "$SC10"; then
    check "SC-10 script references 'staged-dirs-collision:' diagnostic" 0
else
    check "SC-10 script references 'staged-dirs-collision:' diagnostic" 1
fi

# 6. Exercises all three oracle branches by name.
for branch in '(no-collision|clean)' 'bootstrapping' 'operator-owned'; do
    if grep -qE "$branch" "$SC10"; then
        check "SC-10 script names oracle branch: $branch" 0
    else
        check "SC-10 script names oracle branch: $branch" 1
    fi
done

# 7. Exits 0 against the staged fixtures.
sc10_out="$( bash "$SC10" 2>&1 )"
sc10_rc=$?
if [ "$sc10_rc" -eq 0 ]; then
    check "SC-10 script exits 0 against the staged fixtures" 0
else
    check "SC-10 script exits 0 against the staged fixtures (got $sc10_rc)" 1
    printf '%s\n' "$sc10_out" >&2
fi

# 8. Emits RESULT: ok line.
if printf '%s\n' "$sc10_out" | grep -qE '^RESULT: ok p01-staged-dirs-collision\.sh$'; then
    check "SC-10 script emits RESULT: ok line" 0
else
    check "SC-10 script emits RESULT: ok line" 1
fi

printf 'SUMMARY: m032-p01-acceptance-shape-sc10.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
