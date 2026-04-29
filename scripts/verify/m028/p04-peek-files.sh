#!/usr/bin/env bash
# scripts/verify/m028/p04-peek-files.sh -- M028 P04/T02 plan-level verifier for peek-files.sh.
#
# Cases:
#   1. Happy path: stage 4 matching files in tmp tree, run wrapper, assert 4 separators + content.
#   2. --lines N: assert head-N respected.
#   3. --exclude: assert excluded path absent from output.
#   4. --max N: assert cap enforced.
#   5. No matches -> exit 1.
#   6. Usage error: bad --lines value -> exit 2.
#
# Verifier runs from a tmp dir to isolate find . from the repo tree.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/peek-files.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Stage tree.
mkdir -p "$tmp/a/sub" "$tmp/b" "$tmp/excluded"
printf 'line1\nline2\nline3\nline4\n' > "$tmp/a/T01-SUMMARY.md"
printf 'lineA\nlineB\nlineC\n' > "$tmp/a/sub/T02-SUMMARY.md"
printf 'lineX\nlineY\n' > "$tmp/b/T03-SUMMARY.md"
printf 'should not appear\n' > "$tmp/excluded/T04-SUMMARY.md"

# Use a subshell-style approach: cd via a wrapper that runs the gate inside $tmp.
# (No process substitution; plain cd is safe.)
prev_dir="$(pwd -P)"
cd "$tmp"

# Case 1: happy path -- 4 matches, default --lines 20 (all content shown).
out="$(bash "$WRAPPER" 'T*-SUMMARY.md')"
rc=$?
if [ "$rc" -eq 0 ]; then pass "case1 exit 0"; else fail "case1 exit" "rc=$rc"; fi
sep_count="$(printf '%s\n' "$out" | grep -c '^--- ')"
if [ "$sep_count" -eq 4 ]; then pass "case1 4 separators"; else fail "case1 separators" "got $sep_count"; fi

# Case 2: --lines 2.
out2="$(bash "$WRAPPER" 'T01-SUMMARY.md' --lines 2)"
content_lines="$(printf '%s\n' "$out2" | grep -cE '^line[1-4]$')"
if [ "$content_lines" -eq 2 ]; then pass "case2 --lines 2 respected"; else fail "case2 --lines" "got $content_lines"; fi

# Case 3: --exclude.
out3="$(bash "$WRAPPER" 'T*-SUMMARY.md' --exclude excluded)"
if printf '%s\n' "$out3" | grep -q 'should not appear'; then
  fail "case3 --exclude" "excluded content present"
else
  pass "case3 --exclude filters"
fi

# Case 4: --max 1.
out4="$(bash "$WRAPPER" 'T*-SUMMARY.md' --max 1)"
sep4="$(printf '%s\n' "$out4" | grep -c '^--- ')"
if [ "$sep4" -eq 1 ]; then pass "case4 --max 1 enforced"; else fail "case4 --max" "got $sep4"; fi

# Case 5: no matches.
bash "$WRAPPER" 'NO_SUCH_FILE_*.md' >/dev/null
rc=$?
if [ "$rc" -eq 1 ]; then pass "case5 exit 1 on no-match"; else fail "case5 exit" "rc=$rc"; fi

# Case 6: bad --lines.
bash "$WRAPPER" 'T*-SUMMARY.md' --lines abc 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case6 exit 2 on bad --lines"; else fail "case6 exit" "rc=$rc"; fi

cd "$prev_dir"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-peek-files.sh"
  exit 0
fi
echo "FAIL: p04-peek-files.sh ($fail_count failures)"
exit 1
