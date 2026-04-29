#!/usr/bin/env bash
# scripts/verify/m028/p04-node-eval.sh -- M028 P04/T02 plan-level verifier for node-eval.sh.
#
# Cases:
#   1. Happy path: stage tmp .js file printing 'NODE_EVAL_OK', run wrapper, assert stdout.
#   2. Usage (no args) -> exit 2.
#   3. Refuse -e -> exit 2.
#   4. Missing file -> exit 2.
#   5. Forwarded args: stage tmp .js that prints process.argv.slice(2), assert pass-through.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/node-eval.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "SKIP: p04-node-eval.sh (node not on PATH)"
  exit 0
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Case 1: happy path.
printf 'console.log("NODE_EVAL_OK");\n' > "$tmp/ok.js"
out="$(bash "$WRAPPER" "$tmp/ok.js")"
rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "NODE_EVAL_OK" ]; then
  pass "case1 happy path"
else
  fail "case1 happy path" "rc=$rc out=[$out]"
fi

# Case 2: usage.
bash "$WRAPPER" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case2 exit 2 on usage"; else fail "case2 exit" "rc=$rc"; fi

# Case 3: refuse -e.
bash "$WRAPPER" -e 'console.log(1)' 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case3 exit 2 on -e"; else fail "case3 exit" "rc=$rc"; fi

# Case 4: missing file.
bash "$WRAPPER" "$tmp/does-not-exist.js" 2>/dev/null
rc=$?
if [ "$rc" -eq 2 ]; then pass "case4 exit 2 on missing"; else fail "case4 exit" "rc=$rc"; fi

# Case 5: forwarded args.
printf 'console.log(process.argv.slice(2).join(","));\n' > "$tmp/argv.js"
out5="$(bash "$WRAPPER" "$tmp/argv.js" alpha beta gamma)"
if [ "$out5" = "alpha,beta,gamma" ]; then pass "case5 forwarded args"; else fail "case5 forwarded args" "got [$out5]"; fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-node-eval.sh"
  exit 0
fi
echo "FAIL: p04-node-eval.sh ($fail_count failures)"
exit 1
