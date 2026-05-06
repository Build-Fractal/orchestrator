#!/usr/bin/env bash
# tests/m029-acceptance/p03-acceptance-battery.sh -- M029 P03 acceptance battery (SC-7..SC-10 slice).
#
# Chains the four P03 SC acceptance scripts in dependency order and emits a
# single aggregate `BATTERY:` line. This is the P03 slice of the M029
# acceptance battery; the full battery covering all 14 success criteria
# lands in T06 at `tests/m029-acceptance/run-acceptance-battery.sh`.
#
# Sub-scripts (in order):
#   1. p03-sc7-live-tail.sh                  -- SC-7  live-tail latency + canonical compact savings marker
#   2. p03-sc8-auto-preflight.sh             -- SC-8  auto preflight predicted_cost byte-identity (AD-4 oracle wrapper)
#   3. p03-sc9-auto-quick-no-preflight.sh    -- SC-9  Quick intensity suppresses preflight
#   4. p03-sc10-auto-chain.sh                -- SC-10 --auto-chain marker writes + resume
#
# Each sub-script's own stdout (per-assertion PASS/FAIL + final SUMMARY-style
# line) is preserved on this script's stdout for diagnostics. The battery
# emits the aggregate `BATTERY: p03-acceptance pass=N fail=M` line at the
# end and exits 0 iff every sub-script exits 0.
#
# Re-used by tests/m029-acceptance/run-acceptance-battery.sh (T06 deliverable)
# alongside p01-acceptance-battery.sh + p02-acceptance-battery.sh.
#
# Bash 3.2 / MEM001. AD-19 straight-line bash -- no loops over arrays, no
# compound chains, no eval. Mirrors tests/m029-acceptance/p02-acceptance-battery.sh.

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

# ---------- SC-7: live-tail latency + canonical compact savings marker ----------

_run_sc "SC-7 p03-sc7-live-tail.sh" "$PROJECT_ROOT/tests/m029-acceptance/p03-sc7-live-tail.sh"

# ---------- SC-8: auto preflight predicted_cost byte-identity ----------

_run_sc "SC-8 p03-sc8-auto-preflight.sh" "$PROJECT_ROOT/tests/m029-acceptance/p03-sc8-auto-preflight.sh"

# ---------- SC-9: Quick intensity suppresses preflight ----------

_run_sc "SC-9 p03-sc9-auto-quick-no-preflight.sh" "$PROJECT_ROOT/tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh"

# ---------- SC-10: --auto-chain marker writes + resume ----------

_run_sc "SC-10 p03-sc10-auto-chain.sh" "$PROJECT_ROOT/tests/m029-acceptance/p03-sc10-auto-chain.sh"

# ---------- Aggregate ----------

printf 'BATTERY: p03-acceptance pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
