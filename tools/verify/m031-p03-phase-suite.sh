#!/usr/bin/env bash
# tools/verify/m031-p03-phase-suite.sh -- M031 P03 phase-close gate suite.
#
# Aggregates all P03 sub-gates (T01 + T02 + T03) for the right-sized-entry
# milestone (M031) universal-entry phase and emits a single aggregate
# SUMMARY line. Mirrors the m031-p01-phase-suite.sh + m031-p02-phase-
# suite.sh straight-line patterns (AD-19 compliant -- no array loops,
# no compound chains, no eval).
#
# Sub-gates (in T01 -> T02 -> T03 dependency order):
#    1. m031-p03-do-md-shape.sh                       (T01 do-md gate)
#    2. m031-p03-do-entry-shape.sh                    (T01 do-entry gate)
#    3. m031-p03-fastpath-shape.sh                    (T01 fastpath gate)
#    4. m031-p03-passthrough-shape.sh                 (T01 passthrough gate)
#    5. m031-p03-test-universal-entry-trivial-shape.sh (T02 SC-7 gate)
#    6. m031-p03-test-universal-entry-lowconf-shape.sh (T02 SC-8 gate)
#    7. m031-p03-scope-guard.sh                       (T03 scope-guard gate; last)
#
# Each sub-gate's own SUMMARY line is preserved on stdout for
# diagnostics; the suite emits a single aggregate SUMMARY line at the
# end and exits 0 iff every sub-gate exits 0. The suite does NOT
# short-circuit on a sub-gate failure; all seven gates run regardless
# so the operator sees the full report.
#
# The suite reads each gate's exit code; it does NOT parse SUMMARY
# lines (parsing would couple the suite to envelope formatting; exit
# codes are the load-bearing contract -- mirrors P01/P02).
#
# Note: future maintainers extending P03 with additional gates MUST
# add the new verifier to this gate list AND update the expected
# `SUMMARY: pass=N` count in downstream consumers (P04 acceptance-
# battery aggregator).
#
# Bash 3.2 compatible. Straight-line invocation per AD-19 -- no loops
# over arrays, no compound chains, no eval. Seven literal `bash <path>`
# invocations followed by accumulator updates. Mirrors the M031/P02
# phase-suite pattern from `tools/verify/m031-p02-phase-suite.sh`.
#
# Key links (M031/P03):
#   - m031-p03-do-md-shape.sh                       (T01 do-md gate)
#   - m031-p03-do-entry-shape.sh                    (T01 do-entry gate)
#   - m031-p03-fastpath-shape.sh                    (T01 fastpath gate)
#   - m031-p03-passthrough-shape.sh                 (T01 passthrough gate)
#   - m031-p03-test-universal-entry-trivial-shape.sh (T02 SC-7 gate)
#   - m031-p03-test-universal-entry-lowconf-shape.sh (T02 SC-8 gate)
#   - m031-p03-scope-guard.sh                       (T03 scope-guard gate; last)

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

# ---------- Gate 1: do-md-shape (T01) ----------

bash tools/verify/m031-p03-do-md-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p03-do-md-shape.sh"

# ---------- Gate 2: do-entry-shape (T01) ----------

bash tools/verify/m031-p03-do-entry-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p03-do-entry-shape.sh"

# ---------- Gate 3: fastpath-shape (T01) ----------

bash tools/verify/m031-p03-fastpath-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p03-fastpath-shape.sh"

# ---------- Gate 4: passthrough-shape (T01) ----------

bash tools/verify/m031-p03-passthrough-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p03-passthrough-shape.sh"

# ---------- Gate 5: test-universal-entry-trivial-shape (T02) ----------

bash tools/verify/m031-p03-test-universal-entry-trivial-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p03-test-universal-entry-trivial-shape.sh"

# ---------- Gate 6: test-universal-entry-lowconf-shape (T02) ----------

bash tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p03-test-universal-entry-lowconf-shape.sh"

# ---------- Gate 7: scope-guard (T03) ----------

bash tools/verify/m031-p03-scope-guard.sh
rc=$?
emit_gate_result "$rc" "m031-p03-scope-guard.sh"

# ---------- Aggregate summary ----------

printf 'SUMMARY: m031-p03-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
else
    exit 1
fi
