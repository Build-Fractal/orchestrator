#!/usr/bin/env bash
# scripts/verify/m028/p04-cleanup-stale-results.sh -- M028 P04/T01 plan-level verifier
# for cleanup-stale-results.sh.
#
# Exercises the wrapper against an isolated tmp tree mirroring the
# .orchestrator/milestones/<MID>/phases/<PID>/tasks/ layout:
#   1. Happy path: 3 .txt files staged, wrapper removes all 3, RESIDUAL=0.
#   2. No-tree case: bogus milestone ID -> exit 2 (invalid format) or exit 1 (missing tree).
#   3. Empty-tree case: milestone exists but no .txt files -> REMOVED=0, exit 0.
#   4. Boundary refusal: invalid milestone ID -> exit 2.
#
# Uses an isolated REPO_ROOT by copying the wrapper into a tmp tree.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/cleanup-stale-results.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Case 4: invalid milestone ID -> exit 2.
set +e
bash "$WRAPPER" "not-a-milestone" 2>/dev/null
rc=$?
set -e
if [ "$rc" -eq 2 ]; then pass "case4 exit 2 on invalid ID"; else fail "case4 exit" "rc=$rc"; fi

# Case 4b: usage (no args) -> exit 2.
set +e
bash "$WRAPPER" 2>/dev/null
rc=$?
set -e
if [ "$rc" -eq 2 ]; then pass "case4b exit 2 on no-args"; else fail "case4b exit" "rc=$rc"; fi

# Case 1 (happy path): stage isolated tree.
tmp_root="$(mktemp -d)"
mkdir -p "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks"
mkdir -p "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks"
printf 'stale1\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks/T01-result.txt"
printf 'stale2\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P01/tasks/T02-result.txt"
printf 'stale3\n' > "$tmp_root/.orchestrator/milestones/M999/phases/P02/tasks/T01-result.txt"

# Stage a wrapper copy that resolves REPO_ROOT to $tmp_root via dirname inversion:
# cleanup-stale-results.sh resolves REPO_ROOT as "$(cd "$script_dir/../.." && pwd -P)",
# so we copy it into $tmp_root/scripts/util/ and invoke from there.
mkdir -p "$tmp_root/scripts/util"
cp "$WRAPPER" "$tmp_root/scripts/util/cleanup-stale-results.sh"

set +e
out="$(bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M999)"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then pass "case1 exit 0 on happy path"; else fail "case1 exit" "rc=$rc"; fi
echo "$out" | grep -q '^REMOVED: 3$' && pass "case1 REMOVED=3" || fail "case1 REMOVED" "got [$out]"
echo "$out" | grep -q '^RESIDUAL: 0$' && pass "case1 RESIDUAL=0" || fail "case1 RESIDUAL" "got [$out]"
echo "$out" | grep -q '^OK$' && pass "case1 OK terminator" || fail "case1 OK" "got [$out]"

# Case 3: empty tree (no .txt files).
mkdir -p "$tmp_root/.orchestrator/milestones/M998/phases/P01/tasks"
set +e
out2="$(bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M998)"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then pass "case3 exit 0 on empty"; else fail "case3 exit" "rc=$rc"; fi
echo "$out2" | grep -q '^REMOVED: 0$' && pass "case3 REMOVED=0" || fail "case3 REMOVED" "got [$out2]"

# Case 2: missing tree.
set +e
bash "$tmp_root/scripts/util/cleanup-stale-results.sh" M997 2>/dev/null
rc=$?
set -e
if [ "$rc" -eq 1 ]; then pass "case2 exit 1 on missing tree"; else fail "case2 exit" "rc=$rc"; fi

rm -rf "$tmp_root"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-cleanup-stale-results.sh"
  exit 0
fi
echo "FAIL: p04-cleanup-stale-results.sh ($fail_count failures)"
exit 1
