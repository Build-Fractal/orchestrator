#!/usr/bin/env bash
# tools/verify/m029-p02-phase-suite.sh -- M029 P02 phase-close gate suite.
#
# Aggregates every P02 verifier from T01..T05 of the roadmap-visibility &
# CLI-UX milestone (M029). validate-milestone.sh M029 (P03 deliverable)
# consumes this suite alongside the P01 and P03 phase-suites.
#
# Sub-gates (in dependency order -- T01 design contract surfaces BEFORE
# downstream consumers, so an upstream failure short-circuits diagnostics):
#
#   T01 -- cross-milestone data model:
#     1. m029-p02-cross-milestone-shape-contract.sh
#
#   T02 -- summarize-milestone helper:
#     2. m029-p02-summarize-milestone-shape.sh
#
#   T03 -- render-position + where skill:
#     3. m029-p02-render-position-shape.sh
#     4. m029-p02-where-skill-shape.sh
#
#   T04 -- fixtures + SC acceptance:
#     5. m029-p02-sc5-fixtures-shape.sh
#     6. m029-p02-sentinel-harness-shape.sh
#     7. m029-p02-sc5-shape.sh
#     8. m029-p02-sc6-shape.sh
#     9. m029-p02-sc13-shape.sh
#    10. m029-p02-sc14-shape.sh
#
#   T05 -- close gates:
#    11. m029-p02-acceptance-battery-shape.sh
#    12. m029-p02-readonly-invariant.sh
#    13. m029-p02-scope-guard.sh
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at the end and exits 0
# iff every sub-gate exits 0.
#
# Note: future maintainers extending P02 with additional gates MUST add the
# new verifier to this gate list AND update the expected
# `SUMMARY: pass=N` count in the T05 task plan's expected output.
#
# Bash 3.2 / MEM001 compatible. Straight-line invocation per AD-19 -- no
# loops over arrays, no compound chains, no eval. Thirteen literal
# `bash <path>` invocations followed by accumulator updates. Mirrors
# tools/verify/m029-p01-phase-suite.sh.

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

# ---------- T01 Gate 1: cross-milestone-shape-contract ----------

bash tools/verify/m029-p02-cross-milestone-shape-contract.sh
rc=$?
emit_gate_result "$rc" "m029-p02-cross-milestone-shape-contract.sh"

# ---------- T02 Gate 2: summarize-milestone-shape ----------

bash tools/verify/m029-p02-summarize-milestone-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p02-summarize-milestone-shape.sh"

# ---------- T03 Gate 3: render-position-shape ----------

bash tools/verify/m029-p02-render-position-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p02-render-position-shape.sh"

# ---------- T03 Gate 4: where-skill-shape ----------

bash tools/verify/m029-p02-where-skill-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p02-where-skill-shape.sh"

# ---------- T04 Gate 5: sc5-fixtures-shape ----------

bash tools/verify/m029-p02-sc5-fixtures-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p02-sc5-fixtures-shape.sh"

# ---------- T04 Gate 6: sentinel-harness-shape ----------

bash tools/verify/m029-p02-sentinel-harness-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p02-sentinel-harness-shape.sh"

# ---------- T04 Gate 7: sc5-shape ----------

bash tools/verify/m029-p02-sc5-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p02-sc5-shape.sh"

# ---------- T04 Gate 8: sc6-shape ----------

bash tools/verify/m029-p02-sc6-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p02-sc6-shape.sh"

# ---------- T04 Gate 9: sc13-shape ----------

bash tools/verify/m029-p02-sc13-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p02-sc13-shape.sh"

# ---------- T04 Gate 10: sc14-shape ----------

bash tools/verify/m029-p02-sc14-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p02-sc14-shape.sh"

# ---------- T05 Gate 11: acceptance-battery-shape ----------

bash tools/verify/m029-p02-acceptance-battery-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p02-acceptance-battery-shape.sh"

# ---------- T05 Gate 12: readonly-invariant ----------

bash tools/verify/m029-p02-readonly-invariant.sh
rc=$?
emit_gate_result "$rc" "m029-p02-readonly-invariant.sh"

# ---------- T05 Gate 13: scope-guard ----------

bash tools/verify/m029-p02-scope-guard.sh
rc=$?
emit_gate_result "$rc" "m029-p02-scope-guard.sh"

# ---------- Aggregate summary ----------

printf 'SUMMARY: m029-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
