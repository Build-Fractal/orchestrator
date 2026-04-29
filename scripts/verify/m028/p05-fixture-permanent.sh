#!/usr/bin/env bash
# scripts/verify/m028/p05-fixture-permanent.sh -- M028/P05/T01 cross-cutting verifier.
#
# Asserts the permanent in-tree downstream-project fixture (CON-10) exists
# at tests/fixtures/downstream-project/ with its .claude/settings.json and
# README.md present and minimally populated.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
FIXTURE_DIR="${REPO_ROOT}/tests/fixtures/downstream-project"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)" >&2; fail_count=$((fail_count + 1)); }

if [ -d "$FIXTURE_DIR" ]; then
  pass "fixture dir exists at $FIXTURE_DIR"
else
  fail "fixture dir exists" "missing $FIXTURE_DIR"
fi

settings="${FIXTURE_DIR}/.claude/settings.json"
if [ -f "$settings" ]; then
  lines=$(wc -l < "$settings")
  if [ "$lines" -ge 8 ]; then
    pass ".claude/settings.json present (>=8 lines)"
  else
    fail ".claude/settings.json line count" "got $lines"
  fi
else
  fail ".claude/settings.json present" "missing $settings"
fi

readme="${FIXTURE_DIR}/README.md"
if [ -f "$readme" ]; then
  lines=$(wc -l < "$readme")
  if [ "$lines" -ge 6 ]; then
    pass "README.md present (>=6 lines)"
  else
    fail "README.md line count" "got $lines"
  fi
  if grep -q 'downstream-project' "$readme"; then
    pass "README.md mentions downstream-project"
  else
    fail "README.md substring" "missing downstream-project token"
  fi
else
  fail "README.md present" "missing $readme"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p05-fixture-permanent.sh"
  exit 0
fi
echo "FAIL: p05-fixture-permanent.sh ($fail_count failures)"
exit 1
