#!/usr/bin/env bash
# scripts/verify/m028/p04-anti-pattern-lint-clean.sh -- M028 P04/T03 plan-level verifier.
#
# Runs `scripts/verify/anti-pattern-lint.sh` against its default scope
# (which includes commands/*.md, templates/*.md, dispatch lib, and active
# task PAYLOADs) and asserts exit 0. The default scope covers the T03
# surface; the lint already self-excludes ANTIPATTERNS.md by default.
#
# Also runs the lint with --fixture against ANTIPATTERNS.md to validate
# the new "Investigation patterns" subsection's shape is clean.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
LINT="${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh"

if [ ! -f "$LINT" ]; then
  echo "FAIL: $LINT not found" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# Default-scope lint -- must pass.
if bash "$LINT" >/dev/null 2>&1; then
  pass "anti-pattern-lint default-scope clean"
else
  fail "anti-pattern-lint default-scope" "non-zero exit"
fi

# Fixture-mode lint against ANTIPATTERNS.md -- must pass on the new subsection.
if bash "$LINT" --fixture "${REPO_ROOT}/ANTIPATTERNS.md" >/dev/null 2>&1; then
  pass "anti-pattern-lint --fixture ANTIPATTERNS.md clean"
else
  fail "anti-pattern-lint --fixture ANTIPATTERNS.md" "non-zero exit"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-anti-pattern-lint-clean.sh"
  exit 0
fi
echo "FAIL: p04-anti-pattern-lint-clean.sh ($fail_count failures)"
exit 1
