#!/usr/bin/env bash
# tools/verify/m029-p03-phase-suite.sh -- M029 P03 phase-close gate suite.
#
# Aggregates every P03 verifier from T01..T05 of the roadmap-visibility &
# CLI-UX milestone (M029). validate-milestone.sh M029 (T06 deliverable)
# consumes this suite alongside the P01 and P02 phase-suites + the full
# SC-1..SC-14 acceptance battery (run-acceptance-battery.sh).
#
# Sub-gates (in dependency order -- T01 design surfaces BEFORE downstream
# consumers, so an upstream failure short-circuits diagnostics):
#
#   T01 -- render-position --live + display_thresholds config knob:
#     1. m029-p03-render-position-live-shape.sh
#     2. m029-p03-display-thresholds-config-shape.sh
#
#   T02 -- commands/auto.md Preflight Summary section:
#     3. m029-p03-auto-preflight-shape.sh
#
#   T03 -- commands/start.md --auto-chain flag + chain-driver:
#     4. m029-p03-auto-chain-shape.sh
#
#   T04 -- live-tail latency harness + 4 SC acceptance shape verifiers:
#     5. m029-p03-measure-live-tail-latency-shape.sh
#     6. m029-p03-sc7-shape.sh
#     7. m029-p03-sc8-shape.sh
#     8. m029-p03-sc9-shape.sh
#     9. m029-p03-sc10-shape.sh
#
#   T05 -- close gates:
#    10. m029-p03-spec-amendment-shape.sh
#    11. m029-p03-acceptance-battery-shape.sh
#    12. m029-p03-readonly-invariant.sh
#    13. m029-p03-scope-guard.sh
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at the end and exits 0
# iff every sub-gate exits 0.
#
# Note: future maintainers extending P03 with additional gates MUST add the
# new verifier to this gate list AND update the expected
# `SUMMARY: pass=N` count in the T05 task plan's expected output.
#
# T06 introduces milestone-grain validators (m029-p03-validate-milestone-pass.sh
# and m029-p03-closure-ceremony-shape.sh) -- those are NOT included in this
# per-phase suite because they are milestone-grain, not phase-grain.
#
# Bash 3.2 / MEM001 compatible. Straight-line invocation per AD-19 -- no
# loops over arrays, no compound chains, no eval. Thirteen literal
# `bash <path>` invocations followed by accumulator updates. Mirrors
# tools/verify/m029-p02-phase-suite.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

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

# ---------- T01 Gate 1: render-position-live-shape ----------

bash tools/verify/m029-p03-render-position-live-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p03-render-position-live-shape.sh"

# ---------- T01 Gate 2: display-thresholds-config-shape ----------

bash tools/verify/m029-p03-display-thresholds-config-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p03-display-thresholds-config-shape.sh"

# ---------- T02 Gate 3: auto-preflight-shape ----------

bash tools/verify/m029-p03-auto-preflight-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p03-auto-preflight-shape.sh"

# ---------- T03 Gate 4: auto-chain-shape ----------

bash tools/verify/m029-p03-auto-chain-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p03-auto-chain-shape.sh"

# ---------- T04 Gate 5: measure-live-tail-latency-shape ----------

bash tools/verify/m029-p03-measure-live-tail-latency-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p03-measure-live-tail-latency-shape.sh"

# ---------- T04 Gate 6: sc7-shape ----------

bash tools/verify/m029-p03-sc7-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p03-sc7-shape.sh"

# ---------- T04 Gate 7: sc8-shape ----------

bash tools/verify/m029-p03-sc8-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p03-sc8-shape.sh"

# ---------- T04 Gate 8: sc9-shape ----------

bash tools/verify/m029-p03-sc9-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p03-sc9-shape.sh"

# ---------- T04 Gate 9: sc10-shape ----------

bash tools/verify/m029-p03-sc10-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p03-sc10-shape.sh"

# ---------- T05 Gate 10: spec-amendment-shape ----------

bash tools/verify/m029-p03-spec-amendment-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p03-spec-amendment-shape.sh"

# ---------- T05 Gate 11: acceptance-battery-shape ----------

bash tools/verify/m029-p03-acceptance-battery-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p03-acceptance-battery-shape.sh"

# ---------- T05 Gate 12: readonly-invariant ----------

bash tools/verify/m029-p03-readonly-invariant.sh
rc=$?
emit_gate_result "$rc" "m029-p03-readonly-invariant.sh"

# ---------- T05 Gate 13: scope-guard ----------

bash tools/verify/m029-p03-scope-guard.sh
rc=$?
emit_gate_result "$rc" "m029-p03-scope-guard.sh"

# ---------- Aggregate summary ----------

printf 'SUMMARY: m029-p03-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
