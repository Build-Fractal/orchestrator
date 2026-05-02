#!/usr/bin/env bash
# m031-p01-config-knobs-stable.sh
#
# Verifier for M031/P01/T01 stability gate: asserts that
# templates/orchestrator-config-default.yml carries exactly one occurrence
# of each of the three M031 knobs at their P00-pinned values:
#
#   quick_knowledge_token_budget: 800
#   entry_routing_confidence_floor: 0.7
#   tier_a_plus_prompt_summary_lines: 8
#
# P00 set these; P01 does NOT modify them. This verifier is a stability
# assertion, not a write.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m031-p01-config-knobs-stable.sh
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

config_file="$PROJECT_ROOT/templates/orchestrator-config-default.yml"

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

# Check 1: config file exists.
if [ ! -f "$config_file" ]; then
    echo "FAIL: orchestrator-config-default.yml missing at $config_file"
    echo "SUMMARY: m031-p01-config-knobs-stable.sh pass=0 fail=1"
    exit 1
fi
check_pass "orchestrator-config-default.yml exists at $config_file"

# Check 2: exactly one quick_knowledge_token_budget: 800 occurrence.
n_qk=$(grep -cE '^quick_knowledge_token_budget:[[:space:]]*800' "$config_file" 2>/dev/null || echo 0)
if [ "$n_qk" = "1" ]; then
    check_pass "quick_knowledge_token_budget: 800 occurs exactly once"
else
    check_fail "quick_knowledge_token_budget: 800 occurs $n_qk times (expected 1)"
fi

# Check 3: exactly one entry_routing_confidence_floor: 0.7 occurrence.
n_er=$(grep -cE '^entry_routing_confidence_floor:[[:space:]]*0\.7' "$config_file" 2>/dev/null || echo 0)
if [ "$n_er" = "1" ]; then
    check_pass "entry_routing_confidence_floor: 0.7 occurs exactly once"
else
    check_fail "entry_routing_confidence_floor: 0.7 occurs $n_er times (expected 1)"
fi

# Check 4: exactly one tier_a_plus_prompt_summary_lines: 8 occurrence.
n_ta=$(grep -cE '^tier_a_plus_prompt_summary_lines:[[:space:]]*8' "$config_file" 2>/dev/null || echo 0)
if [ "$n_ta" = "1" ]; then
    check_pass "tier_a_plus_prompt_summary_lines: 8 occurs exactly once"
else
    check_fail "tier_a_plus_prompt_summary_lines: 8 occurs $n_ta times (expected 1)"
fi

echo "SUMMARY: m031-p01-config-knobs-stable.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
