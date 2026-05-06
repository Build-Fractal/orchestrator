#!/usr/bin/env bash
# tests/m029-acceptance/p01-acceptance-battery.sh -- M029 P01 acceptance battery (SC-11 slice).
#
# Chains the four P01 SC acceptance scripts in dependency order and emits a
# single aggregate BATTERY: line. This is the P01 slice of SC-11 (M029
# acceptance battery); the full battery covering all 14 success criteria
# lands in P03 at `tests/m029-acceptance/run-acceptance-battery.sh`.
#
# Sub-scripts (in order):
#   1. p01-sc1-resolver.sh     -- SC-1 invocation-context resolver shape
#   2. p01-sc2-headline.sh     -- SC-2 status headline regex
#   3. p01-sc3-format-json.sh  -- SC-3 status --format=json schema
#   4. p01-sc4-context.sh      -- SC-4 commands/context.md skill
#
# Each sub-script's own stdout (per-assertion PASS/FAIL + final SUMMARY-style
# line) is preserved on this script's stdout for diagnostics. The battery
# emits the aggregate `BATTERY: p01-acceptance pass=N fail=M` line at the
# end and exits 0 iff every sub-script exits 0.
#
# Bash 3.2 compatible. Straight-line invocation per AD-19 -- no loops over
# arrays, no compound chains, no eval. Linear `bash <path>` invocations
# followed by accumulator updates. Mirrors tools/verify/m031-p00-phase-suite.sh.

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

# ---------- SC-1: invocation-context resolver ----------

_run_sc "SC-1 p01-sc1-resolver.sh" "$PROJECT_ROOT/tests/m029-acceptance/p01-sc1-resolver.sh"

# ---------- SC-2: status headline regex ----------

_run_sc "SC-2 p01-sc2-headline.sh" "$PROJECT_ROOT/tests/m029-acceptance/p01-sc2-headline.sh"

# ---------- SC-3: status --format=json schema ----------

_run_sc "SC-3 p01-sc3-format-json.sh" "$PROJECT_ROOT/tests/m029-acceptance/p01-sc3-format-json.sh"

# ---------- SC-4: commands/context.md skill ----------

_run_sc "SC-4 p01-sc4-context.sh" "$PROJECT_ROOT/tests/m029-acceptance/p01-sc4-context.sh"

# ---------- Aggregate ----------

printf 'BATTERY: p01-acceptance pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
