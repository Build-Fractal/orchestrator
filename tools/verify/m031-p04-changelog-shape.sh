#!/usr/bin/env bash
# tools/verify/m031-p04-changelog-shape.sh
#
# M031/P04/T01 shape verifier for CHANGELOG.md M031 entry
# (AD-9 CHANGELOG portion / Truth #4).
#
# Asserts the M031 entry under [Unreleased] names the compound
# behavioral change as a single co-located note (per AD-9, not two
# separate items): the auto_proceed default flip + the unconditional
# Quick-profile knowledge + compression injection.
#
# Required substrings:
#   - "M031"                          (entry heading names the milestone)
#   - "auto_proceed"                  (entry names the config knob)
#   - "quick_knowledge_token_budget"  (entry names the new Quick-profile knob)
#   - "compound"                      (entry frames the change as compound)
#
# AD-19 single-script-file shape. Bash 3.2 + MEM001 compatible.
#
# Output: per-check PASS/FAIL lines + final SUMMARY: line.
# Exit 0 iff fail=0.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

target="$PROJECT_ROOT/CHANGELOG.md"

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
    ok "CHANGELOG.md exists"
else
    ng "CHANGELOG.md missing at $target"
    printf 'SUMMARY: m031-p04-changelog-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
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

check_literal "M031 milestone heading"         "M031"
check_literal "auto_proceed knob"              "auto_proceed"
check_literal "quick_knowledge_token_budget knob" "quick_knowledge_token_budget"
check_literal "compound (single co-located note framing)" "compound"

printf 'SUMMARY: m031-p04-changelog-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
