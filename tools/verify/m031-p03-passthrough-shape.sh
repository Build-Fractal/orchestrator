#!/usr/bin/env bash
# tools/verify/m031-p03-passthrough-shape.sh
#
# M031/P03/T01 shape verifier (project-owned, slug-bearing under
# tools/verify/) for the Tier B/C passthrough branch in
# scripts/intake/do-entry.sh (FR-13) and the no-state-machine /
# no-auto-loop / no-scaffolding-write invariants (CON-4 / Truth #4).
#
# Asserts:
#   1) the file contains the literal substrings `orchestrator:specify` AND
#      `orchestrator:evaluate` (FR-13 passthrough surface names).
#   2) the file contains the literal substring `route=tier_bc` (passthrough
#      stderr line key).
#   3) the file contains a function definition `run_tier_bc_passthrough`.
#   4) the file does NOT contain `orchestrator:auto`, `orchestrator:roadmap`,
#      or `orchestrator:consolidate` (CON-4).
#   5) the file does NOT contain a `mkdir -p .orchestrator/milestones/` write
#      (no milestone scaffolding).
#   6) the file does NOT contain a `.orchestrator/auto/` lock-file write.
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

# 0) File exists.
if [ -f "$target" ]; then
    ok "do-entry.sh exists at $target"
else
    ng "do-entry.sh missing at $target"
    printf 'SUMMARY: m031-p03-passthrough-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 1) FR-13 passthrough surface names.
if grep -qF "orchestrator:specify" "$target"; then
    ok "orchestrator:specify literal present"
else
    ng "orchestrator:specify literal missing"
fi
if grep -qF "orchestrator:evaluate" "$target"; then
    ok "orchestrator:evaluate literal present"
else
    ng "orchestrator:evaluate literal missing"
fi

# 2) route=tier_bc stderr key.
if grep -qF "route=tier_bc" "$target"; then
    ok "route=tier_bc passthrough key present"
else
    ng "route=tier_bc passthrough key missing"
fi

# 3) run_tier_bc_passthrough function definition.
if grep -qE '^run_tier_bc_passthrough[[:space:]]*\(\)' "$target"; then
    ok "run_tier_bc_passthrough function definition present"
else
    ng "run_tier_bc_passthrough function definition missing"
fi

# 4) Forbidden CON-4 invocation tokens.
check_absent() {
    local label="$1"
    local needle="$2"
    if grep -qF "$needle" "$target"; then
        ng "$label forbidden token present ($needle)"
    else
        ok "$label forbidden token absent"
    fi
}

check_absent "orchestrator:auto" "orchestrator:auto"
check_absent "orchestrator:roadmap" "orchestrator:roadmap"
check_absent "orchestrator:consolidate" "orchestrator:consolidate"

# 5) No milestone scaffolding write.
if grep -qE 'mkdir -p[[:space:]]+\.orchestrator/milestones/' "$target"; then
    ng "milestone scaffolding write present (mkdir -p .orchestrator/milestones/)"
else
    ok "no milestone scaffolding write"
fi

# 6) No auto-loop lock file write.
if grep -qF ".orchestrator/auto/" "$target"; then
    ng "auto-loop lock file path present (.orchestrator/auto/)"
else
    ok "no auto-loop lock file path"
fi

printf 'SUMMARY: m031-p03-passthrough-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
