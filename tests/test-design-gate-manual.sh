#!/usr/bin/env bash
# tests/test-design-gate-manual.sh
# M024/P07/T04 — Manual branch end-to-end: halt-on-first-invoke; flip-on-follow-up.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
emit_out=$(bash "$EMIT" --input "redesign the dashboard viewer with split panes" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

# First invoke -> halt.
out1=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$GATE" --proposal "$proposal" --verb manual 2>/dev/null)
echo "$out1" | grep -q '^branch=manual halt=true' || { echo "FAIL: first invoke did not halt (got: $out1)"; exit 1; }
design_md=$(echo "$out1" | sed -n 's/^.*design_md_path=//p' | head -1)
[ -n "$design_md" ] || { echo "FAIL: first invoke did not emit design_md_path"; exit 1; }

# Author DESIGN.md.
mkdir -p "$(dirname "$design_md")"
echo "# DESIGN.md (synthetic)" > "$design_md"

# Follow-up -> flip.
out2=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$GATE" --proposal "$proposal" --verb manual 2>/dev/null)
echo "$out2" | grep -q '^branch=manual halt=false' || { echo "FAIL: follow-up did not flip (got: $out2)"; exit 1; }
grep -q '^design_authored_manually: true' "$proposal" || { echo "FAIL: design_authored_manually not flipped"; exit 1; }
grep -q '^pending_approval: true' "$proposal" || { echo "FAIL: pending_approval not reset"; exit 1; }

echo "PASS: design-gate-manual — halt+flip cycle works; pending_approval reset for re-approval"
exit 0
