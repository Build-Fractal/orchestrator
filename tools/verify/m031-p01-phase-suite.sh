#!/usr/bin/env bash
# tools/verify/m031-p01-phase-suite.sh — M031 P01 phase-close gate suite.
#
# Aggregates all nine P01 sub-gates from T01 + T02 + T03 of the
# right-sized-entry milestone (M031) and emits a single aggregate
# SUMMARY line.
#
# Sub-gates (in order; matches T01 -> T02 -> T03 dependency order):
#   1. m031-p01-build-context-profile-shape.sh        (T01)
#   2. m031-p01-quick-no-skip-branch.sh               (T01)
#   3. m031-p01-config-knobs-stable.sh                (T01)
#   4. m031-p01-dispatch-md-reconciliation.sh         (T02)
#   5. m031-p01-post-baseline-jsonl-population.sh     (T02)
#   6. m031-p01-test-quick-injects-knowledge-shape.sh (T03)
#   7. m031-p01-test-build-context-profile-shape.sh   (T03)
#   8. m031-p01-test-compression-applies-to-quick-shape.sh (T03)
#   9. m031-p01-test-quick-budget-median-shape.sh     (T03)
#
# Each sub-gate's own SUMMARY line is preserved on stdout for
# diagnostics; the suite emits a single aggregate SUMMARY line at the
# end and exits 0 iff every sub-gate exits 0. The suite does NOT
# short-circuit on a sub-gate failure; all nine gates run regardless
# so the operator sees the full report.
#
# The suite reads each gate's exit code; it does NOT parse SUMMARY
# lines (parsing would couple the suite to envelope formatting; exit
# codes are the load-bearing contract).
#
# Note: future maintainers extending P01 with additional gates MUST
# add the new verifier to this gate list AND update the expected
# `SUMMARY: pass=N` count in the T04 task plan's expected output.
#
# Bash 3.2 compatible. Straight-line invocation per AD-19 -- no loops
# over arrays, no compound chains, no eval. Nine literal `bash <path>`
# invocations followed by accumulator updates. Mirrors the P00
# phase-suite pattern from `tools/verify/p00-phase-suite.sh`.

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

# ---------- Gate 1: build-context-profile-shape (T01) ----------

bash tools/verify/m031-p01-build-context-profile-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p01-build-context-profile-shape.sh"

# ---------- Gate 2: quick-no-skip-branch (T01) ----------

bash tools/verify/m031-p01-quick-no-skip-branch.sh
rc=$?
emit_gate_result "$rc" "m031-p01-quick-no-skip-branch.sh"

# ---------- Gate 3: config-knobs-stable (T01) ----------

bash tools/verify/m031-p01-config-knobs-stable.sh
rc=$?
emit_gate_result "$rc" "m031-p01-config-knobs-stable.sh"

# ---------- Gate 4: dispatch-md-reconciliation (T02) ----------

bash tools/verify/m031-p01-dispatch-md-reconciliation.sh
rc=$?
emit_gate_result "$rc" "m031-p01-dispatch-md-reconciliation.sh"

# ---------- Gate 5: post-baseline-jsonl-population (T02) ----------

bash tools/verify/m031-p01-post-baseline-jsonl-population.sh
rc=$?
emit_gate_result "$rc" "m031-p01-post-baseline-jsonl-population.sh"

# ---------- Gate 6: test-quick-injects-knowledge-shape (T03) ----------

bash tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p01-test-quick-injects-knowledge-shape.sh"

# ---------- Gate 7: test-build-context-profile-shape (T03) ----------

bash tools/verify/m031-p01-test-build-context-profile-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p01-test-build-context-profile-shape.sh"

# ---------- Gate 8: test-compression-applies-to-quick-shape (T03) ----------

bash tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p01-test-compression-applies-to-quick-shape.sh"

# ---------- Gate 9: test-quick-budget-median-shape (T03) ----------

bash tools/verify/m031-p01-test-quick-budget-median-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p01-test-quick-budget-median-shape.sh"

# ---------- Aggregate summary ----------

printf 'SUMMARY: m031-p01-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
else
    exit 1
fi
