#!/usr/bin/env bash
# tools/verify/m035-p00-npm-collision-evidence.sh -- M035 P00 T04 shape verifier.
#
# Asserts packaging/bundle/D-RN-1-evidence.txt records the npm-name
# collision-check outcome for D-RN-1 (rename-plan resolution
# `@build-fractal/orchestrator`).
#
# Bash 3.2 compatible.
#
# Exit:
#   0  PASS
#   1  FAIL

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

EVIDENCE="$REPO_ROOT/packaging/bundle/D-RN-1-evidence.txt"

pass=0
fail=0
failures=""

check_pass() {
    pass=$((pass + 1))
    printf '  ok: %s\n' "$1"
}

check_fail() {
    fail=$((fail + 1))
    failures="${failures}    - ${1}\n"
    printf '  FAIL: %s\n' "$1"
}

printf '=== m035-p00-npm-collision-evidence (T04 / D-RN-1 evidence) ===\n'
printf 'evidence=%s\n' "$EVIDENCE"
printf '\n'

if [ -f "$EVIDENCE" ]; then
    check_pass "evidence file exists: packaging/bundle/D-RN-1-evidence.txt"
else
    check_fail "evidence file missing: packaging/bundle/D-RN-1-evidence.txt"
    printf 'FAIL: m035-p00-npm-collision-evidence (pass=%d fail=%d)\n' "$pass" "$fail"
    exit 1
fi

if grep -q 'D-RN-1' "$EVIDENCE"; then
    check_pass "evidence carries D-RN-1 marker"
else
    check_fail "evidence missing D-RN-1 marker"
fi

if grep -q '@build-fractal/orchestrator' "$EVIDENCE"; then
    check_pass "evidence carries @build-fractal/orchestrator resolution"
else
    check_fail "evidence missing @build-fractal/orchestrator resolution"
fi

if grep -q '^Resolution:' "$EVIDENCE"; then
    check_pass "evidence carries Resolution: line"
else
    check_fail "evidence missing Resolution: line"
fi

if grep -q '^Captured at:' "$EVIDENCE"; then
    check_pass "evidence carries Captured at: line"
else
    check_fail "evidence missing Captured at: line"
fi

# Length check: >= 8 lines.
nlines="$( wc -l < "$EVIDENCE" | tr -d ' ' )"
if [ "$nlines" -ge 8 ]; then
    check_pass "evidence length >= 8 lines (actual=$nlines)"
else
    check_fail "evidence length < 8 lines (actual=$nlines)"
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
    printf 'PASS: m035-p00-npm-collision-evidence (D-RN-1-evidence.txt records collision-check outcome) checks=%d\n' "$pass"
    exit 0
else
    printf 'FAIL: m035-p00-npm-collision-evidence (pass=%d fail=%d)\n' "$pass" "$fail"
    printf '%b' "$failures" >&2
    exit 1
fi
