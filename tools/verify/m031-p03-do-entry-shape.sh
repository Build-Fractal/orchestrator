#!/usr/bin/env bash
# tools/verify/m031-p03-do-entry-shape.sh
#
# M031/P03/T01 shape verifier (project-owned, slug-bearing under
# tools/verify/) for scripts/intake/do-entry.sh.
#
# Asserts:
#   1) scripts/intake/do-entry.sh exists, is executable, and is >= 200 lines.
#   2) the file body contains required literal substrings:
#        - tier_a_plus
#        - shape-detect.sh
#        - route-to-dispatch.sh
#        - build-context.sh
#        - entry_routing_confidence_floor
#        - --task
#        - --yes
#        - --no-prompt-mode
#        - --dispatch-stub
#        - --scratch-root
#        - --config
#        - chosen_shape
#        - MEMs
#        - tokens
#   3) the file does NOT contain `declare -A` (MEM001).
#   4) the file does NOT contain `<(` (process substitution forbidden by MEM001).
#   5) the file does NOT contain forbidden invocation tokens (CON-4):
#        - orchestrator:auto
#        - orchestrator:roadmap
#        - orchestrator:consolidate
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/intake/do-entry.sh"

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
    ok "do-entry.sh exists at $target"
else
    ng "do-entry.sh missing at $target"
    printf 'SUMMARY: m031-p03-do-entry-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

if [ -x "$target" ]; then
    ok "do-entry.sh is executable"
else
    ng "do-entry.sh is not executable"
fi

target_lines=$(awk 'END {print NR}' "$target")
if [ "$target_lines" -ge 200 ]; then
    ok "do-entry.sh has $target_lines lines (>= 200)"
else
    ng "do-entry.sh has $target_lines lines (< 200)"
fi

# 2) Required literal substrings.
check_literal() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ok "$label literal present"
    else
        ng "$label literal missing ($needle)"
    fi
}

check_literal "tier_a_plus" "tier_a_plus"
check_literal "shape-detect.sh" "shape-detect.sh"
check_literal "route-to-dispatch.sh" "route-to-dispatch.sh"
check_literal "build-context.sh" "build-context.sh"
check_literal "entry_routing_confidence_floor" "entry_routing_confidence_floor"
check_literal "--task" "--task"
check_literal "--yes" "--yes"
check_literal "--no-prompt-mode" "--no-prompt-mode"
check_literal "--dispatch-stub" "--dispatch-stub"
check_literal "--scratch-root" "--scratch-root"
check_literal "--config" "--config"
check_literal "chosen_shape" "chosen_shape"
check_literal "MEMs" "MEMs"
check_literal "tokens" "tokens"

# 3) Forbidden bash 3.2 incompatibilities.
check_absent() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ng "$label forbidden token present ($needle)"
    else
        ok "$label forbidden token absent"
    fi
}

check_absent "declare -A" "declare -A"
check_absent "process substitution" "<("

# 5) Forbidden CON-4 invocation tokens.
check_absent "orchestrator:auto" "orchestrator:auto"
check_absent "orchestrator:roadmap" "orchestrator:roadmap"
check_absent "orchestrator:consolidate" "orchestrator:consolidate"

printf 'SUMMARY: m031-p03-do-entry-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
