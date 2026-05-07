#!/usr/bin/env bash
# tools/verify/m037-p01-phase-suite.sh — M037 P01 phase-close gate suite.
#
# Aggregates every P01 verifier from T01..T06 of the wiki team-feedback-ready
# milestone (M037) and emits a single aggregate SUMMARY line. This is the
# canonical "P01 is done" gate.
#
# Sub-gates (in task order — upstream task gates surface BEFORE downstream
# consumers, so an upstream failure short-circuits diagnostics):
#
#   T01 — card-grid surface end-to-end:
#     1. m037-p01-card-grid.sh
#
#   T02 — stub version: → title: + auto_generated escape hatch:
#     2. m037-p01-version-to-title.sh
#     3. m037-p01-auto-generated-escape-hatch.sh
#
#   T03 — DR-### heading-shape pivot + framework-owned shape-lint:
#     4. m037-p01-decisions-shape.sh (wraps scripts/verify/decisions-shape-lint.sh)
#
#   T04 — authoring-conventions doc + dispatch payload-guidance reference:
#     5. m037-p01-authoring-conventions-doc.sh
#     6. m037-p01-dispatch-references-conventions.sh
#
#   T05 — CON-4 default-branch helper + mkdocs.yml polish bundle:
#     7. m037-p01-mkdocs-polish-bundle.sh
#
#   T06 — yaml-merge primitive + 3-installer config emission:
#     8. m037-p01-config-clobber-fix.sh
#     9. m037-p01-malformed-yaml-fail-closed.sh
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at the end and exits 0
# iff every sub-gate exits 0.
#
# Bash 3.2 compatible. Straight-line invocation per AD-19 — no loops over
# arrays, no compound chains, no eval. Mirrors tools/verify/m029-p01-phase-suite.sh.

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

# ---------- T01 Gate 1: card-grid ----------

bash tools/verify/m037-p01-card-grid.sh
rc=$?
emit_gate_result "$rc" "m037-p01-card-grid.sh"

# ---------- T02 Gate 2: version-to-title ----------

bash tools/verify/m037-p01-version-to-title.sh
rc=$?
emit_gate_result "$rc" "m037-p01-version-to-title.sh"

# ---------- T02 Gate 3: auto-generated-escape-hatch ----------

bash tools/verify/m037-p01-auto-generated-escape-hatch.sh
rc=$?
emit_gate_result "$rc" "m037-p01-auto-generated-escape-hatch.sh"

# ---------- T03 Gate 4: decisions-shape ----------

bash tools/verify/m037-p01-decisions-shape.sh
rc=$?
emit_gate_result "$rc" "m037-p01-decisions-shape.sh"

# ---------- T04 Gate 5: authoring-conventions-doc ----------

bash tools/verify/m037-p01-authoring-conventions-doc.sh
rc=$?
emit_gate_result "$rc" "m037-p01-authoring-conventions-doc.sh"

# ---------- T04 Gate 6: dispatch-references-conventions ----------

bash tools/verify/m037-p01-dispatch-references-conventions.sh
rc=$?
emit_gate_result "$rc" "m037-p01-dispatch-references-conventions.sh"

# ---------- T05 Gate 7: mkdocs-polish-bundle ----------

bash tools/verify/m037-p01-mkdocs-polish-bundle.sh
rc=$?
emit_gate_result "$rc" "m037-p01-mkdocs-polish-bundle.sh"

# ---------- T06 Gate 8: config-clobber-fix ----------

bash tools/verify/m037-p01-config-clobber-fix.sh
rc=$?
emit_gate_result "$rc" "m037-p01-config-clobber-fix.sh"

# ---------- T06 Gate 9: malformed-yaml-fail-closed ----------

bash tools/verify/m037-p01-malformed-yaml-fail-closed.sh
rc=$?
emit_gate_result "$rc" "m037-p01-malformed-yaml-fail-closed.sh"

# ---------- Aggregate summary ----------

printf 'SUMMARY: m037-p01-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
