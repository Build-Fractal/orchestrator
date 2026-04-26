#!/usr/bin/env bash
# scripts/verify/m024-p07-pinned-message.sh
# Asserts the FR-7 pinned message is byte-stable across the three pinned sites.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# The literal pinned string. DO NOT edit without updating all three pinned sites.
PINNED='design walkthrough lands in M023; author DESIGN.md manually or skip'

# Site 1: scripts/intake/design-gate-degradation.sh
grep -qF "$PINNED" "$ROOT/scripts/intake/design-gate-degradation.sh" \
  || { echo "FAIL: pinned message missing from scripts/intake/design-gate-degradation.sh"; exit 1; }

# Site 2: commands/evaluate.md
grep -qF "$PINNED" "$ROOT/commands/evaluate.md" \
  || { echo "FAIL: pinned message missing from commands/evaluate.md"; exit 1; }

# Site 3: this verify script (self-reference) — implicit; if the script ran the line above
# matched, the constant is intact.

# End-to-end emission: force walkthrough proposal, run --branch skip, assert stderr carries it.
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
DEG="$ROOT/scripts/intake/design-gate-degradation.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
emit_out=$(bash "$EMIT" --input "redesign the dashboard viewer with split panes and theme support" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
sed -i.bak 's/^design_gate: ".*"$/design_gate: "walkthrough"/' "$proposal"; rm -f "$proposal.bak"
grep -q '^pending_design_authored_manually:' "$proposal" || echo 'pending_design_authored_manually: false' >> "$proposal"

stderr_capture=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch skip 2>&1 >/dev/null)
echo "$stderr_capture" | grep -qF "$PINNED" \
  || { echo "FAIL: pinned message not on stderr during --branch skip (got: $stderr_capture)"; exit 1; }

echo "PASS: pinned-message — FR-7 string byte-stable across degradation script + evaluate.md + emitted to stderr"
exit 0
