#!/usr/bin/env bash
# tools/verify/m032-p01-acceptance-shape-sc2.sh -- M032 P01 T04.
#
# Asserts the SC-2 acceptance script (tests/m032-acceptance/p01-symlink-mode.sh)
# exists, references SC-2 / FR-3 / M032_FORCE_WINDOWS / "POSIX-only in v1"
# by string, contains a `[ -L` symlink check, and exits 0 (or 77 SKIP) against
# the staged fresh-project fixture.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
SC2="$PROJECT_ROOT/tests/m032-acceptance/p01-symlink-mode.sh"

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

# 1. SC-2 script exists.
if [ -f "$SC2" ]; then
    check "SC-2 script exists at $SC2" 0
else
    check "SC-2 script exists at $SC2" 1
    printf 'SUMMARY: m032-p01-acceptance-shape-sc2.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. References SC-2.
if grep -qE 'SC-2\b' "$SC2"; then
    check "SC-2 script references 'SC-2'" 0
else
    check "SC-2 script references 'SC-2'" 1
fi

# 3. References FR-3.
if grep -qE 'FR-3\b' "$SC2"; then
    check "SC-2 script references FR-3" 0
else
    check "SC-2 script references FR-3" 1
fi

# 4. References M032_FORCE_WINDOWS.
if grep -q 'M032_FORCE_WINDOWS' "$SC2"; then
    check "SC-2 script references M032_FORCE_WINDOWS" 0
else
    check "SC-2 script references M032_FORCE_WINDOWS" 1
fi

# 5. References "POSIX-only in v1".
if grep -q 'POSIX-only in v1' "$SC2"; then
    check "SC-2 script references 'POSIX-only in v1'" 0
else
    check "SC-2 script references 'POSIX-only in v1'" 1
fi

# 6. Contains [ -L symbolic-link existence check.
if grep -qE '\[\s+-L\b' "$SC2"; then
    check "SC-2 script uses '[ -L ...' symlink check" 0
else
    check "SC-2 script uses '[ -L ...' symlink check" 1
fi

# 7. Exits 0 (or 77 SKIP) against the staged fixture.
sc2_out="$( bash "$SC2" 2>&1 )"
sc2_rc=$?
if [ "$sc2_rc" -eq 0 ] || [ "$sc2_rc" -eq 77 ]; then
    check "SC-2 script exits 0 or 77 (SKIP) against the staged fixture" 0
else
    check "SC-2 script exits 0 or 77 (SKIP) against the staged fixture (got $sc2_rc)" 1
    printf '%s\n' "$sc2_out" >&2
fi

# 8. Emits RESULT: ok or RESULT: skip line.
if printf '%s\n' "$sc2_out" | grep -qE '^RESULT: (ok|skip) p01-symlink-mode\.sh'; then
    check "SC-2 script emits RESULT: ok|skip line" 0
else
    check "SC-2 script emits RESULT: ok|skip line" 1
fi

printf 'SUMMARY: m032-p01-acceptance-shape-sc2.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
