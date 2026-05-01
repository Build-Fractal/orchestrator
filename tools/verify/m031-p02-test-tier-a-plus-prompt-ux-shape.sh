#!/usr/bin/env bash
# tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh
#
# M031/P02/T03 shape verifier (project-owned, slug-bearing under
# tools/verify/) for tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh.
#
# Asserts:
#   1) the SC-16 acceptance script exists, is executable, and is
#      >= 60 lines.
#   2) the script body carries the literal substrings:
#        - SC-16
#        - AD-20
#        - tier_a_plus_prompt_summary_lines
#        - (N more lines at
#        - --yes
#        - (y) plan
#        - (n) re-run
#        - (c) abort
#        - research:
#
# Single-script Truth Check shape per AD-19. Bash 3.2 compatible.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh"

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

# 1) Existence + executability + line count.
if [ -f "$target" ]; then
    ok "SC-16 script exists at $target"
else
    ng "SC-16 script missing at $target"
    printf 'SUMMARY: m031-p02-test-tier-a-plus-prompt-ux-shape.sh pass=%d fail=%d\n' \
        "$pass" "$fail"
    exit 1
fi

if [ -x "$target" ]; then
    ok "SC-16 script is executable"
else
    ng "SC-16 script is not executable"
fi

target_lines=$(awk 'END {print NR}' "$target")
if [ "$target_lines" -ge 60 ]; then
    ok "SC-16 script has $target_lines lines (>= 60)"
else
    ng "SC-16 script has $target_lines lines (< 60 floor)"
fi

# 2) Required literal substring contracts.
for lit in 'SC-16' 'AD-20' 'tier_a_plus_prompt_summary_lines' '(N more lines at' '--yes' '(y) plan' '(n) re-run' '(c) abort' 'research:'; do
    if grep -F -q -e "$lit" "$target"; then
        ok "SC-16 script contains required literal: $lit"
    else
        ng "SC-16 script missing required literal: $lit"
    fi
done

printf 'SUMMARY: m031-p02-test-tier-a-plus-prompt-ux-shape.sh pass=%d fail=%d\n' \
    "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
