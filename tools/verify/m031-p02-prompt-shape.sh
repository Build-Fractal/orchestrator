#!/usr/bin/env bash
# tools/verify/m031-p02-prompt-shape.sh
#
# M031/P02/T03 shape verifier (project-owned, slug-bearing under
# tools/verify/) for scripts/intake/lib/tier-a-plus-prompt.sh.
#
# Asserts:
#   1) the helper exists, is executable, and is >= 100 lines.
#   2) the helper body contains the required literal substrings:
#        - tier_a_plus_prompt_summary_lines  (config knob read)
#        - research:                         (audit-line emission)
#        - (y) plan against this research    (AD-20 option label)
#        - (n) re-run research with different framing
#        - (c) abort this Tier A+ flow
#        - --yes                             (skip-flag CLI surface)
#        - more lines at                     (ellipsis substring)
#   3) the prompt-printing region (delimited by the BEGIN PROMPT BODY
#      and END PROMPT BODY sentinels in the source) does NOT contain
#      the literal token `null`, the open-brace character, the
#      close-brace character, nor the CON-7 scaffold-placeholder
#      bracket-TODO byte pattern. The byte patterns for braces and
#      the scaffold-placeholder are constructed at runtime via
#      printf so this verifier source itself does not embed the
#      prohibited literals.
#   4) the helper file as a whole does NOT contain the CON-7
#      scaffold-placeholder bracket-TODO byte pattern in any
#      position (D020 token hygiene -- file-wide assertion).
#
# Single-script Truth Check shape per AD-19. Bash 3.2 compatible. No
# mapfile/readarray, no declare -A, no process substitution, no $()
# pipes inside conditionals.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/intake/lib/tier-a-plus-prompt.sh"

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
    ok "tier-a-plus-prompt.sh exists at $target"
else
    ng "tier-a-plus-prompt.sh missing at $target"
    printf 'SUMMARY: m031-p02-prompt-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

if [ -x "$target" ]; then
    ok "tier-a-plus-prompt.sh is executable"
else
    ng "tier-a-plus-prompt.sh is not executable"
fi

target_lines=$(awk 'END {print NR}' "$target")
if [ "$target_lines" -ge 100 ]; then
    ok "tier-a-plus-prompt.sh has $target_lines lines (>= 100)"
else
    ng "tier-a-plus-prompt.sh has $target_lines lines (< 100 floor)"
fi

# 2) Required literal substring contracts.
for lit in 'tier_a_plus_prompt_summary_lines' 'research:' '(y) plan against this research' '(n) re-run research with different framing' '(c) abort this Tier A+ flow' '--yes' 'more lines at'; do
    if grep -F -q -e "$lit" "$target"; then
        ok "tier-a-plus-prompt.sh contains required literal: $lit"
    else
        ng "tier-a-plus-prompt.sh missing required literal: $lit"
    fi
done

# 3) Prompt-printing region cleanliness. Extract the region between
# the BEGIN/END sentinels and assert the prohibited tokens do not
# appear there.
body_region="/tmp/m031-p02-t03-prompt-body-region.txt"
rm -f "$body_region"
awk '/# BEGIN PROMPT BODY/,/# END PROMPT BODY/' "$target" > "$body_region"

if [ -s "$body_region" ]; then
    ok "extracted non-empty prompt body region"
else
    ng "could not extract prompt body region (BEGIN/END sentinels missing or empty)"
fi

if grep -F -q 'null' "$body_region"; then
    ng "prompt body region contains forbidden literal 'null'"
else
    ok "prompt body region clean of literal 'null'"
fi

verifier_open_brace=$(printf '\173')
verifier_close_brace=$(printf '\175')

if grep -F -q "$verifier_open_brace" "$body_region"; then
    ng "prompt body region contains forbidden open-brace character"
else
    ok "prompt body region clean of open-brace character"
fi

if grep -F -q "$verifier_close_brace" "$body_region"; then
    ng "prompt body region contains forbidden close-brace character"
else
    ok "prompt body region clean of close-brace character"
fi

verifier_scaffold=$(printf '\133TODO: ')
if grep -F -q "$verifier_scaffold" "$body_region"; then
    ng "prompt body region contains forbidden CON-7 scaffold-placeholder byte pattern"
else
    ok "prompt body region clean of CON-7 scaffold-placeholder byte pattern"
fi

# 4) File-wide assertion: the scaffold-placeholder bracket-TODO byte
# pattern must not appear anywhere in the helper source (D020).
if grep -F -q "$verifier_scaffold" "$target"; then
    ng "tier-a-plus-prompt.sh contains forbidden CON-7 scaffold-placeholder byte pattern (file-wide)"
else
    ok "tier-a-plus-prompt.sh clean of CON-7 scaffold-placeholder byte pattern (file-wide)"
fi

rm -f "$body_region"

printf 'SUMMARY: m031-p02-prompt-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
