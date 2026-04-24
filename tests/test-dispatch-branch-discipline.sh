#!/usr/bin/env bash
# tests/test-dispatch-branch-discipline.sh — Issue #4 regression test
#
# Issue #4: a T03/T04 subagent on M026 checked out dogfood-hotfix-efgh
# to land a side-fix without announcing it. The dispatch payload had
# no explicit prohibition on git checkout / switch / merge / rebase
# inside a dispatched task, so the subagent thought it was being
# helpful.
#
# Fix: handle_template (Constraints section emitter in
# scripts/dispatch/lib/section-handlers.sh) now appends a "Branch
# Discipline" subsection that forbids unannounced branch operations
# and tells the agent to stop+report if a side-branch is genuinely
# required.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HANDLERS="$PROJECT_ROOT/scripts/dispatch/lib/section-handlers.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# Source handlers + invoke handle_template directly.
out_file=$(mktemp)
(
  set +e
  # shellcheck disable=SC1090
  . "$HANDLERS"
  handle_template "/tmp/orch" "M999" "P00" "T01" "constraints"
) > "$out_file" 2>&1

if grep -q '### Branch Discipline' "$out_file"; then
  pass "Constraints section emits ### Branch Discipline subsection"
else
  fail "Constraints section emits ### Branch Discipline (got: $(cat "$out_file"))"
fi

if grep -qE 'git (checkout|switch|branch|merge|rebase)' "$out_file"; then
  pass "Branch Discipline names the prohibited git verbs"
else
  fail "Branch Discipline names prohibited git verbs"
fi

if grep -qE '[Ss][Tt][Oo][Pp].*report|report.*[Ss][Tt][Oo][Pp]' "$out_file"; then
  pass "Branch Discipline tells agent to stop+report when unsure"
else
  fail "Branch Discipline tells agent to stop+report"
fi

if grep -q 'inherit' "$out_file"; then
  pass "Branch Discipline frames behavior as 'inherit the dispatcher branch'"
else
  fail "Branch Discipline frames as inherit"
fi

rm -f "$out_file"

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
