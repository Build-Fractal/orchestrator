#!/usr/bin/env bash
# tests/m029-acceptance/p02-acceptance-battery.sh -- M029 P02 acceptance battery (SC-11 slice).
#
# Chains the four P02 SC acceptance scripts in dependency order and emits a
# single aggregate BATTERY: line. This is the P02 slice of SC-11 (M029
# acceptance battery); the full battery covering all 14 success criteria
# lands in P03 at `tests/m029-acceptance/run-acceptance-battery.sh`.
#
# Sub-scripts (in order):
#   1. p02-sc5-where-mixed-state.sh -- SC-5 where mixed-state golden (FR-5)
#   2. p02-sc6-where-pre-m019.sh    -- SC-6 pre-M019 cost-column suppression (FR-6 / CON-3)
#   3. p02-sc13-anti-coupling.sh    -- SC-13 GitHub anti-coupling (FR-11 / CON-4)
#   4. p02-sc14-readonly.sh         -- SC-14 read-only invariant via sentinel harness (AD-9 / CON-1 / FR-14)
#
# Each sub-script's own stdout (per-assertion PASS/FAIL + final SUMMARY-style
# line) is preserved on this script's stdout for diagnostics. The battery
# emits the aggregate `BATTERY: p02-acceptance pass=N fail=M` line at the
# end and exits 0 iff every sub-script exits 0.
#
# Re-used by validate-milestone.sh M029 (P03 deliverable) alongside the P01
# and P03 batteries.
#
# Bash 3.2 / MEM001. AD-19 straight-line bash -- no loops over arrays, no
# compound chains, no eval. Mirrors tests/m029-acceptance/p01-acceptance-battery.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

_run_sc() {
    label="$1"
    script="$2"
    bash "$script"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        pass=$(( pass + 1 ))
        printf 'OK: %s\n' "$label"
    else
        fail=$(( fail + 1 ))
        printf 'FAIL: %s (rc=%d)\n' "$label" "$rc"
    fi
}

# ---------- SC-5: where mixed-state golden ----------

_run_sc "SC-5 p02-sc5-where-mixed-state.sh" "$PROJECT_ROOT/tests/m029-acceptance/p02-sc5-where-mixed-state.sh"

# ---------- SC-6: pre-M019 cost-column suppression ----------

_run_sc "SC-6 p02-sc6-where-pre-m019.sh" "$PROJECT_ROOT/tests/m029-acceptance/p02-sc6-where-pre-m019.sh"

# ---------- SC-13: GitHub anti-coupling ----------

_run_sc "SC-13 p02-sc13-anti-coupling.sh" "$PROJECT_ROOT/tests/m029-acceptance/p02-sc13-anti-coupling.sh"

# ---------- SC-14: read-only invariant ----------

_run_sc "SC-14 p02-sc14-readonly.sh" "$PROJECT_ROOT/tests/m029-acceptance/p02-sc14-readonly.sh"

# ---------- Aggregate ----------

printf 'BATTERY: p02-acceptance pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
