#!/usr/bin/env bash
# scripts/verify/m024-p07-approval-gate-design-verbs.sh
# Asserts approval-gate's manual/skip verbs are wired and validated.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp" "$tmp2" "$tmp3"' EXIT
tmp2=""
tmp3=""
out=$(bash "$EMIT" --input "redesign the dashboard with a viewer panel" --intake-root "$tmp/intake")
proposal=$(echo "$out" | sed -n 's/^proposal_path=//p')

# Verb=skip on walkthrough proposal under stub probe -> exits 0, mutates design_skipped.
M023_SHIPPED_PROBE_OVERRIDE=stub bash "$GATE" --proposal "$proposal" --verb skip >/dev/null 2>&1 \
  || { echo "FAIL: skip verb on walkthrough proposal exited non-zero"; exit 1; }
grep -q '^design_skipped: true' "$proposal" || { echo "FAIL: skip verb did not mutate design_skipped"; exit 1; }

# Re-emit a fresh proposal with non-walkthrough design_gate.
tmp2="$(mktemp -d)"
out=$(bash "$EMIT" --input "fix typo in commands/status.md" --intake-root "$tmp2/intake")
proposal2=$(echo "$out" | sed -n 's/^proposal_path=//p')
grep -q '^design_gate: "none"' "$proposal2" || { echo "FAIL: non-UI input did not yield design_gate=none"; exit 1; }

# Verb=skip on non-walkthrough proposal -> exit 2.
if M023_SHIPPED_PROBE_OVERRIDE=stub bash "$GATE" --proposal "$proposal2" --verb skip >/dev/null 2>&1; then
  echo "FAIL: skip verb on non-walkthrough proposal should exit 2"
  exit 1
fi

# Verb=manual on walkthrough proposal under live probe -> exit 2 (M023 shipped).
tmp3="$(mktemp -d)"
out=$(bash "$EMIT" --input "redesign the dashboard with a viewer panel" --intake-root "$tmp3/intake")
proposal3=$(echo "$out" | sed -n 's/^proposal_path=//p')
if M023_SHIPPED_PROBE_OVERRIDE=live bash "$GATE" --proposal "$proposal3" --verb manual >/dev/null 2>&1; then
  echo "FAIL: manual verb under live probe should exit 2"
  exit 1
fi

echo "PASS: approval-gate-design-verbs — skip+manual wired; validation rejects non-walkthrough + post-M023"
exit 0
