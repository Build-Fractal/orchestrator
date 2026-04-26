#!/usr/bin/env bash
# scripts/verify/m024-p06-axis-rederive.sh
# Verifies the axis-rederive rule table.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
RD="$ROOT/scripts/intake/axis-rederive.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$RD" ]   || { echo "FAIL: $RD not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Generate a fresh paragraph proposal.
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# scope_tier=C → decomposition=milestone-with-phases + recommended_command=orchestrator:specify
out=$(bash "$RD" --axis scope_tier --value C --proposal "$proposal")
echo "$out" | grep -qx "decomposition=milestone-with-phases" || { echo "FAIL: scope_tier=C did not emit milestone-with-phases (got: $out)"; exit 1; }
echo "$out" | grep -qx "recommended_command=orchestrator:specify" || { echo "FAIL: scope_tier=C did not emit orchestrator:specify (got: $out)"; exit 1; }

# scope_tier=A → decomposition=single-task + recommended_command=orchestrator:dispatch
out=$(bash "$RD" --axis scope_tier --value A --proposal "$proposal")
echo "$out" | grep -qx "decomposition=single-task" || { echo "FAIL: scope_tier=A did not emit single-task (got: $out)"; exit 1; }
echo "$out" | grep -qx "recommended_command=orchestrator:dispatch" || { echo "FAIL: scope_tier=A did not emit orchestrator:dispatch (got: $out)"; exit 1; }

# decomposition=multi-milestone → recommended_command=orchestrator:roadmap
out=$(bash "$RD" --axis decomposition --value multi-milestone --proposal "$proposal")
echo "$out" | grep -qx "recommended_command=orchestrator:roadmap" || { echo "FAIL: multi-milestone did not emit orchestrator:roadmap (got: $out)"; exit 1; }

# Independent axis (conversus_gate) emits no rederive lines.
out=$(bash "$RD" --axis conversus_gate --value tdd-prone --proposal "$proposal")
[ -z "$out" ] || { echo "FAIL: conversus_gate emitted unexpected stdout: $out"; exit 1; }

# Independent axis (intensity) emits no rederive lines.
out=$(bash "$RD" --axis intensity --value Full --proposal "$proposal")
[ -z "$out" ] || { echo "FAIL: intensity emitted unexpected stdout: $out"; exit 1; }

# design_gate=walkthrough emits no rederive lines (P07 owns the branch).
out=$(bash "$RD" --axis design_gate --value walkthrough --proposal "$proposal")
[ -z "$out" ] || { echo "FAIL: design_gate=walkthrough emitted unexpected stdout: $out"; exit 1; }

# Unknown axis exits 2.
if bash "$RD" --axis frobnicate --value X --proposal "$proposal" >/dev/null 2>&1; then
  echo "FAIL: unknown axis should exit non-zero"
  exit 1
fi

# Invalid value exits 2.
if bash "$RD" --axis scope_tier --value Z --proposal "$proposal" >/dev/null 2>&1; then
  echo "FAIL: invalid scope_tier value should exit non-zero"
  exit 1
fi

# Missing --proposal exits 2.
if bash "$RD" --axis scope_tier --value A >/dev/null 2>&1; then
  echo "FAIL: missing --proposal should exit non-zero"
  exit 1
fi

echo "PASS: axis-rederive — rule table covers scope_tier+decomposition; independent axes emit no lines; usage validation works"
exit 0
