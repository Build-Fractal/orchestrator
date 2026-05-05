#!/usr/bin/env bash
# m033-p01-branch-detection-rules.sh
#
# T03 verifier: asserts FR-2's deterministic branch-detection ordered
# rules are implemented in scripts/lifecycle/start.sh — the four branch
# names, the rule-1 prior-tooling globs, the rule-2 PBJ markdown glob
# substrings, the rule-3 source-extension list (sample), and the rule-3
# git rev-list invocation. Optionally exercises detect_branch against
# the T01 PBJ fixture.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/lifecycle/start.sh"

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

if [ ! -f "$target" ]; then
    echo "FAIL: scripts/lifecycle/start.sh missing at $target"
    echo "SUMMARY: m033-p01-branch-detection-rules.sh pass=0 fail=1"
    exit 1
fi

# Four branch names (closed enum).
for branch_name in greenfield-empty greenfield-with-materials existing-codebase migrating; do
    if grep -qF -- "$branch_name" "$target"; then
        check_pass "branch name present: '$branch_name'"
    else
        check_fail "branch name missing: '$branch_name'"
    fi
done

# Rule 1: prior-tooling globs.
for glob in '.gsd' '.gsd2' '.specify'; do
    if grep -qF -- "$glob" "$target"; then
        check_pass "rule-1 prior-tooling glob present: '$glob'"
    else
        check_fail "rule-1 prior-tooling glob missing: '$glob'"
    fi
done

# Rule 2: PBJ markdown glob substrings.
for sub in '*BRIEF*' '*PLAN*' '*DECISIONS*' '*HANDOFF*' '*AUDIT*'; do
    if grep -qF -- "$sub" "$target"; then
        check_pass "rule-2 PBJ glob substring present: '$sub'"
    else
        check_fail "rule-2 PBJ glob substring missing: '$sub'"
    fi
done

# Rule 3: at least three source-extension tokens from the documented
# list. Sample picks: .js, .py, .rs.
for ext in '.js' '.py' '.rs'; do
    if grep -qF -- "$ext" "$target"; then
        check_pass "rule-3 source-extension token present: '$ext'"
    else
        check_fail "rule-3 source-extension token missing: '$ext'"
    fi
done

# Rule 3: git rev-list invocation. The actual call uses
# `git -C "$proj" rev-list --count HEAD` so we match the substring
# `rev-list --count HEAD` rather than the full prefix.
if grep -qF -- 'rev-list --count HEAD' "$target"; then
    check_pass "rule-3 git rev-list invocation present"
else
    check_fail "rule-3 git rev-list invocation missing"
fi

# Optional functional check: source the script (under a sentinel that
# suppresses main()) and call detect_branch against the T01 PBJ fixture.
fixture="$PROJECT_ROOT/tests/fixtures/m033-pbj-materials-fixture"
if [ -d "$fixture" ]; then
    # The script's main "$@" runs at file end on source. Run it in a
    # subshell with detect-only mode by invoking via bash -c that
    # extracts and replays detect_branch only.
    branch_out=$(bash -c '
        set -u
        DETECTED_FROM=""
        MIT006_ELIGIBLE=0
        # Source detect_branch by stripping the trailing main "$@" line.
        tmp=$(mktemp)
        grep -v "^main \"\$@\"" "'"$target"'" > "$tmp"
        # shellcheck disable=SC1090
        . "$tmp"
        detect_branch "'"$fixture"'"
        rm -f "$tmp"
    ' 2>/dev/null || echo "")
    if [ "$branch_out" = "greenfield-with-materials" ]; then
        check_pass "detect_branch on PBJ fixture echoes 'greenfield-with-materials'"
    else
        check_fail "detect_branch on PBJ fixture echoed '$branch_out' (expected greenfield-with-materials)"
    fi
else
    check_pass "PBJ fixture not present — skipping functional sanity (T01 deliverable)"
fi

echo "SUMMARY: m033-p01-branch-detection-rules.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
