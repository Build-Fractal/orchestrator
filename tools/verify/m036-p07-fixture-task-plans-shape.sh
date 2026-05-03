#!/usr/bin/env bash
# tools/verify/m036-p07-fixture-task-plans-shape.sh — M036 P07 T03
# token-presence verifier for the two synthetic fixture task plans.
# AD-19.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F1="$ROOT/tests/fixtures/m036-p07-task-plans/T-with-topic-tags-PLAN.md"
F2="$ROOT/tests/fixtures/m036-p07-task-plans/T-no-scope-PLAN.md"
pass=0
fail=0
chk() {
  local label="$1" file="$2" pat="$3"
  if [ -f "$file" ] && grep -qF -e "$pat" "$file"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label"
    fail=$((fail + 1))
  fi
}
chk "with-topic-tags-exists"        "$F1" "topic_tags: [pbj-staffing]"
chk "with-topic-tags-budget"        "$F1" "reference_token_budget: 4000"
chk "no-scope-exists"               "$F2" "scope_tags: [project]"
chk "no-scope-no-topic-tags"        "$F2" "T-no-scope"
if [ -f "$F2" ]; then
  if grep -qF -e "topic_tags:" "$F2"; then
    echo "FAIL: no-scope-fixture-must-not-declare-topic_tags"
    fail=$((fail + 1))
  else
    echo "PASS: no-scope-has-no-topic_tags"
    pass=$((pass + 1))
  fi
fi
echo "SUMMARY: m036-p07-fixture-task-plans-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
