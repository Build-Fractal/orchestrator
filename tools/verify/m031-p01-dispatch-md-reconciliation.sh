#!/usr/bin/env bash
# tools/verify/m031-p01-dispatch-md-reconciliation.sh
#
# M031/P01/T02 verifier (project-owned, slug-bearing under tools/verify/).
#
# Asserts the FR-4 reconciliation of commands/dispatch.md:21 has landed:
#   1) commands/dispatch.md does NOT contain the literal phrase
#      "Skip payload assembly" anywhere -- the FR-4 inversion check.
#   2) commands/dispatch.md contains the literal token "Quick profile"
#      at least once -- the FR-4 canonical replacement marker.
#   3) commands/dispatch.md contains a comment-or-prose reference to
#      "FR-4" -- the M031 reconciliation provenance, encouraging future
#      maintainers to find the reasoning.
#
# IMPORTANT -- INVERTED-POLARITY GUARD:
#   Assertion (1) is INTENTIONALLY inverted -- it asserts ABSENCE of
#   "Skip payload assembly". Per FR-4 + AD-14 the pre-M031 Quick-skip
#   branch was removed from commands/dispatch.md after the post-M031
#   baseline was captured. A future maintainer who "fixes" this
#   verifier by flipping the polarity would silently re-open the
#   AD-14 single-window discipline and invalidate the post-m031
#   baseline. Mirrors the P00 inverted-polarity convention from
#   tools/verify/p00-spec-foldin-shape.sh.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A.

set -u

DISPATCH_MD="commands/dispatch.md"

pass=0
fail=0

ok() {
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$1"
}
ng() {
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n' "$1"
}

if [ ! -f "$DISPATCH_MD" ]; then
    ng "commands/dispatch.md missing at $DISPATCH_MD"
    printf 'SUMMARY: m031-p01-dispatch-md-reconciliation.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# --- 1) Inverted-polarity assertion: "Skip payload assembly" must NOT appear ---
#     (See header guard. Do NOT flip this polarity.)
if grep -q 'Skip payload assembly' "$DISPATCH_MD"; then
    ng "commands/dispatch.md still contains 'Skip payload assembly' (FR-4 inversion failure -- the Quick-skip branch must be removed)"
else
    ok "commands/dispatch.md does NOT contain 'Skip payload assembly' (FR-4 inversion check)"
fi

# --- 2) Forward assertion: "Quick profile" must appear at least once ---
qp_count=$(grep -c 'Quick profile' "$DISPATCH_MD")
if [ "$qp_count" -ge 1 ]; then
    ok "commands/dispatch.md contains 'Quick profile' ($qp_count occurrences)"
else
    ng "commands/dispatch.md does not contain the literal token 'Quick profile'"
fi

# --- 3) Forward assertion: "FR-4" provenance reference present ---
if grep -q 'FR-4' "$DISPATCH_MD"; then
    ok "commands/dispatch.md references FR-4 (M031 reconciliation provenance)"
else
    ng "commands/dispatch.md missing FR-4 provenance reference"
fi

printf 'SUMMARY: m031-p01-dispatch-md-reconciliation.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
else
    exit 1
fi
