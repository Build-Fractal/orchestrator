#!/usr/bin/env bash
# tests/m031-acceptance/test-auto-proceed-default.sh
# M031/P04/T01 — SC-10 auto-proceed default test.
#
# Asserts auto_proceed: true is the committed default in
# templates/orchestrator-config-default.yml AND CHANGELOG.md names the
# M031 compound flip per AD-9 (single co-located note rather than two
# separate items).
#
# Required CHANGELOG.md substrings:
#   - "M031"
#   - "auto_proceed"
#   - "quick_knowledge_token_budget"
#   - "compound"
#
# Emits RESULT: SC-10 pass (exit 0) or RESULT: SC-10 fail (exit 1).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
TEMPLATE="$PROJECT_ROOT/templates/orchestrator-config-default.yml"
CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"

pass=0
fail=0

check_present() {
    if grep -q -F -- "$2" "$1"; then
        printf 'PASS: %s\n' "$3"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s -- %s missing "%s"\n' "$3" "$1" "$2"
        fail=$((fail + 1))
    fi
}

check_present "$TEMPLATE"  "auto_proceed: true"           "auto_proceed: true literal in template"
check_present "$CHANGELOG" "M031"                         "CHANGELOG names M031"
check_present "$CHANGELOG" "auto_proceed"                 "CHANGELOG names auto_proceed"
check_present "$CHANGELOG" "quick_knowledge_token_budget" "CHANGELOG names quick_knowledge_token_budget"
check_present "$CHANGELOG" "compound"                     "CHANGELOG names the compound flip"

printf 'SC-10 totals: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    printf 'RESULT: SC-10 pass\n'
    exit 0
fi
printf 'RESULT: SC-10 fail\n'
exit 1
