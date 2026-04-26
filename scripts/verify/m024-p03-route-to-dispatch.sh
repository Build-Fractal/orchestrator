#!/usr/bin/env bash
# scripts/verify/m024-p03-route-to-dispatch.sh
# Verifies route-to-dispatch on Tier A proposal AND the auto_proceed=true mutation path.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
ROUTE="$ROOT/scripts/intake/route-to-dispatch.sh"

[ -x "$EMIT" ]  || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$ROUTE" ] || { echo "FAIL: $ROUTE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Tier A paragraph → recommended_command=orchestrator:dispatch, auto_proceeded=false (default).
emit_out=$(bash "$EMIT" --input "Add a status caching layer for five seconds." --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }
grep -q '^recommended_command: "orchestrator:dispatch"' "$proposal" || {
  echo "FAIL: emitter did not flag dispatch as recommended_command for the Tier A paragraph"
  exit 1
}

# Default path: auto_proceeded=false → no proceeded_at mutation, no auto_proceed=1 stdout.
route_out=$(bash "$ROUTE" --proposal "$proposal")
echo "$route_out" | grep -q "^invoke=orchestrator:dispatch --proposal $proposal\$" || {
  echo "FAIL: route-to-dispatch did not emit invoke line (got: $route_out)"
  exit 1
}
echo "$route_out" | grep -q '^auto_proceed=1' && {
  echo "FAIL: route-to-dispatch emitted auto_proceed=1 on auto_proceeded=false proposal"
  exit 1
}
grep -q '^proceeded_at: null' "$proposal" || { echo "FAIL: proceeded_at unexpectedly mutated"; exit 1; }

# Auto-proceed path: simulate P06's fast-path branch by flipping auto_proceeded to true on disk.
sed -i.bak 's/^auto_proceeded: false$/auto_proceeded: true/' "$proposal"
rm -f "${proposal}.bak"

route_out2=$(bash "$ROUTE" --proposal "$proposal")
echo "$route_out2" | grep -q '^auto_proceed=1$' || {
  echo "FAIL: route-to-dispatch did not emit auto_proceed=1 on auto_proceeded=true (got: $route_out2)"
  exit 1
}
grep -qE '^proceeded_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$proposal" || {
  echo "FAIL: proceeded_at not set on auto_proceeded=true path"
  exit 1
}

# Mismatch case: a specify-recommended proposal MUST be rejected.
# NOTE: payload Step 5 paragraph was 28 words (Tier A) — appended "Also a verbose mode." to push to 32 words (Tier B), matching the specify-verify paragraph.
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers that need fresh data. Also a verbose mode."
emit_out3=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake3")
proposal3=$(echo "$emit_out3" | sed -n 's/^proposal_path=//p')
grep -q '^recommended_command: "orchestrator:specify"' "$proposal3" || {
  echo "FAIL: Tier B proposal did not carry specify as recommended_command"
  exit 1
}
if bash "$ROUTE" --proposal "$proposal3" >/dev/null 2>&1; then
  echo "FAIL: route-to-dispatch accepted a specify-recommended proposal"
  exit 1
fi

echo "PASS: route-to-dispatch.sh — invoke line + auto_proceed mutation + rejects specify-recommended proposals"
exit 0
