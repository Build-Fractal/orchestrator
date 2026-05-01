#!/usr/bin/env bash
# tools/verify/m031-p04-evaluate-md-drift-shape.sh
#
# M031/P04/T01 shape verifier (project-owned, slug-bearing under
# tools/verify/) for commands/evaluate.md drift fix (FR-14 / SC-9).
#
# Asserts:
#   1) commands/evaluate.md exists.
#   2) Zero matches for "no orchestrator overhead" (pre-M024 phrasing).
#   3) Zero matches for "Do NOT create any orchestrator directory"
#      (pre-M024 phrasing — the FR-003 self-citation block was the
#      load-bearing leak the M031 P04 drift fix closed).
#   4) Canonical Tier A descriptor "Quick profile" present.
#
# AD-19 single-script-file shape: no inline compound bash, no process
# substitution, no plain subshells in the verifier body. Bash 3.2 +
# MEM001 compatible.
#
# Output: per-check PASS/FAIL lines + final SUMMARY: line.
# Exit 0 iff fail=0.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

target="$PROJECT_ROOT/commands/evaluate.md"

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
    ok "commands/evaluate.md exists at $target"
else
    ng "commands/evaluate.md missing at $target"
    printf 'SUMMARY: m031-p04-evaluate-md-drift-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

check_absent() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ng "$label still present (drift not fixed)"
    else
        ok "$label absent"
    fi
}

check_literal() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ok "$label literal present"
    else
        ng "$label literal missing ($needle)"
    fi
}

check_absent  "no orchestrator overhead"                "no orchestrator overhead"
check_absent  "Do NOT create any orchestrator directory" "Do NOT create any orchestrator directory"
check_literal "Quick profile"                           "Quick profile"

printf 'SUMMARY: m031-p04-evaluate-md-drift-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
