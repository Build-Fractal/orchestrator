#!/usr/bin/env bash
# scripts/verify/m024-p07-degradation-script.sh
# Verifies the degradation script's mode dispatch and validation.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/intake/design-gate-degradation.sh"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
[ -x "$EMIT" ]   || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Emit a baseline paragraph proposal (design_gate=none stub at P01 emit time).
out=$(bash "$EMIT" --input "fix typo in commands/status.md" --intake-root "$tmp/intake")
proposal=$(echo "$out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# Force design_gate=walkthrough for branch tests.
sed -i.bak 's/^design_gate: ".*"$/design_gate: "walkthrough"/' "$proposal"
rm -f "$proposal.bak"
# Add the transient pending flag (P07 schema addition; T03 wires this into the template).
grep -q '^pending_design_authored_manually:' "$proposal" || echo 'pending_design_authored_manually: false' >> "$proposal"

# Probe-only mode emits m023_shipped + recommended_command.
po_out=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$SCRIPT" --proposal "$proposal" --probe-only)
echo "$po_out" | grep -qx "m023_shipped=false" || { echo "FAIL: probe-only m023_shipped=false (got: $po_out)"; exit 1; }
echo "$po_out" | grep -qE "^recommended_command=" || { echo "FAIL: probe-only recommended_command line (got: $po_out)"; exit 1; }

# Branch=skip on a non-walkthrough proposal exits 2.
sed -i.bak 's/^design_gate: ".*"$/design_gate: "none"/' "$proposal"
rm -f "$proposal.bak"
if M023_SHIPPED_PROBE_OVERRIDE=stub bash "$SCRIPT" --proposal "$proposal" --branch skip >/dev/null 2>&1; then
  echo "FAIL: skip on non-walkthrough should exit 2"
  exit 1
fi

# Restore walkthrough; branch=skip on probe=live exits 2 (M023 shipped).
sed -i.bak 's/^design_gate: ".*"$/design_gate: "walkthrough"/' "$proposal"
rm -f "$proposal.bak"
if M023_SHIPPED_PROBE_OVERRIDE=live bash "$SCRIPT" --proposal "$proposal" --branch skip >/dev/null 2>&1; then
  echo "FAIL: skip on probe=live should exit 2"
  exit 1
fi

# Unknown --branch value exits 2.
if M023_SHIPPED_PROBE_OVERRIDE=stub bash "$SCRIPT" --proposal "$proposal" --branch frobnicate >/dev/null 2>&1; then
  echo "FAIL: unknown --branch should exit 2"
  exit 1
fi

# Missing --proposal exits 2.
if bash "$SCRIPT" --branch skip >/dev/null 2>&1; then
  echo "FAIL: missing --proposal should exit 2"
  exit 1
fi

echo "PASS: degradation-script — probe-only + branch validation errors covered"
exit 0
