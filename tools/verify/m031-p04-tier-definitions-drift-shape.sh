#!/usr/bin/env bash
# tools/verify/m031-p04-tier-definitions-drift-shape.sh
#
# M031/P04/T01 shape verifier (project-owned, slug-bearing under
# tools/verify/) for references/tier-definitions.md drift fix
# (FR-15 / SC-9).
#
# Asserts:
#   1) references/tier-definitions.md exists.
#   2) Zero matches for "no orchestrator overhead" (pre-M024 phrasing).
#   3) Canonical Tier A descriptor "Quick profile" present.
#   4) ".orchestrator/" literal present (the always-present statement
#      naming knowledge / config / integrations as unconditional, with
#      only milestones/M###/ scaffolding conditional on Tier B/C).
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

target="$PROJECT_ROOT/references/tier-definitions.md"

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
    ok "references/tier-definitions.md exists at $target"
else
    ng "references/tier-definitions.md missing at $target"
    printf 'SUMMARY: m031-p04-tier-definitions-drift-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
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

check_absent  "no orchestrator overhead"  "no orchestrator overhead"
check_literal "Quick profile"             "Quick profile"
check_literal ".orchestrator/"            ".orchestrator/"

printf 'SUMMARY: m031-p04-tier-definitions-drift-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
