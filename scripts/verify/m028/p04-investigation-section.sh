#!/usr/bin/env bash
# scripts/verify/m028/p04-investigation-section.sh -- M028 P04/T03 plan-level verifier.
#
# Asserts that the three documentation surfaces (commands/dispatch.md,
# templates/dispatch-prompt.md, ANTIPATTERNS.md) carry the Investigation
# Patterns section and that each section names all four wrappers.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"

DISPATCH_MD="${REPO_ROOT}/commands/dispatch.md"
PROMPT_TPL="${REPO_ROOT}/templates/dispatch-prompt.md"
ANTI_MD="${REPO_ROOT}/ANTIPATTERNS.md"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

assert_section_and_wrappers() {
  local file="$1" header_pattern="$2" label="$3"
  if [ ! -f "$file" ]; then
    fail "$label exists" "missing $file"
    return
  fi
  if grep -qE "$header_pattern" "$file"; then
    pass "$label has Investigation section header"
  else
    fail "$label section header" "no match for $header_pattern in $file"
    return
  fi
  for w in grep-files.sh cleanup-stale-results.sh node-eval.sh peek-files.sh; do
    if grep -q "$w" "$file"; then
      pass "$label names $w"
    else
      fail "$label names $w" "missing $w in $file"
    fi
  done
}

assert_section_and_wrappers "$DISPATCH_MD" "^## Investigation Patterns" "commands/dispatch.md"
assert_section_and_wrappers "$PROMPT_TPL" "^## Investigation Patterns" "templates/dispatch-prompt.md"
assert_section_and_wrappers "$ANTI_MD"    "^## Investigation patterns" "ANTIPATTERNS.md"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-investigation-section.sh"
  exit 0
fi
echo "FAIL: p04-investigation-section.sh ($fail_count failures)"
exit 1
