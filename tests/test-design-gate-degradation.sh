#!/usr/bin/env bash
# tests/test-design-gate-degradation.sh
# M024/P07/T04 — End-to-end design-gate degradation: pinned message + no orphan command.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
DEG="$ROOT/scripts/intake/design-gate-degradation.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$DEG" ]  || { echo "FAIL: $DEG not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# UI-tagged paragraph -> classifier flips design_gate=walkthrough.
para="redesign the proposal viewer with split panes, a live diff layout, and a theme picker"
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

grep -q '^design_gate: "walkthrough"' "$proposal" || { echo "FAIL: classifier did not flip design_gate to walkthrough"; exit 1; }

# Recommended_command guard: must NOT be orchestrator:design pre-M023.
rec=$(sed -n 's/^recommended_command: "\(.*\)"$/\1/p' "$proposal" | head -1)
[ "$rec" != "orchestrator:design" ] || { echo "FAIL: orphan orchestrator:design recommendation in pre-M023 proposal"; exit 1; }

# FR-7 pinned message lands on stderr during --branch skip.
PINNED='design walkthrough lands in M023; author DESIGN.md manually or skip'
stderr=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch skip 2>&1 >/dev/null)
echo "$stderr" | grep -qF "$PINNED" || { echo "FAIL: pinned message not on stderr"; exit 1; }

echo "PASS: design-gate-degradation — pinned message emits; no orphan orchestrator:design recommendation"
exit 0
