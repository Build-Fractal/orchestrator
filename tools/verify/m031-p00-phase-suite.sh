#!/usr/bin/env bash
# tools/verify/p00-phase-suite.sh — M031 P00 phase-close gate suite.
#
# Aggregates all nine P00 verifiers from T01 + T02 + T03 of the
# right-sized-entry milestone (M031) and emits a single aggregate
# SUMMARY line.
#
# Sub-gates (in order):
#   1. p00-spec-foldin-shape.sh                (T01)
#   2. p00-corpus-manifest-shape.sh            (T02)
#   3. p00-corpus-population.sh                (T02)
#   4. p00-pre-stub-shape.sh                   (T02)
#   5. p00-runtime-assumptions-foldin.sh       (T02)
#   6. p00-config-defaults-pinned.sh           (T02)
#   7. p00-baseline-harness-shape.sh           (T03)
#   8. p00-ordering-verifier-shape.sh          (T03)
#   9. p00-pre-baseline-jsonl-population.sh    (T03)
#
# Each sub-gate's own SUMMARY line is preserved on stdout for
# diagnostics; the suite emits a single aggregate SUMMARY line at the
# end and exits 0 iff every sub-gate exits 0.
#
# Note: future maintainers extending P00 with additional gates MUST
# add the new verifier to this gate list AND update the expected
# `SUMMARY: pass=N` count in the T03 task plan's expected output.
#
# Bash 3.2 compatible. Straight-line invocation per AD-19 — no loops
# over arrays, no compound chains, no eval. Nine literal `bash <path>`
# invocations followed by accumulator updates.

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
        printf 'FAIL: %s\n' "$name"
    fi
}

# ---------- Gate 1: spec-foldin-shape (T01) ----------

bash tools/verify/p00-spec-foldin-shape.sh
rc=$?
emit_gate_result "$rc" "p00-spec-foldin-shape.sh"

# ---------- Gate 2: corpus-manifest-shape (T02) ----------

bash tools/verify/p00-corpus-manifest-shape.sh
rc=$?
emit_gate_result "$rc" "p00-corpus-manifest-shape.sh"

# ---------- Gate 3: corpus-population (T02) ----------

bash tools/verify/p00-corpus-population.sh
rc=$?
emit_gate_result "$rc" "p00-corpus-population.sh"

# ---------- Gate 4: pre-stub-shape (T02) ----------

bash tools/verify/p00-pre-stub-shape.sh
rc=$?
emit_gate_result "$rc" "p00-pre-stub-shape.sh"

# ---------- Gate 5: runtime-assumptions-foldin (T02) ----------

bash tools/verify/p00-runtime-assumptions-foldin.sh
rc=$?
emit_gate_result "$rc" "p00-runtime-assumptions-foldin.sh"

# ---------- Gate 6: config-defaults-pinned (T02) ----------

bash tools/verify/p00-config-defaults-pinned.sh
rc=$?
emit_gate_result "$rc" "p00-config-defaults-pinned.sh"

# ---------- Gate 7: baseline-harness-shape (T03) ----------

bash tools/verify/p00-baseline-harness-shape.sh
rc=$?
emit_gate_result "$rc" "p00-baseline-harness-shape.sh"

# ---------- Gate 8: ordering-verifier-shape (T03) ----------

bash tools/verify/p00-ordering-verifier-shape.sh
rc=$?
emit_gate_result "$rc" "p00-ordering-verifier-shape.sh"

# ---------- Gate 9: pre-baseline-jsonl-population (T03) ----------

bash tools/verify/p00-pre-baseline-jsonl-population.sh
rc=$?
emit_gate_result "$rc" "p00-pre-baseline-jsonl-population.sh"

# ---------- Aggregate summary ----------

printf 'SUMMARY: p00-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
else
    exit 1
fi
