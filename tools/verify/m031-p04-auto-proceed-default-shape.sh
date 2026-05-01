#!/usr/bin/env bash
# tools/verify/m031-p04-auto-proceed-default-shape.sh
#
# M031/P04/T01 shape verifier for templates/orchestrator-config-default.yml
# auto_proceed default flip (FR-16 / AD-8 / Truth #3).
#
# Asserts:
#   1) templates/orchestrator-config-default.yml exists.
#   2) "auto_proceed: true" literal present at the start of a line.
#   3) "M031" literal present (comment block names the flip's owner).
#   4) "quick_knowledge_token_budget" literal present (the M031
#      Quick-profile knowledge ceiling knob is co-located so the doctor
#      compound-change comms surface can grep both literals as a single
#      block per AD-9).
#
# AD-19 single-script-file shape. Bash 3.2 + MEM001 compatible.
#
# Output: per-check PASS/FAIL lines + final SUMMARY: line.
# Exit 0 iff fail=0.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

target="$PROJECT_ROOT/templates/orchestrator-config-default.yml"

pass=0
fail=0

ok() {
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$1"
}
ng() {
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n' "$1"
}

# 1) Existence.
if [ -f "$target" ]; then
    ok "orchestrator-config-default.yml exists"
else
    ng "orchestrator-config-default.yml missing at $target"
    printf 'SUMMARY: m031-p04-auto-proceed-default-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2) auto_proceed: true at line start (the active default, not just a
#    commented mention).
if grep -qE '^auto_proceed: true' "$target"; then
    ok "auto_proceed: true at line start"
else
    ng "auto_proceed: true not at line start (default may not be flipped)"
fi

check_literal() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ok "$label literal present"
    else
        ng "$label literal missing ($needle)"
    fi
}

check_literal "M031"                         "M031"
check_literal "quick_knowledge_token_budget" "quick_knowledge_token_budget"

printf 'SUMMARY: m031-p04-auto-proceed-default-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
