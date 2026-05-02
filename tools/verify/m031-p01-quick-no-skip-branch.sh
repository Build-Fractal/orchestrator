#!/usr/bin/env bash
# m031-p01-quick-no-skip-branch.sh
#
# Verifier for M031/P01/T01 CON-1 invariant from build-context.sh's
# perspective: the script's body MUST contain a profile-aware branch that
# always reaches the manifest-assembly + payload_breakdown emission code
# path. Concretely:
#   - Assert build-context.sh does NOT contain a literal early-exit pattern
#     matching "# skip context" (case-insensitive).
#   - Assert build-context.sh contains the substring `payload_breakdown`
#     (the JSONL record name proving every dispatch path emits one).
# This is the build-context.sh-side check; the dispatch.md-side check
# (FR-4) is m031-p01-dispatch-md-reconciliation.sh shipped in T02.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m031-p01-quick-no-skip-branch.sh
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

build_context="$PROJECT_ROOT/scripts/dispatch/build-context.sh"

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

# Check 1: build-context.sh exists.
if [ ! -f "$build_context" ]; then
    echo "FAIL: build-context.sh missing at $build_context"
    echo "SUMMARY: m031-p01-quick-no-skip-branch.sh pass=0 fail=1"
    exit 1
fi
check_pass "build-context.sh exists at $build_context"

# Check 2: no "# skip context" early-exit pattern (case-insensitive). The
# CON-1 invariant rules out any path that bypasses manifest assembly + the
# payload_breakdown emit. Inverted-polarity grep — the comment guards
# against well-intentioned future "fixes" (MEM-AD-19-style).
if grep -i '# skip context' "$build_context" >/dev/null 2>&1; then
    check_fail "build-context.sh contains '# skip context' early-exit (CON-1 violation)"
else
    check_pass "build-context.sh does NOT contain '# skip context' early-exit"
fi

# Check 3: payload_breakdown record name is present (proves every dispatch
# path emits one JSONL record).
if grep -q 'payload_breakdown' "$build_context"; then
    check_pass "build-context.sh contains payload_breakdown record name"
else
    check_fail "build-context.sh missing payload_breakdown record name"
fi

echo "SUMMARY: m031-p01-quick-no-skip-branch.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
