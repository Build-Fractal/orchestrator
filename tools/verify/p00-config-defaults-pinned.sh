#!/usr/bin/env bash
# p00-config-defaults-pinned.sh
#
# Verifier for M031/P00/T02 config defaults: asserts the three M031
# knobs landed in templates/orchestrator-config-default.yml at the
# expected pinned values with FR/AD comment references.
#
#   quick_knowledge_token_budget: 800       — FR-5 / AD-5
#   entry_routing_confidence_floor: 0.7     — FR-11 / OQ-4
#   tier_a_plus_prompt_summary_lines: 8     — AD-20
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no
# process substitution. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/p00-config-defaults-pinned.sh
#   bash tools/verify/p00-config-defaults-pinned.sh path/to/orchestrator-config-default.yml
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

file="${1:-templates/orchestrator-config-default.yml}"

pass=0
fail=0

check_pass() {
    pass=$((pass + 1))
    echo "PASS: $1"
}

check_fail() {
    fail=$((fail + 1))
    echo "FAIL: $1"
}

# Check 1: file exists
if [ ! -f "$file" ]; then
    echo "FAIL: orchestrator-config-default.yml missing at $file"
    echo "SUMMARY: p00-config-defaults-pinned.sh pass=0 fail=1"
    exit 1
fi
check_pass "orchestrator-config-default.yml exists at $file"

# Check 2: quick_knowledge_token_budget: 800 declared at top level
if grep -qE '^quick_knowledge_token_budget:[[:space:]]*800' "$file"; then
    check_pass "quick_knowledge_token_budget: 800 declared at top level"
else
    check_fail "quick_knowledge_token_budget: 800 missing or not at top level"
fi

# Check 3: entry_routing_confidence_floor: 0.7 declared at top level
if grep -qE '^entry_routing_confidence_floor:[[:space:]]*0\.7' "$file"; then
    check_pass "entry_routing_confidence_floor: 0.7 declared at top level"
else
    check_fail "entry_routing_confidence_floor: 0.7 missing or not at top level"
fi

# Check 4: tier_a_plus_prompt_summary_lines: 8 declared at top level
if grep -qE '^tier_a_plus_prompt_summary_lines:[[:space:]]*8' "$file"; then
    check_pass "tier_a_plus_prompt_summary_lines: 8 declared at top level"
else
    check_fail "tier_a_plus_prompt_summary_lines: 8 missing or not at top level"
fi

# Check 5: each knob's line carries an FR or AD reference comment.
# The line itself should contain "# ... FR-N" or "# ... AD-N" after the value.
comment_missing=""
for knob in quick_knowledge_token_budget entry_routing_confidence_floor tier_a_plus_prompt_summary_lines; do
    line=$(grep -E "^${knob}:" "$file" | head -n 1)
    if [ -z "$line" ]; then
        comment_missing="$comment_missing [${knob}:line-missing]"
        continue
    fi
    if echo "$line" | grep -qE '#.*(FR-[0-9]+|AD-[0-9]+|OQ-[0-9]+)'; then
        :
    else
        comment_missing="$comment_missing [${knob}:no-FR/AD-comment]"
    fi
done
if [ -z "$comment_missing" ]; then
    check_pass "each knob carries an inline FR/AD reference comment"
else
    check_fail "knob comment references missing:$comment_missing"
fi

# Final summary
echo "SUMMARY: p00-config-defaults-pinned.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
