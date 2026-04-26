#!/usr/bin/env bash
# tests/test-paragraph-intake.sh
# M024/P03 phase test — paragraph end-to-end (emit → deep axes → approve → route).
# Conventions: parallel arrays for pass/fail tracking (MEM002).

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"
ROUTE_S="$ROOT/scripts/intake/route-to-specify.sh"
ROUTE_D="$ROOT/scripts/intake/route-to-dispatch.sh"

PASS=0
FAIL=0
NAMES_0=""; NAMES_1=""; NAMES_2=""; NAMES_3=""
i=0

pass() { PASS=$((PASS+1)); eval "NAMES_$i=\"PASS: \$1\""; i=$((i+1)); }
fail() { FAIL=$((FAIL+1)); eval "NAMES_$i=\"FAIL: \$1 — \$2\""; i=$((i+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ----- Tier A paragraph (≤30 words) → dispatch.
emit_a=$(bash "$EMIT" --input "Add a status caching layer for five seconds." --intake-root "$tmp/a")
prop_a=$(echo "$emit_a" | sed -n 's/^proposal_path=//p')
if [ -f "$prop_a" ] && grep -q '^scope_tier: "A"' "$prop_a" && grep -q '^recommended_command: "orchestrator:dispatch"' "$prop_a"; then
  pass "tier A paragraph → dispatch"
else
  fail "tier A paragraph → dispatch" "proposal at $prop_a missing tier=A or dispatch"
fi

# Approve the Tier A proposal; gate emits invoke=orchestrator:dispatch.
ag_out=$(bash "$GATE" --proposal "$prop_a" --verb approve)
if echo "$ag_out" | grep -q '^recommended_command_invoke=orchestrator:dispatch$'; then
  pass "gate approve → dispatch invoke"
else
  fail "gate approve → dispatch invoke" "got: $ag_out"
fi

# Route to dispatch.
rd_out=$(bash "$ROUTE_D" --proposal "$prop_a")
if echo "$rd_out" | grep -q "^invoke=orchestrator:dispatch --proposal $prop_a\$"; then
  pass "route-to-dispatch invoke line"
else
  fail "route-to-dispatch invoke line" "got: $rd_out"
fi

# ----- Tier B paragraph (31–80 words) → specify.
para_b="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers that need fresh data. Also a verbose mode."
emit_b=$(bash "$EMIT" --input "$para_b" --intake-root "$tmp/b")
prop_b=$(echo "$emit_b" | sed -n 's/^proposal_path=//p')
if [ -f "$prop_b" ] && grep -q '^scope_tier: "B"' "$prop_b" && grep -q '^recommended_command: "orchestrator:specify"' "$prop_b"; then
  pass "tier B paragraph → specify"
else
  fail "tier B paragraph → specify" "proposal at $prop_b missing tier=B or specify"
fi

# Approve + route to specify.
ag_out_b=$(bash "$GATE" --proposal "$prop_b" --verb approve)
if echo "$ag_out_b" | grep -q '^recommended_command_invoke=orchestrator:specify$'; then
  pass "gate approve → specify invoke"
else
  fail "gate approve → specify invoke" "got: $ag_out_b"
fi
rs_out=$(bash "$ROUTE_S" --proposal "$prop_b")
if echo "$rs_out" | grep -q "^invoke=orchestrator:specify --input-from $prop_b\$"; then
  pass "route-to-specify invoke line"
else
  fail "route-to-specify invoke line" "got: $rs_out"
fi

# ----- Tier C paragraph (milestone marker) → specify + milestone-with-phases.
emit_c=$(bash "$EMIT" --input "Plan a new milestone with multiple phases that overhauls the status command surface." --intake-root "$tmp/c")
prop_c=$(echo "$emit_c" | sed -n 's/^proposal_path=//p')
if [ -f "$prop_c" ] && grep -q '^scope_tier: "C"' "$prop_c" && grep -q '^decomposition: "milestone-with-phases"' "$prop_c"; then
  pass "tier C paragraph → milestone-with-phases"
else
  fail "tier C paragraph → milestone-with-phases" "proposal at $prop_c missing tier=C or correct decomposition"
fi

# Print summary.
n=0
while [ $n -lt $i ]; do
  eval "echo \"\$NAMES_$n\""
  n=$((n+1))
done

echo "----- test-paragraph-intake.sh: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
