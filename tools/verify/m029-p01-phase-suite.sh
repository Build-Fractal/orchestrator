#!/usr/bin/env bash
# tools/verify/m029-p01-phase-suite.sh -- M029 P01 phase-close gate suite.
#
# Aggregates every P01 verifier from T01..T06 of the roadmap-visibility &
# CLI-UX milestone (M029) and emits a single aggregate SUMMARY line. This
# is the canonical "P01 is done" gate; `validate-milestone.sh M029` (P03
# deliverable) consumes this suite alongside the P02/P03 phase-suites and
# the full SC-1..SC-14 acceptance battery.
#
# Sub-gates (in dependency order -- T01 design contracts surface BEFORE
# downstream consumers, so an upstream failure short-circuits diagnostics):
#
#   T01 -- design contracts:
#     1. m029-p01-headline-shape-contract.sh
#     2. m029-p01-json-schema-contract.sh
#
#   T02 -- AD-1 invocation-context resolver:
#     3. m029-p01-invocation-context-resolver-shape.sh
#     4. m029-p01-sc1-shape.sh
#
#   T03 -- FR-2 headline:
#     5. m029-p01-status-headline-shape.sh
#     6. m029-p01-sc2-shape.sh
#
#   T04 -- FR-3 JSON renderer + status --format=json wiring:
#     7. m029-p01-render-status-json-shape.sh
#     8. m029-p01-status-format-json-wiring.sh
#     9. m029-p01-sc3-shape.sh
#
#   T05 -- FR-4 commands/context.md skill:
#    10. m029-p01-context-skill-shape.sh
#    11. m029-p01-sc4-shape.sh
#
#   T06 -- close gates:
#    12. m029-p01-acceptance-battery-shape.sh
#    13. m029-p01-readonly-invariant.sh
#    14. m029-p01-scope-guard.sh
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at the end and exits 0
# iff every sub-gate exits 0.
#
# Note: future maintainers extending P01 with additional gates MUST add
# the new verifier to this gate list AND update the expected
# `SUMMARY: pass=N` count in the T06 task plan's expected output.
#
# Bash 3.2 compatible. Straight-line invocation per AD-19 -- no loops over
# arrays, no compound chains, no eval. Fourteen literal `bash <path>`
# invocations followed by accumulator updates. Mirrors
# tools/verify/m031-p00-phase-suite.sh.

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

# ---------- T01 Gate 1: headline-shape-contract ----------

bash tools/verify/m029-p01-headline-shape-contract.sh
rc=$?
emit_gate_result "$rc" "m029-p01-headline-shape-contract.sh"

# ---------- T01 Gate 2: json-schema-contract ----------

bash tools/verify/m029-p01-json-schema-contract.sh
rc=$?
emit_gate_result "$rc" "m029-p01-json-schema-contract.sh"

# ---------- T02 Gate 3: invocation-context-resolver-shape ----------

bash tools/verify/m029-p01-invocation-context-resolver-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p01-invocation-context-resolver-shape.sh"

# ---------- T02 Gate 4: sc1-shape ----------

bash tools/verify/m029-p01-sc1-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p01-sc1-shape.sh"

# ---------- T03 Gate 5: status-headline-shape ----------

bash tools/verify/m029-p01-status-headline-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p01-status-headline-shape.sh"

# ---------- T03 Gate 6: sc2-shape ----------

bash tools/verify/m029-p01-sc2-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p01-sc2-shape.sh"

# ---------- T04 Gate 7: render-status-json-shape ----------

bash tools/verify/m029-p01-render-status-json-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p01-render-status-json-shape.sh"

# ---------- T04 Gate 8: status-format-json-wiring ----------

bash tools/verify/m029-p01-status-format-json-wiring.sh
rc=$?
emit_gate_result "$rc" "m029-p01-status-format-json-wiring.sh"

# ---------- T04 Gate 9: sc3-shape ----------

bash tools/verify/m029-p01-sc3-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p01-sc3-shape.sh"

# ---------- T05 Gate 10: context-skill-shape ----------

bash tools/verify/m029-p01-context-skill-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p01-context-skill-shape.sh"

# ---------- T05 Gate 11: sc4-shape ----------

bash tools/verify/m029-p01-sc4-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p01-sc4-shape.sh"

# ---------- T06 Gate 12: acceptance-battery-shape ----------

bash tools/verify/m029-p01-acceptance-battery-shape.sh
rc=$?
emit_gate_result "$rc" "m029-p01-acceptance-battery-shape.sh"

# ---------- T06 Gate 13: readonly-invariant ----------

bash tools/verify/m029-p01-readonly-invariant.sh
rc=$?
emit_gate_result "$rc" "m029-p01-readonly-invariant.sh"

# ---------- T06 Gate 14: scope-guard ----------

bash tools/verify/m029-p01-scope-guard.sh
rc=$?
emit_gate_result "$rc" "m029-p01-scope-guard.sh"

# ---------- Aggregate summary ----------

printf 'SUMMARY: m029-p01-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
