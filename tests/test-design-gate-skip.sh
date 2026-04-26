#!/usr/bin/env bash
# tests/test-design-gate-skip.sh
# M024/P07/T04 — Skip branch end-to-end: design_skipped=true, pending_approval=false.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
emit_out=$(bash "$EMIT" --input "redesign the dashboard viewer with split panes" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

# Approval-gate skip verb under stub probe.
M023_SHIPPED_PROBE_OVERRIDE=stub bash "$GATE" --proposal "$proposal" --verb skip >/dev/null 2>&1 \
  || { echo "FAIL: skip verb exited non-zero"; exit 1; }

grep -q '^design_skipped: true' "$proposal" || { echo "FAIL: design_skipped not flipped"; exit 1; }
grep -q '^pending_approval: false' "$proposal" || { echo "FAIL: pending_approval not flipped"; exit 1; }
grep -qE '^proceeded_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$proposal" || { echo "FAIL: proceeded_at not set"; exit 1; }

echo "PASS: design-gate-skip — design_skipped=true, pending_approval=false, proceeded_at set"
exit 0
