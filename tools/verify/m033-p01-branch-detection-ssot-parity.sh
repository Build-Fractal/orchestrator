#!/usr/bin/env bash
# m033-p01-branch-detection-ssot-parity.sh
#
# Verifier for M033/P01/T02: asserts that the branch-detection pattern
# strings documented in `references/branch-detection.md` byte-match the
# patterns implemented in `scripts/lifecycle/start.sh`.
#
# Contract:
#   - SSOT: references/branch-detection.md (authored T02).
#   - Implementation: scripts/lifecycle/start.sh (authored T03).
#   - Parity check: every literal pattern string documented in the
#     four `branch-detection-rule-N` fenced blocks of the SSOT must
#     also appear literally somewhere in start.sh. Uses `grep -F`
#     (fixed-string match) to avoid regex-escaping ambiguity.
#   - Co-author gate: this verifier ships in T02 alongside the SSOT.
#     If start.sh does not yet exist (T03 not landed), the verifier
#     emits a single SKIP: line and exits 0. The phase-suite
#     aggregator (T05) treats SKIP as non-fail-non-pass.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
# Output prefixes per MEM001 structured-output convention.
#
# Usage:
#   bash tools/verify/m033-p01-branch-detection-ssot-parity.sh
#
# Output:
#   stdout: per-check PASS/FAIL/SKIP lines + final SUMMARY: line
#   exit 0 on all-pass-or-skip, 1 on any failure

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ssot_file="$PROJECT_ROOT/references/branch-detection.md"
impl_file="$PROJECT_ROOT/scripts/lifecycle/start.sh"

pass=0
fail=0
skip=0

check_pass() {
    pass=$((pass + 1))
    echo "PASS: $1"
}

check_fail() {
    fail=$((fail + 1))
    echo "FAIL: $1"
}

check_skip() {
    skip=$((skip + 1))
    echo "SKIP: $1"
}

# Gate 1: SSOT must exist. SSOT absence is a hard fail (T02 deliverable).
if [ ! -f "$ssot_file" ]; then
    echo "FAIL: references/branch-detection.md missing at $ssot_file"
    echo "SUMMARY: m033-p01-branch-detection-ssot-parity.sh pass=0 fail=1 skip=0"
    exit 1
fi
check_pass "references/branch-detection.md exists at $ssot_file"

# SSOT internal assertions: the four rule-blocks are present and the
# four branch names are documented.

# Check: each of the four rule-N fenced blocks is present.
for rule_num in 1 2 3 4; do
    marker="branch-detection-rule-${rule_num}"
    if grep -qF "$marker" "$ssot_file"; then
        check_pass "SSOT contains branch-detection-rule-${rule_num} block"
    else
        check_fail "SSOT missing branch-detection-rule-${rule_num} block"
    fi
done

# Check: each of the four branch names appears literally in the SSOT.
for branch_name in greenfield-empty greenfield-with-materials existing-codebase migrating; do
    if grep -qF "$branch_name" "$ssot_file"; then
        check_pass "SSOT contains branch name '$branch_name'"
    else
        check_fail "SSOT missing branch name '$branch_name'"
    fi
done

# Check: load-bearing pattern strings are present in the SSOT.
# These are the strings the parity check will cross-assert against
# start.sh. Asserting their presence in the SSOT first catches
# accidental SSOT corruption that would otherwise propagate silently.
ssot_patterns_required=(
    ".gsd/"
    ".gsd2/"
    ".specify/"
    "*BRIEF*.md|*PLAN*.md|*DECISIONS*.md|*HANDOFF*.md|*AUDIT*.md"
    ".js .ts .jsx .tsx .py .rs .go .rb .java .kt .swift .cs .cpp .c .h"
    "source_root_min_count: 10"
    "git_min_commits: 1"
)
for pat in "${ssot_patterns_required[@]}"; do
    if grep -qF -- "$pat" "$ssot_file"; then
        check_pass "SSOT contains pattern '$pat'"
    else
        check_fail "SSOT missing pattern '$pat'"
    fi
done

# Gate 2: start.sh existence gate. If start.sh does not yet exist
# (T03 not landed), emit SKIP for the cross-parity assertions and
# exit 0. This lets the verifier ship in T02 without false-failing.
if [ ! -f "$impl_file" ]; then
    check_skip "scripts/lifecycle/start.sh not yet authored (T03 deliverable); cross-parity assertions deferred"
    echo "SUMMARY: m033-p01-branch-detection-ssot-parity.sh pass=$pass fail=$fail skip=$skip"
    if [ "$fail" -gt 0 ]; then
        exit 1
    fi
    exit 0
fi
check_pass "scripts/lifecycle/start.sh exists at $impl_file"

# Cross-parity assertions: every load-bearing literal pattern string
# documented in the SSOT must also appear literally in start.sh.

# Check: prior-tooling globs (rule 1).
for tooling_glob in ".gsd/" ".gsd2/" ".specify/"; do
    if grep -qF -- "$tooling_glob" "$impl_file"; then
        check_pass "start.sh contains rule-1 tooling glob '$tooling_glob'"
    else
        check_fail "start.sh missing rule-1 tooling glob '$tooling_glob'"
    fi
done

# Check: PBJ markdown glob (rule 2).
pbj_glob='*BRIEF*.md|*PLAN*.md|*DECISIONS*.md|*HANDOFF*.md|*AUDIT*.md'
if grep -qF -- "$pbj_glob" "$impl_file"; then
    check_pass "start.sh contains rule-2 PBJ markdown glob"
else
    check_fail "start.sh missing rule-2 PBJ markdown glob"
fi

# Check: source-extension list (rule 3). Asserted as the literal
# space-separated string to avoid drift in ordering or formatting.
src_ext_list='.js .ts .jsx .tsx .py .rs .go .rb .java .kt .swift .cs .cpp .c .h'
if grep -qF -- "$src_ext_list" "$impl_file"; then
    check_pass "start.sh contains rule-3 source-extension list"
else
    check_fail "start.sh missing rule-3 source-extension list"
fi

# Check: source-root min count (rule 3).
if grep -qF -- "source_root_min_count: 10" "$impl_file"; then
    check_pass "start.sh contains rule-3 source_root_min_count: 10"
else
    check_fail "start.sh missing rule-3 source_root_min_count: 10"
fi

# Check: git min commits (rule 3).
if grep -qF -- "git_min_commits: 1" "$impl_file"; then
    check_pass "start.sh contains rule-3 git_min_commits: 1"
else
    check_fail "start.sh missing rule-3 git_min_commits: 1"
fi

# Check: each of the four branch names appears literally in start.sh.
for branch_name in greenfield-empty greenfield-with-materials existing-codebase migrating; do
    if grep -qF -- "$branch_name" "$impl_file"; then
        check_pass "start.sh contains branch name '$branch_name'"
    else
        check_fail "start.sh missing branch name '$branch_name'"
    fi
done

echo "SUMMARY: m033-p01-branch-detection-ssot-parity.sh pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
