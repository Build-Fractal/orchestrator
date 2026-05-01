#!/usr/bin/env bash
# tools/verify/m031-p02-router-shape.sh
#
# M031/P02/T04 shape verifier (project-owned, slug-bearing under
# tools/verify/) for scripts/intake/route-to-dispatch.sh.
#
# Asserts:
#   1) the router exists, is executable, and is >= 100 lines (the pre-T04
#      54-line baseline plus the new Tier A+ chain logic).
#   2) the router body contains the required literal substrings:
#        - tier_a_plus
#        - tier_a_plus_role
#        - aborted
#        - research
#        - plan
#        - build
#        - --profile=quick
#        - task-slug.sh
#        - tier-a-plus-prompt.sh
#   3) the router body does NOT contain forbidden invocation tokens
#      (CON-4 / DC-4 / Principle XIV grep -- the router MUST NOT
#      invoke any of these three commands):
#        - orchestrator:auto
#        - orchestrator:roadmap
#        - orchestrator:consolidate
#   4) the router does NOT introduce any
#        mkdir -p .orchestrator/milestones/
#      line (no milestone scaffolding write).
#   5) the router does NOT introduce any
#        .orchestrator/auto/
#      lock-file write surface.
#   6) the router does NOT embed the CON-7 scaffold-placeholder
#      bracket-TODO byte pattern (D020 token hygiene).
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19. No
# mapfile/readarray, no declare -A, no process substitution, no $()
# pipes inside conditionals.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/intake/route-to-dispatch.sh"

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
    ok "route-to-dispatch.sh exists at $target"
else
    ng "route-to-dispatch.sh missing at $target"
    printf 'SUMMARY: m031-p02-router-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

if [ -x "$target" ]; then
    ok "route-to-dispatch.sh is executable"
else
    ng "route-to-dispatch.sh is not executable"
fi

target_lines=$(awk 'END {print NR}' "$target")
if [ "$target_lines" -ge 100 ]; then
    ok "route-to-dispatch.sh has $target_lines lines (>= 100)"
else
    ng "route-to-dispatch.sh has $target_lines lines (< 100 floor)"
fi

# 2) Required literal substrings.
for lit in 'tier_a_plus' 'tier_a_plus_role' 'aborted' 'research' 'plan' 'build' '--profile=quick' 'task-slug.sh' 'tier-a-plus-prompt.sh'; do
    if grep -F -q -e "$lit" "$target"; then
        ok "router contains required literal: $lit"
    else
        ng "router missing required literal: $lit"
    fi
done

# 3) Forbidden invocation tokens (CON-4 / DC-4).
for forbidden in 'orchestrator:auto' 'orchestrator:roadmap' 'orchestrator:consolidate'; do
    if grep -F -q -e "$forbidden" "$target"; then
        ng "router contains forbidden literal: $forbidden"
    else
        ok "router clean of forbidden literal: $forbidden"
    fi
done

# 4) No milestone scaffolding write.
if grep -E -q 'mkdir -p [^ ]*\.orchestrator/milestones/' "$target"; then
    ng "router contains forbidden 'mkdir -p .orchestrator/milestones/' write"
else
    ok "router clean of milestone scaffolding write"
fi

# 5) No auto-loop lock-file write surface.
if grep -F -q '.orchestrator/auto/' "$target"; then
    ng "router references forbidden .orchestrator/auto/ lock surface"
else
    ok "router clean of .orchestrator/auto/ lock surface"
fi

# 6) D020 / CON-7 scaffold-placeholder byte pattern hygiene. Pattern
# constructed via printf so this verifier source itself does not
# embed the prohibited literal.
verifier_scaffold=$(printf '\133TODO: ')
if grep -F -q "$verifier_scaffold" "$target"; then
    ng "router contains forbidden CON-7 scaffold-placeholder byte pattern"
else
    ok "router clean of CON-7 scaffold-placeholder byte pattern"
fi

printf 'SUMMARY: m031-p02-router-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
