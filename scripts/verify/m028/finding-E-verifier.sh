#!/usr/bin/env bash
# scripts/verify/m028/finding-E-verifier.sh -- M028 Finding E end-to-end gate.
#
# Finding E (in the wild): agents invent compound shells when no canonical
# investigation example covers them (M028 spec Findings C, D, E group). The
# documentation surfaces (dispatch.md, dispatch-prompt.md, ANTIPATTERNS.md
# Investigation patterns subsection) cover the discoverability axis (T03);
# the wrapper-existence axis is asserted by p04-wrappers-present.sh (T05).
#
# This verifier asserts the operational axis: when an agent calls one of the
# canonical wrappers, it produces the expected output. We exercise grep-files.sh
# and node-eval.sh end-to-end to prove they are operationally reachable.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
GREP_FILES="${REPO_ROOT}/scripts/util/grep-files.sh"
NODE_EVAL="${REPO_ROOT}/scripts/util/node-eval.sh"

if [ ! -f "$GREP_FILES" ]; then
  echo "FAIL: $GREP_FILES not found (Finding E wrapper missing)" >&2
  exit 1
fi
if [ ! -f "$NODE_EVAL" ]; then
  echo "FAIL: $NODE_EVAL not found (Finding E wrapper missing)" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# grep-files.sh end-to-end: stage 2 files, grep an investigation pattern.
printf 'classify_command "foo"\nset -u\n' > "$tmp/a.sh"
printf 'classify_command "$cmd"\necho done\n' > "$tmp/b.sh"

out_grep="$(bash "$GREP_FILES" 'classify_command' "$tmp/a.sh" "$tmp/b.sh")"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "grep-files.sh end-to-end exit 0"
else
  fail "grep-files.sh exit" "rc=$rc"
fi

sep_count="$(printf '%s\n' "$out_grep" | grep -c '^--- ')"
if [ "$sep_count" -eq 2 ]; then
  pass "grep-files.sh emits 2 separators"
else
  fail "grep-files.sh separators" "got $sep_count"
fi

match_count="$(printf '%s\n' "$out_grep" | grep -c 'classify_command')"
if [ "$match_count" -ge 2 ]; then
  pass "grep-files.sh emits matches"
else
  fail "grep-files.sh matches" "got $match_count"
fi

# node-eval.sh end-to-end: stage a .js, run wrapper, assert stdout.
if command -v node >/dev/null 2>&1; then
  printf 'console.log("FINDING_E_NODE_OK");\n' > "$tmp/probe.js"
  out_node="$(bash "$NODE_EVAL" "$tmp/probe.js")"
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$out_node" = "FINDING_E_NODE_OK" ]; then
    pass "node-eval.sh end-to-end emits expected stdout"
  else
    fail "node-eval.sh end-to-end" "rc=$rc out=[$out_node]"
  fi
else
  echo "SKIP: node-eval.sh end-to-end (node not on PATH)"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-E-verifier.sh"
  exit 0
fi
echo "FAIL: finding-E-verifier.sh ($fail_count failures)"
exit 1
