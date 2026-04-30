#!/usr/bin/env bash
# scripts/verify/m028/finding-D-verifier.sh -- M028 Finding D end-to-end gate.
#
# Finding D (in the wild): destructive `/bin/rm -f .../*.txt && ls .../*.txt`
# always prompts under Claude Code's destructive-op policy. The remediation is
# the wrapper `scripts/util/cleanup-stale-results.sh <milestone-id>` that
# performs the rm + listing internally, refuses paths outside the milestone
# tree, and emits a structured summary.
#
# This verifier proves the wrapper's contract end-to-end:
#   1. Happy path: 4 stale .txt files staged, wrapper removes all 4, REMOVED=4 RESIDUAL=0.
#   2. Boundary refusal: invalid milestone ID -> exit 2.
#   3. Missing tree: valid ID but no tree -> exit 1.
#   4. Multi-phase: stale files under multiple phases all removed.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/cleanup-stale-results.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found (Finding D wrapper missing)" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Stage isolated tmp tree.
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p "$tmp_root/scripts/util"
cp "$WRAPPER" "$tmp_root/scripts/util/cleanup-stale-results.sh"
mkdir -p "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks"
mkdir -p "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks"
printf 'a\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks/T01-r.txt"
printf 'b\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks/T02-r.txt"
printf 'c\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks/T01-r.txt"
printf 'd\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks/T02-r.txt"

# Case 1 + 4: happy path multi-phase.
out="$(bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M999)"
rc=$?
if [ "$rc" -eq 0 ]; then pass "case1 exit 0"; else fail "case1 exit" "rc=$rc"; fi
if printf '%s\n' "$out" | grep -q '^REMOVED: 4$'; then
  pass "case1 REMOVED=4 (multi-phase)"
else
  fail "case1 REMOVED=4" "got [$out]"
fi
if printf '%s\n' "$out" | grep -q '^RESIDUAL: 0$'; then
  pass "case1 RESIDUAL=0"
else
  fail "case1 RESIDUAL=0" "got [$out]"
fi
if printf '%s\n' "$out" | grep -q '^OK$'; then
  pass "case1 OK terminator"
else
  fail "case1 OK" "got [$out]"
fi

# Case 2: boundary refusal -- invalid milestone ID (path-escape).
bash "$tmp_root/scripts/util/cleanup-stale-results.sh" "../escape" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then
  pass "case2 boundary refusal on path-escape ID"
else
  fail "case2 refusal" "rc=$rc"
fi

# Case 2b: boundary refusal -- absolute path as ID.
bash "$tmp_root/scripts/util/cleanup-stale-results.sh" "/etc" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then
  pass "case2b boundary refusal on absolute path"
else
  fail "case2b refusal" "rc=$rc"
fi

# Case 3: missing tree -- valid ID format but no directory.
bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M998 2>/dev/null
rc=$?
if [ "$rc" -eq 1 ]; then
  pass "case3 exit 1 on missing tree"
else
  fail "case3 exit" "rc=$rc"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-D-verifier.sh"
  exit 0
fi
echo "FAIL: finding-D-verifier.sh ($fail_count failures)"
exit 1
