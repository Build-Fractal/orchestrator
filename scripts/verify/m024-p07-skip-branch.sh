#!/usr/bin/env bash
# scripts/verify/m024-p07-skip-branch.sh
# Asserts the skip branch flips design_skipped=true, pending_approval=false, proceeded_at set.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
DEG="$ROOT/scripts/intake/design-gate-degradation.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
out=$(bash "$EMIT" --input "redesign the dashboard with a viewer panel" --intake-root "$tmp/intake")
proposal=$(echo "$out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# Sanity: classifier should have flipped design_gate to walkthrough.
grep -q '^design_gate: "walkthrough"' "$proposal" || { echo "FAIL: classifier did not flip design_gate to walkthrough"; exit 1; }

# Run skip branch under stub probe.
M023_SHIPPED_PROBE_OVERRIDE=stub bash "$DEG" --proposal "$proposal" --branch skip >/dev/null 2>&1 \
  || { echo "FAIL: skip branch exited non-zero"; exit 1; }

# Assert frontmatter mutations.
grep -q '^design_skipped: true' "$proposal" || { echo "FAIL: design_skipped not flipped to true"; exit 1; }
grep -q '^pending_approval: false' "$proposal" || { echo "FAIL: pending_approval not flipped to false"; exit 1; }
grep -qE '^proceeded_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$proposal" || { echo "FAIL: proceeded_at not set to ISO8601"; exit 1; }

echo "PASS: skip-branch — design_skipped=true, pending_approval=false, proceeded_at set"
exit 0
