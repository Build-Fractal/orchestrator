#!/usr/bin/env bash
# tools/verify/m037-p02-phase-suite.sh — M037 P02 phase-close gate suite.
#
# Aggregates every P02 verifier from T01..T05 of the publishing-robustness
# paper-cut bundle and emits a single aggregate SUMMARY line. Canonical
# "P02 is done" gate.
#
# Sub-gates (in task order — upstream task gates surface BEFORE downstream
# consumers, so an upstream failure short-circuits diagnostics):
#
#   T01 — feedback routing arm:
#     1. m037-p02-feedback-routing.sh
#
#   T02 — F12 publishing cluster:
#     2. m037-p02-workflow-pages-publishing.sh
#
#   T03 — private site_url visibility branch:
#     3. m037-p02-private-site-url.sh
#
#   T04 — OUT-OF-SCOPE collapse:
#     4. m037-p02-out-of-scope-collapse.sh
#
#   T05 — discussions callout:
#     5. m037-p02-discussions-callout.sh
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at end and exits 0
# iff every sub-gate exits 0.
#
# Bash 3.2 compatible. Straight-line invocation per AD-19 — no loops over
# arrays, no compound chains, no eval. Mirrors tools/verify/m037-p01-phase-suite.sh.

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

# ---------- T01 Gate 1: feedback-routing ----------

bash tools/verify/m037-p02-feedback-routing.sh
rc=$?
emit_gate_result "$rc" "m037-p02-feedback-routing.sh"

# ---------- T02 Gate 2: workflow-pages-publishing ----------

bash tools/verify/m037-p02-workflow-pages-publishing.sh
rc=$?
emit_gate_result "$rc" "m037-p02-workflow-pages-publishing.sh"

# ---------- T03 Gate 3: private-site-url ----------

bash tools/verify/m037-p02-private-site-url.sh
rc=$?
emit_gate_result "$rc" "m037-p02-private-site-url.sh"

# ---------- T04 Gate 4: out-of-scope-collapse ----------

bash tools/verify/m037-p02-out-of-scope-collapse.sh
rc=$?
emit_gate_result "$rc" "m037-p02-out-of-scope-collapse.sh"

# ---------- T05 Gate 5: discussions-callout ----------

bash tools/verify/m037-p02-discussions-callout.sh
rc=$?
emit_gate_result "$rc" "m037-p02-discussions-callout.sh"

# ---------- Aggregate summary ----------

printf 'SUMMARY: m037-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
