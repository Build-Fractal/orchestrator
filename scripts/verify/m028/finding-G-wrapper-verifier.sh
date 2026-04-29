#!/usr/bin/env bash
# scripts/verify/m028/finding-G-wrapper-verifier.sh -- M028 Finding G wrapper-path gate.
#
# Finding G (in the wild): the verbatim shape
#   find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null \
#     | head -3 | xargs -I{} sh -c 'echo "=== {} ==="; head -20 "{}"'
# trips AP-014 under the M028 classifier (verified by finding-G-classifier-
# verifier.sh in P03). The wrapper-side complement: peek-files.sh produces
# the operator's intended output for the same use case without invoking the
# AP-014 shape internally.
#
# Cases:
#   1. Happy path: stage 4 T*-SUMMARY.md files across M001/M002/M066, run
#      peek-files.sh with --max 3 --lines 20, assert 3 separators.
#   2. --exclude path: rerun with --exclude M066; assert excluded content
#      absent from output.
#   3. No internal sh -c: assert peek-files.sh source contains no
#      `sh -c '` literal (the wrapper's self-conformance to the AP-014
#      remediation contract).
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
WRAPPER="${REPO_ROOT}/scripts/util/peek-files.sh"

if [ ! -f "$WRAPPER" ]; then
  echo "FAIL: $WRAPPER not found (Finding G wrapper missing)" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Stage tree mirroring the Finding G use case.
mkdir -p "$tmp/M001/phases/P01/tasks" "$tmp/M002/phases/P01/tasks" "$tmp/M066/phases/P01/tasks"
printf 'M001-T01-line1\nM001-T01-line2\n' > "$tmp/M001/phases/P01/tasks/T01-SUMMARY.md"
printf 'M001-T02-line1\nM001-T02-line2\n' > "$tmp/M001/phases/P01/tasks/T02-SUMMARY.md"
printf 'M002-T01-line1\nM002-T01-line2\n' > "$tmp/M002/phases/P01/tasks/T01-SUMMARY.md"
printf 'M066-T01-EXCLUDED\n' > "$tmp/M066/phases/P01/tasks/T01-SUMMARY.md"

prev_dir="$(pwd -P)"
cd "$tmp"

# Case 1: happy path -- 4 matches without --exclude, --max 3 -> 3 separators.
out="$(bash "$WRAPPER" 'T*-SUMMARY.md' --max 3 --lines 20)"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "case1 exit 0"
else
  fail "case1 exit" "rc=$rc"
fi
sep="$(printf '%s\n' "$out" | grep -c '^--- ')"
if [ "$sep" -eq 3 ]; then
  pass "case1 --max 3 enforced"
else
  fail "case1 --max" "got $sep"
fi

# Case 2: --exclude M066.
out2="$(bash "$WRAPPER" 'T*-SUMMARY.md' --exclude M066)"
if printf '%s\n' "$out2" | grep -q 'EXCLUDED'; then
  fail "case2 --exclude M066" "excluded content present"
else
  pass "case2 --exclude M066 filters"
fi

cd "$prev_dir"

# Case 3: wrapper-source self-conformance -- peek-files.sh code (excluding
# comment lines) contains no `sh -c '` literal. Comment lines are excluded
# because the wrapper's own docstring legitimately references the AP-014
# shape it replaces; the contract is that the implementation does not
# rebuild the shape, not that the documentation cannot mention it.
code_only="$(mktemp)"
grep -v '^[[:space:]]*#' "$WRAPPER" > "$code_only"
if grep -q "sh -c '" "$code_only"; then
  fail "case3 self-conformance" "peek-files.sh code contains sh -c literal"
else
  pass "case3 peek-files.sh self-conformance (no sh -c internal)"
fi
rm -f "$code_only"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: finding-G-wrapper-verifier.sh"
  exit 0
fi
echo "FAIL: finding-G-wrapper-verifier.sh ($fail_count failures)"
exit 1
