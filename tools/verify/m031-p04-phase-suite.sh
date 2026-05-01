#!/usr/bin/env bash
# tools/verify/m031-p04-phase-suite.sh -- M031 P04 phase-close gate suite.
#
# Aggregates all P04 sub-gates (T01 + T02 + T03 + T04 + T05) for the
# right-sized-entry milestone (M031) close phase and emits a single
# aggregate SUMMARY line. Mirrors the m031-p01/p02/p03-phase-suite.sh
# straight-line patterns (AD-19 compliant -- no array loops, no
# compound chains, no eval).
#
# Sub-gates (in T01 -> T02 -> T03 -> T04 -> T05 dependency order):
#    1.  m031-p04-evaluate-md-drift-shape.sh           (T01 evaluate.md drift gate)
#    2.  m031-p04-tier-definitions-drift-shape.sh      (T01 tier-definitions.md drift gate)
#    3.  m031-p04-auto-proceed-default-shape.sh        (T01 auto_proceed default gate)
#    4.  m031-p04-changelog-shape.sh                   (T01 CHANGELOG entry gate)
#    5.  m031-p04-test-doc-drift-shape.sh              (T01 SC-9 shape gate)
#    6.  m031-p04-test-auto-proceed-shape.sh           (T01 SC-10 shape gate)
#    7.  m031-p04-doctor-compound-change-shape.sh      (T02 doctor amendment gate)
#    8.  m031-p04-test-doctor-compound-change-shape.sh (T02 AD-9 shape gate)
#    9.  m031-p04-budget-drift-shape.sh                (T03 efficiency-footer amendment gate)
#   10.  m031-p04-test-budget-drift-shape.sh           (T03 AD-19 shape gate)
#   11.  m031-p04-test-scope-guard-shape.sh            (T04 milestone-scope-guard shape gate)
#   12.  m031-p04-battery-shape.sh                     (T04 battery aggregator shape gate)
#   13.  m031-p04-evidence-ledger-shape.sh             (T04 verifier; gates T05's ledger)
#   14.  m031-p04-scope-guard.sh                       (T05 phase-grain scope-guard; last)
#
# Each sub-gate's own SUMMARY line is preserved on stdout for
# diagnostics; the suite emits a single aggregate SUMMARY line at the
# end and exits 0 iff every sub-gate exits 0. The suite does NOT
# short-circuit on a sub-gate failure; all 14 gates run regardless so
# the operator sees the full report.
#
# The suite reads each gate's exit code; it does NOT parse SUMMARY
# lines (parsing would couple the suite to envelope formatting; exit
# codes are the load-bearing contract -- mirrors P01/P02/P03).
#
# Bash 3.2 compatible. Straight-line invocation per AD-19 -- no loops
# over arrays, no compound chains, no eval. Fourteen literal `bash <path>`
# invocations followed by accumulator updates. Mirrors the M031/P03
# phase-suite pattern from `tools/verify/m031-p03-phase-suite.sh`.
#
# Key links (M031/P04):
#   - m031-p04-evaluate-md-drift-shape.sh         (T01 evaluate.md drift gate)
#   - m031-p04-tier-definitions-drift-shape.sh    (T01 tier-definitions.md drift gate)
#   - m031-p04-auto-proceed-default-shape.sh      (T01 auto_proceed default gate)
#   - m031-p04-changelog-shape.sh                 (T01 CHANGELOG entry gate)
#   - m031-p04-test-doc-drift-shape.sh            (T01 SC-9 shape gate)
#   - m031-p04-test-auto-proceed-shape.sh         (T01 SC-10 shape gate)
#   - m031-p04-doctor-compound-change-shape.sh    (T02 doctor amendment gate)
#   - m031-p04-test-doctor-compound-change-shape.sh (T02 AD-9 shape gate)
#   - m031-p04-budget-drift-shape.sh              (T03 efficiency-footer amendment gate)
#   - m031-p04-test-budget-drift-shape.sh         (T03 AD-19 shape gate)
#   - m031-p04-test-scope-guard-shape.sh          (T04 milestone-scope-guard shape gate)
#   - m031-p04-battery-shape.sh                   (T04 battery aggregator shape gate)
#   - m031-p04-evidence-ledger-shape.sh           (T04 evidence-ledger shape gate; gates T05 artifact)
#   - m031-p04-scope-guard.sh                     (T05 phase-grain scope-guard; last)

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

# ---------- Gate 1: evaluate-md-drift-shape (T01) ----------

bash tools/verify/m031-p04-evaluate-md-drift-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-evaluate-md-drift-shape.sh"

# ---------- Gate 2: tier-definitions-drift-shape (T01) ----------

bash tools/verify/m031-p04-tier-definitions-drift-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-tier-definitions-drift-shape.sh"

# ---------- Gate 3: auto-proceed-default-shape (T01) ----------

bash tools/verify/m031-p04-auto-proceed-default-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-auto-proceed-default-shape.sh"

# ---------- Gate 4: changelog-shape (T01) ----------

bash tools/verify/m031-p04-changelog-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-changelog-shape.sh"

# ---------- Gate 5: test-doc-drift-shape (T01) ----------

bash tools/verify/m031-p04-test-doc-drift-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-test-doc-drift-shape.sh"

# ---------- Gate 6: test-auto-proceed-shape (T01) ----------

bash tools/verify/m031-p04-test-auto-proceed-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-test-auto-proceed-shape.sh"

# ---------- Gate 7: doctor-compound-change-shape (T02) ----------

bash tools/verify/m031-p04-doctor-compound-change-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-doctor-compound-change-shape.sh"

# ---------- Gate 8: test-doctor-compound-change-shape (T02) ----------

bash tools/verify/m031-p04-test-doctor-compound-change-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-test-doctor-compound-change-shape.sh"

# ---------- Gate 9: budget-drift-shape (T03) ----------

bash tools/verify/m031-p04-budget-drift-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-budget-drift-shape.sh"

# ---------- Gate 10: test-budget-drift-shape (T03) ----------

bash tools/verify/m031-p04-test-budget-drift-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-test-budget-drift-shape.sh"

# ---------- Gate 11: test-scope-guard-shape (T04) ----------

bash tools/verify/m031-p04-test-scope-guard-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-test-scope-guard-shape.sh"

# ---------- Gate 12: battery-shape (T04) ----------

bash tools/verify/m031-p04-battery-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-battery-shape.sh"

# ---------- Gate 13: evidence-ledger-shape (T04 verifier; gates T05 artifact) ----------

bash tools/verify/m031-p04-evidence-ledger-shape.sh
rc=$?
emit_gate_result "$rc" "m031-p04-evidence-ledger-shape.sh"

# ---------- Gate 14: scope-guard (T05; last) ----------

bash tools/verify/m031-p04-scope-guard.sh
rc=$?
emit_gate_result "$rc" "m031-p04-scope-guard.sh"

# ---------- Aggregate summary ----------

printf 'SUMMARY: m031-p04-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
else
    exit 1
fi
