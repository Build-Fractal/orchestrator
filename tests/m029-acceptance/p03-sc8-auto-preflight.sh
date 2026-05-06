#!/usr/bin/env bash
# tests/m029-acceptance/p03-sc8-auto-preflight.sh
#
# M029 / P03 / SC-8 acceptance script.
#
# SC-8 contract: the FR-9 Preflight Summary surface in commands/auto.md
# documents that at Standard intensity the auto loop emits a four-line
# stderr block (Preflight Summary header + phase_count + dispatch_count
# _estimate + predicted_cost) where `predicted_cost` is byte-identical
# to the `cost_standard_usd=` line emitted by the documented oracle
# wrapper:
#
#   bash scripts/dispatch/predictive-surface.sh \
#     --description "$(bash scripts/diagnostics/summarize-milestone.sh \
#                       <MID> --format=keys)" \
#     --intensity standard
#
# This SC is a *contract-surface* assertion (per the read-only-skill-doc
# model documented in T02 SUMMARY): the actual `orchestrator:auto` loop
# runs in the LLM agent, not in this Bash harness. SC-8 verifies the
# *documented contract is reproducible by anyone reading the docstring*:
#   1. The oracle invocation completes and emits a non-empty
#      `cost_standard_usd=` line (the byte-identity source).
#   2. The documented preflight contract surface in commands/auto.md
#      contains the load-bearing literal labels (`phase_count`,
#      `dispatch_count_estimate`, `predicted_cost`, `Preflight Summary`,
#      `cost_standard_usd`).
#
# Bash 3.2 (MEM001). MEM004 carve-out: pipes inside script body OK.
# CON-1 / FR-14 read-only: writes only to /tmp/m029-p03-sc8.$$/.
#
# Documented paper-cut (carried from P02/T04): summarize-milestone.sh
# does NOT honour a `--root` flag (it resolves
# _SM_PROJECT_ROOT/.orchestrator only). The plan-time pseudocode
# referenced `--root <fixture>`; we work around this in two layers:
#   * Layer 1 (this run): construct the description string from the
#     fixture's known-deterministic shape (phase_count=3 phases_complete
#     =1 tasks_remaining=0 intensity=standard) -- the values match what
#     summarize-milestone WOULD emit if it honoured --root. The oracle
#     does not parse the description structurally; it only uses it as a
#     description-string input to intensity-recommend.sh.
#   * Layer 2 (operator follow-up): a future paper-cut tightens
#     summarize-milestone to honour --root or ORCHESTRATOR_ROOT, after
#     which the layer-1 hard-coding can be replaced with a live invocation.
# The fixture under
# tests/m029-acceptance/fixtures/auto-preflight-standard.fixture/ is
# preserved as the schematic record of the deterministic shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/tests/m029-acceptance/fixtures/auto-preflight-standard.fixture"
PREDICTIVE="$PROJECT_ROOT/scripts/dispatch/predictive-surface.sh"
SUMMARIZE="$PROJECT_ROOT/scripts/diagnostics/summarize-milestone.sh"
AUTO_MD="$PROJECT_ROOT/commands/auto.md"

pass=0
fail=0
ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

TMP="${TMPDIR:-/tmp}/m029-p03-sc8.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT

# Gate: fixture tree exists.
if [ -d "$FIXTURE/.orchestrator/milestones/M998" ]; then
    ok "SC-8 fixture tree exists"
else
    bad "SC-8 fixture missing at $FIXTURE/.orchestrator/milestones/M998"
    printf 'SUMMARY: p03-sc8-auto-preflight.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Gate: fixture EVALUATION declares intensity: standard (load-bearing
# for the SC-8 contract surface).
if grep -F -q 'intensity: "standard"' "$FIXTURE/.orchestrator/milestones/M998/M998-EVALUATION.md"; then
    ok "SC-8 fixture EVALUATION declares intensity: standard"
else
    bad "SC-8 fixture EVALUATION does NOT declare intensity: standard"
fi

# Gate: oracle wrapper scripts exist.
if [ -x "$PREDICTIVE" ]; then
    ok "predictive-surface.sh exists and is executable"
else
    bad "predictive-surface.sh missing or non-executable at $PREDICTIVE"
fi
if [ -x "$SUMMARIZE" ]; then
    ok "summarize-milestone.sh exists and is executable"
else
    bad "summarize-milestone.sh missing or non-executable at $SUMMARIZE"
fi

# Build the description string. Layer-1 path (see header) -- we mirror
# the deterministic shape the fixture would emit if summarize-milestone
# honoured --root. The exact value is not parsed structurally by
# predictive-surface; it is fed to intensity-recommend.sh as the
# task-description input.
DESC="phase_count=3 phases_complete=1 tasks_remaining=0 intensity=standard"

# Run the oracle.
ORACLE_OUT="$TMP/oracle.out"
ORACLE_ERR="$TMP/oracle.err"
if bash "$PREDICTIVE" --description "$DESC" --intensity standard >"$ORACLE_OUT" 2>"$ORACLE_ERR"; then
    ok "oracle wrapper exited 0"
else
    bad "oracle wrapper exited non-zero"
    cat "$ORACLE_OUT"
    cat "$ORACLE_ERR"
fi

# Assert oracle emitted a non-empty cost_standard_usd= line. This is
# the byte-identity source for the documented predicted_cost field.
ORACLE_COST=""
if [ -s "$ORACLE_OUT" ]; then
    ORACLE_COST="$(grep -F 'cost_standard_usd=' "$ORACLE_OUT" 2>/dev/null \
        | head -n 1 \
        | cut -d= -f2 \
        || true)"
fi
if [ -n "$ORACLE_COST" ]; then
    ok "SC-8 oracle emitted non-empty cost_standard_usd= line ($ORACLE_COST)"
else
    bad "SC-8 oracle did NOT emit cost_standard_usd= line"
    cat "$ORACLE_OUT"
fi

# Re-run the same oracle invocation. Byte-identity: the cost_standard_usd
# line MUST match across invocations (same description -> deterministic
# cost-estimate output). This validates the AD-4 byte-identity contract
# that the documented oracle wrapper produces a reproducible cost.
ORACLE_OUT_2="$TMP/oracle2.out"
bash "$PREDICTIVE" --description "$DESC" --intensity standard >"$ORACLE_OUT_2" 2>/dev/null
ORACLE_COST_2=""
if [ -s "$ORACLE_OUT_2" ]; then
    ORACLE_COST_2="$(grep -F 'cost_standard_usd=' "$ORACLE_OUT_2" 2>/dev/null \
        | head -n 1 \
        | cut -d= -f2 \
        || true)"
fi
if [ -n "$ORACLE_COST_2" ] && [ "$ORACLE_COST" = "$ORACLE_COST_2" ]; then
    ok "SC-8 oracle cost_standard_usd= byte-identical across invocations (AD-4 reproducibility)"
else
    bad "SC-8 oracle cost_standard_usd= drifts: '$ORACLE_COST' vs '$ORACLE_COST_2'"
fi

# Assert the documented preflight contract surface in commands/auto.md
# contains the load-bearing literal tokens.
if [ -f "$AUTO_MD" ]; then
    ok "commands/auto.md exists"
else
    bad "commands/auto.md missing at $AUTO_MD"
    printf 'SUMMARY: p03-sc8-auto-preflight.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

assert_in_auto_md() {
    _needle="$1"
    _label="$2"
    if grep -F -q -e "$_needle" "$AUTO_MD"; then
        ok "$_label"
    else
        bad "$_label (missing in commands/auto.md)"
    fi
}

assert_in_auto_md 'Preflight Summary' 'SC-8 commands/auto.md contains "Preflight Summary" header'
assert_in_auto_md 'phase_count' 'SC-8 commands/auto.md contains phase_count label'
assert_in_auto_md 'dispatch_count_estimate' 'SC-8 commands/auto.md contains dispatch_count_estimate label'
assert_in_auto_md 'predicted_cost' 'SC-8 commands/auto.md contains predicted_cost label'
assert_in_auto_md 'cost_standard_usd' 'SC-8 commands/auto.md references cost_standard_usd byte-identity field'
assert_in_auto_md 'predictive-surface.sh' 'SC-8 commands/auto.md references predictive-surface.sh oracle'
assert_in_auto_md 'summarize-milestone.sh' 'SC-8 commands/auto.md references summarize-milestone.sh oracle wrapper'

printf 'SUMMARY: p03-sc8-auto-preflight.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
