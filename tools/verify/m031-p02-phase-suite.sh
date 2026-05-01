#!/usr/bin/env bash
# tools/verify/m031-p02-phase-suite.sh -- M031 P02 phase-close gate suite.
#
# Aggregates all P02 sub-gates (T01 + T02 + T03 + T04 + T05) for the
# right-sized-entry milestone (M031) and emits a single aggregate
# SUMMARY line. Mirrors the m031-p01-phase-suite.sh straight-line
# pattern (AD-19 compliant -- no array loops, no compound chains).
#
# Sub-gates (in T01 -> T05 dependency order):
#    1. m031-p02-classifier-extension-shape.sh        (T01)
#    2. m031-p02-fixture-provenance-shape.sh          (T01)
#    3. m031-p02-tier-a-plus-input-shape.sh           (T01)
#    4. m031-p02-test-tier-a-plus-classifier-shape.sh (T01)
#    5. m031-p02-task-slug-shape.sh                   (T02)
#    6. m031-p02-role-templates-shape.sh              (T02)
#    7. m031-p02-prompt-shape.sh                      (T03)
#    8. m031-p02-test-tier-a-plus-prompt-ux-shape.sh  (T03)
#    9. m031-p02-router-shape.sh                      (T04)
#   10. m031-p02-test-tier-a-plus-flow-shape.sh       (T04)
#   11. m031-p02-scope-guard.sh                       (T05)
#
# Each sub-gate's own SUMMARY line is preserved on stdout for
# diagnostics; the suite emits a single aggregate SUMMARY line at the
# end and exits 0 iff every sub-gate exits 0. The suite does NOT
# short-circuit on a sub-gate failure; all eleven gates run regardless
# so the operator sees the full report.
#
# The suite reads each gate's exit code; it does NOT parse SUMMARY
# lines (parsing would couple the suite to envelope formatting; exit
# codes are the load-bearing contract).
#
# Note: future maintainers extending P02 with additional gates MUST
# add the new verifier to this gate list AND update the expected
# `SUMMARY: pass=N` count in downstream consumers (P04 acceptance-
# battery aggregator).
#
# Bash 3.2 compatible. Straight-line invocation per AD-19 -- no loops
# over arrays, no compound chains, no eval. Eleven literal `bash <path>`
# invocations followed by accumulator updates. Mirrors the M031/P01
# phase-suite pattern from `tools/verify/m031-p01-phase-suite.sh`.

set -u

pass=0
fail=0

emit_gate_result() {
    rc="$1"
    name="$2"
    if [ "$rc" -eq 0 ]; then
        pass=$(( pass + 1 ))
        printf 'OK: %s\n' "$name"
    else
        fail=$(( fail + 1 ))
        printf 'FAIL: %s rc=%s\n' "$name" "$rc"
    fi
}

# ---------- Gate 1: classifier-extension-shape (T01) ----------

bash tools/verify/m031-p02-classifier-extension-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p02-classifier-extension-shape.sh"

# ---------- Gate 2: fixture-provenance-shape (T01) ----------

bash tools/verify/m031-p02-fixture-provenance-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p02-fixture-provenance-shape.sh"

# ---------- Gate 3: tier-a-plus-input-shape (T01) ----------

bash tools/verify/m031-p02-tier-a-plus-input-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p02-tier-a-plus-input-shape.sh"

# ---------- Gate 4: test-tier-a-plus-classifier-shape (T01) ----------

bash tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p02-test-tier-a-plus-classifier-shape.sh"

# ---------- Gate 5: task-slug-shape (T02) ----------

bash tools/verify/m031-p02-task-slug-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p02-task-slug-shape.sh"

# ---------- Gate 6: role-templates-shape (T02) ----------

bash tools/verify/m031-p02-role-templates-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p02-role-templates-shape.sh"

# ---------- Gate 7: prompt-shape (T03) ----------

bash tools/verify/m031-p02-prompt-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p02-prompt-shape.sh"

# ---------- Gate 8: test-tier-a-plus-prompt-ux-shape (T03) ----------

bash tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p02-test-tier-a-plus-prompt-ux-shape.sh"

# ---------- Gate 9: router-shape (T04) ----------

bash tools/verify/m031-p02-router-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p02-router-shape.sh"

# ---------- Gate 10: test-tier-a-plus-flow-shape (T04) ----------

bash tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p02-test-tier-a-plus-flow-shape.sh"

# ---------- Gate 11: scope-guard (T05) ----------

bash tools/verify/m031-p02-scope-guard.sh
rc=$?
emit_gate_result "$rc" "m031-p02-scope-guard.sh"

# ---------- Aggregate summary ----------

printf 'SUMMARY: m031-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
else
    exit 1
fi
