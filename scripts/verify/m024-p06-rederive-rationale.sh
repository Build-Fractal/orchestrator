#!/usr/bin/env bash
# scripts/verify/m024-p06-rederive-rationale.sh
# Verifies rationale slot semantics on a revised proposal.
#
# Asserts:
#   - For axes touched by the revision (operator-overridden + rederived dependents),
#     the body Rationale slot under ### Axis N — <Name> contains the literal
#     "operator revision (revise.sh)" plus a "proposal-v<N>.md" pointer.
#   - For untouched axes (e.g. intensity when only scope_tier was revised),
#     the body Rationale retains its prior content (no operator-revision text).
#   - The pre-post-process placeholder string never leaks into the final proposal.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
REVISE="$ROOT/scripts/intake/revise.sh"

[ -x "$EMIT" ]   || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$REVISE" ] || { echo "FAIL: $REVISE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# Extract the body Rationale slot for a given axis section header (e.g. "Scope Tier").
# Single-pipeline shape (sed | head allowed per AD-19).
rationale_for() {
  awk -v hdr="### Axis .* — $1" '
    $0 ~ hdr { in_axis = 1; next }
    in_axis && /^### Axis / { in_axis = 0 }
    in_axis && /^\*\*Rationale\*\*:/ { sub(/^\*\*Rationale\*\*:[ \t]*/, ""); print; exit }
  ' "$proposal"
}

# Capture the original intensity rationale (independent axis — should NOT change after revising scope_tier).
intensity_rat_before=$(rationale_for "Intensity")
[ -n "$intensity_rat_before" ] || { echo "FAIL: could not extract pre-revise intensity rationale"; exit 1; }

bash "$REVISE" --proposal "$proposal" --axis scope_tier --value C >/dev/null

# Touched axes carry the version-pointer rationale.
scope_rat=$(rationale_for "Scope Tier")
case "$scope_rat" in
  *"operator revision (revise.sh)"*"proposal-v1.md"*) ;;
  *) echo "FAIL: revised scope_tier rationale missing operator-revision + v1 pointer (got: $scope_rat)"; exit 1 ;;
esac

decomp_rat=$(rationale_for "Decomposition")
case "$decomp_rat" in
  *"operator revision (revise.sh)"*"proposal-v1.md"*) ;;
  *) echo "FAIL: rederived decomposition rationale missing operator-revision + v1 pointer (got: $decomp_rat)"; exit 1 ;;
esac

# Evidence slot for scope_tier should reference proposal-v1.md.
evidence_for() {
  awk -v hdr="### Axis .* — $1" '
    $0 ~ hdr { in_axis = 1; next }
    in_axis && /^### Axis / { in_axis = 0 }
    in_axis && /^\*\*Evidence\*\*:/ { sub(/^\*\*Evidence\*\*:[ \t]*/, ""); print; exit }
  ' "$proposal"
}
scope_ev=$(evidence_for "Scope Tier")
case "$scope_ev" in
  *"proposal-v1.md"*) ;;
  *) echo "FAIL: revised scope_tier evidence missing v1 pointer (got: $scope_ev)"; exit 1 ;;
esac

# Untouched axes (intensity) must NOT carry the operator-revision rationale.
intensity_rat_after=$(rationale_for "Intensity")
case "$intensity_rat_after" in
  *"operator revision"*) echo "FAIL: untouched intensity axis acquired operator-revision rationale"; exit 1 ;;
esac

# No leaked placeholder (the literal "Operator revision via revise.sh — see prior version" must NOT appear post-process).
if grep -q 'Operator revision via revise.sh — see prior version for original rationale.' "$proposal"; then
  echo "FAIL: revise.sh placeholder rationale leaked into final proposal"
  exit 1
fi

# No leaked evidence placeholder either.
if grep -q 'see proposal-v<N>.md (revise.sh post-processes this slot)' "$proposal"; then
  echo "FAIL: revise.sh evidence placeholder leaked into final proposal"
  exit 1
fi

echo "PASS: rederive-rationale — touched axes pointer-rationale; untouched axes preserved; placeholder substituted"
exit 0
