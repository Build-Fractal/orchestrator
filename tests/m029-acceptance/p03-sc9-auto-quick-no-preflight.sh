#!/usr/bin/env bash
# tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh
#
# M029 / P03 / SC-9 acceptance script.
#
# SC-9 contract: at Quick intensity, the auto loop's Preflight Summary
# block is suppressed entirely -- the literal token `Preflight Summary`
# does NOT appear on stderr before `AUTO:READY`. This is a documented
# byte-stable invariant in commands/auto.md.
#
# Like SC-8, this is a *contract-surface* assertion (per the
# read-only-skill-doc model documented in T02 SUMMARY): the actual
# `orchestrator:auto` loop runs in the LLM agent, not in this Bash
# harness. SC-9 verifies the documented contract surface contains the
# load-bearing invariant text.
#
# Assertions:
#   1. The fixture's EVALUATION frontmatter declares intensity: quick.
#   2. commands/auto.md contains the literal "Quick intensity suppresses".
#   3. commands/auto.md contains the literal "AUTO:READY".
#   4. commands/auto.md contains the literal "Preflight Summary".
#   5. The `Quick intensity suppresses` clause appears AFTER the
#      `Preflight Summary` header (i.e., the suppression invariant is
#      documented in the same section as the surface it suppresses).
#   6. The predictive-surface.sh suppression-by-tier path is preserved:
#      invoking the oracle with --intensity quick emits zero stdout
#      (CON-3 / SC-17 byte-identity contract from M027/P02).
#
# Bash 3.2 (MEM001). MEM004 carve-out: pipes inside body OK.
# CON-1 / FR-14 read-only: writes only to /tmp/m029-p03-sc9.$$/.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/tests/m029-acceptance/fixtures/auto-preflight-quick.fixture"
PREDICTIVE="$PROJECT_ROOT/scripts/dispatch/predictive-surface.sh"
AUTO_MD="$PROJECT_ROOT/commands/auto.md"

pass=0
fail=0
ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

TMP="${TMPDIR:-/tmp}/m029-p03-sc9.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT

# Gate: fixture exists.
if [ -d "$FIXTURE/.orchestrator/milestones/M996" ]; then
    ok "SC-9 fixture tree exists"
else
    bad "SC-9 fixture missing at $FIXTURE/.orchestrator/milestones/M996"
    printf 'SUMMARY: p03-sc9-auto-quick-no-preflight.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Assertion 1: fixture EVALUATION declares intensity: quick.
EVAL_FILE="$FIXTURE/.orchestrator/milestones/M996/M996-EVALUATION.md"
if grep -F -q 'intensity: "quick"' "$EVAL_FILE"; then
    ok "SC-9 fixture EVALUATION declares intensity: quick"
else
    bad "SC-9 fixture EVALUATION does NOT declare intensity: quick"
fi

# Gate: commands/auto.md exists.
if [ -f "$AUTO_MD" ]; then
    ok "commands/auto.md exists"
else
    bad "commands/auto.md missing"
    printf 'SUMMARY: p03-sc9-auto-quick-no-preflight.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Assertion 2: commands/auto.md contains the documented Quick-intensity
# suppression clause.
if grep -F -q -e 'Quick intensity suppresses' "$AUTO_MD"; then
    ok "SC-9 commands/auto.md contains 'Quick intensity suppresses' clause"
else
    bad "SC-9 commands/auto.md missing 'Quick intensity suppresses' clause"
fi

# Assertion 3: commands/auto.md contains AUTO:READY token.
if grep -F -q -e 'AUTO:READY' "$AUTO_MD"; then
    ok "SC-9 commands/auto.md contains AUTO:READY token"
else
    bad "SC-9 commands/auto.md missing AUTO:READY token"
fi

# Assertion 4: commands/auto.md contains "Preflight Summary" header.
if grep -F -q -e 'Preflight Summary' "$AUTO_MD"; then
    ok "SC-9 commands/auto.md contains Preflight Summary header"
else
    bad "SC-9 commands/auto.md missing Preflight Summary header"
fi

# Assertion 5: the Quick-suppression clause appears in the same section
# as the Preflight Summary surface it suppresses. Both literals appear
# in the docstring; we additionally assert that the Preflight Summary
# header line precedes (or coincides with) the Quick-suppression clause
# -- the suppression invariant is documented adjacent to the surface.
HDR_LINE="$(grep -n -F -e 'Preflight Summary' "$AUTO_MD" | head -n 1 | cut -d: -f1)"
SUP_LINE="$(grep -n -F -e 'Quick intensity suppresses' "$AUTO_MD" | head -n 1 | cut -d: -f1)"
if [ -n "$HDR_LINE" ] && [ -n "$SUP_LINE" ] && [ "$SUP_LINE" -ge "$HDR_LINE" ]; then
    ok "SC-9 Quick-suppression clause documented adjacent to (after) Preflight Summary header (line $SUP_LINE >= $HDR_LINE)"
else
    bad "SC-9 Quick-suppression clause not documented adjacent to Preflight Summary header (HDR=$HDR_LINE SUP=$SUP_LINE)"
fi

# Assertion 6: predictive-surface.sh suppression-by-tier preserves the
# zero-stdout contract at --intensity quick.
QK_OUT="$TMP/oracle-quick.out"
QK_ERR="$TMP/oracle-quick.err"
bash "$PREDICTIVE" --description "phase_count=3 phases_complete=1 tasks_remaining=0 intensity=quick" --intensity quick >"$QK_OUT" 2>"$QK_ERR"
if [ ! -s "$QK_OUT" ]; then
    ok "SC-9 predictive-surface.sh --intensity quick emits zero stdout (suppression by tier)"
else
    bad "SC-9 predictive-surface.sh --intensity quick UNEXPECTEDLY emitted stdout"
    cat "$QK_OUT"
fi

# Negative assertion: the Quick-fixture's EVALUATION declares intensity:
# quick (NOT standard or full). This is the schema invariant SC-9
# operates against -- swapping the intensity in the fixture would
# silently break SC-9.
if grep -F -q 'intensity: "standard"' "$EVAL_FILE"; then
    bad "SC-9 fixture EVALUATION UNEXPECTEDLY declares intensity: standard (must be quick)"
else
    ok "SC-9 fixture EVALUATION does not declare intensity: standard (Quick-only invariant)"
fi

printf 'SUMMARY: p03-sc9-auto-quick-no-preflight.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
