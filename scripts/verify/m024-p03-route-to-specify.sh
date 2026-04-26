#!/usr/bin/env bash
# scripts/verify/m024-p03-route-to-specify.sh
# Verifies route-to-specify produces the M024→M014 invoke line on a Tier B/C proposal
# AND the M014-shipping probe gates correctly.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
ROUTE="$ROOT/scripts/intake/route-to-specify.sh"

[ -x "$EMIT" ]  || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$ROUTE" ] || { echo "FAIL: $ROUTE not executable"; exit 1; }

# Probe sanity — M014 must currently be shipped (otherwise this checkout cannot run P03 verifies).
[ -f "$ROOT/scripts/specify/specify.sh" ] || { echo "FAIL: M014 specify.sh missing — checkout broken"; exit 1; }
grep -q 'Pass.1' "$ROOT/commands/specify.md" || { echo "FAIL: commands/specify.md missing three-pass marker"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Tier B paragraph → recommended_command=orchestrator:specify.
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers that need fresh data. Also a verbose mode."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }
grep -q '^recommended_command: "orchestrator:specify"' "$proposal" || {
  echo "FAIL: emitter did not flag specify as recommended_command for the Tier B paragraph"
  exit 1
}

route_out=$(bash "$ROUTE" --proposal "$proposal")
echo "$route_out" | grep -q "^invoke=orchestrator:specify --input-from $proposal\$" || {
  echo "FAIL: route-to-specify did not emit the M024→M014 invoke line (got: $route_out)"
  exit 1
}

# Mismatch case: a Tier A proposal (recommended_command=orchestrator:dispatch) MUST be rejected.
emit_out2=$(bash "$EMIT" --input "Add a status caching layer for five seconds." --intake-root "$tmp/intake2")
proposal2=$(echo "$emit_out2" | sed -n 's/^proposal_path=//p')
grep -q '^recommended_command: "orchestrator:dispatch"' "$proposal2" || {
  echo "FAIL: Tier A proposal did not carry dispatch as recommended_command"
  exit 1
}
if bash "$ROUTE" --proposal "$proposal2" >/dev/null 2>&1; then
  echo "FAIL: route-to-specify accepted a dispatch-recommended proposal"
  exit 1
fi

echo "PASS: route-to-specify.sh — emits M024→M014 invoke line + rejects dispatch-recommended proposals"
exit 0
