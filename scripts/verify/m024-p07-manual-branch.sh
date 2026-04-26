#!/usr/bin/env bash
# scripts/verify/m024-p07-manual-branch.sh
# Asserts the manual branch halts on first invoke, proceeds on follow-up after DESIGN.md exists.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
DEG="$ROOT/scripts/intake/design-gate-degradation.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
out=$(bash "$EMIT" --input "redesign the dashboard with a viewer panel" --intake-root "$tmp/intake")
proposal=$(echo "$out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# First invoke — halt expected.
out1=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch manual)
echo "$out1" | grep -q '^branch=manual halt=true' || { echo "FAIL: first invoke should halt (got: $out1)"; exit 1; }
design_md=$(echo "$out1" | sed -n 's/^.*design_md_path=//p' | head -1)
[ -n "$design_md" ] || { echo "FAIL: first invoke did not emit design_md_path"; exit 1; }
grep -q '^pending_design_authored_manually: true' "$proposal" || { echo "FAIL: pending flag not set"; exit 1; }

# Follow-up before DESIGN.md exists — still halt (idempotent).
out2=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch manual)
echo "$out2" | grep -q '^branch=manual halt=true' || { echo "FAIL: idempotent follow-up should still halt (got: $out2)"; exit 1; }

# Author the DESIGN.md and re-invoke.
mkdir -p "$(dirname "$design_md")"
echo "# DESIGN.md (synthetic)" > "$design_md"
out3=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch manual)
echo "$out3" | grep -q '^branch=manual halt=false' || { echo "FAIL: post-DESIGN.md follow-up should not halt (got: $out3)"; exit 1; }
grep -q '^design_authored_manually: true' "$proposal" || { echo "FAIL: design_authored_manually not flipped"; exit 1; }
grep -q '^pending_design_authored_manually: false' "$proposal" || { echo "FAIL: pending flag not flipped back"; exit 1; }
grep -q '^pending_approval: true' "$proposal" || { echo "FAIL: pending_approval not reset to true"; exit 1; }

echo "PASS: manual-branch — halt+idempotent first invoke; flip on follow-up after DESIGN.md authored"
exit 0
