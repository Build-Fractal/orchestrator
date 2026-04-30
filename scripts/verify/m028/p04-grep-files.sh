#!/usr/bin/env bash
# scripts/verify/m028/p04-grep-files.sh -- M028 P04/T01 plan-level verifier for grep-files.sh.
#
# Exercises the wrapper against a tmp-staged 2-file tree:
#   1. Match case: pattern present in both files -> exit 0, two separators.
#   2. No-match case: pattern in neither file -> exit 1.
#   3. Usage-error case: missing args -> exit 2.
#   4. Unreadable file -> exit 2.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/grep-files.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'apple banana\ncarrot\n' > "$tmp/a.txt"
printf 'apple date\nelderberry\n' > "$tmp/b.txt"
printf 'date elderberry\n' > "$tmp/c.txt"

# Case 1: both files match.
set +e
out_match="$(bash "$WRAPPER" 'apple' "$tmp/a.txt" "$tmp/b.txt")"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then pass "case1 exit 0 on any-match"; else fail "case1 exit" "rc=$rc"; fi
echo "$out_match" | grep -q -- "--- $tmp/a.txt ---" && pass "case1 separator a" || fail "case1 separator a" "missing"
echo "$out_match" | grep -q -- "--- $tmp/b.txt ---" && pass "case1 separator b" || fail "case1 separator b" "missing"

# Case 2: no matches.
set +e
bash "$WRAPPER" 'zzz_no_match' "$tmp/a.txt" "$tmp/b.txt" >/dev/null
rc=$?
set -e
if [ "$rc" -eq 1 ]; then pass "case2 exit 1 on no-match"; else fail "case2 exit" "rc=$rc"; fi

# Case 3: usage error (missing args).
set +e
bash "$WRAPPER" 2>/dev/null
rc=$?
set -e
if [ "$rc" -eq 2 ]; then pass "case3 exit 2 on usage"; else fail "case3 exit" "rc=$rc"; fi

# Case 4: unreadable file.
set +e
bash "$WRAPPER" 'foo' "$tmp/does-not-exist" 2>/dev/null
rc=$?
set -e
if [ "$rc" -eq 2 ]; then pass "case4 exit 2 on missing file"; else fail "case4 exit" "rc=$rc"; fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-grep-files.sh"
  exit 0
fi
echo "FAIL: p04-grep-files.sh ($fail_count failures)"
exit 1
