#!/usr/bin/env bash
# tests/test-fast-path-condition-violation.sh
# M024/P04 phase test — every disqualifying condition produces auto_proceeded: false
# with a reason= that names the failing condition.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$ROOT/scripts/intake/approval-gate.sh"

[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Helper — write a minimal proposal frontmatter for a (tier, intensity, conv, design, lowconf) tuple.
write_proposal() {
  # args: $1=tier $2=intensity $3=conversus_gate $4=design_gate $5=low_confidence  $6=out_path
  cat > "$6" <<EOF
---
schema_version: "1.0"
type: intake-proposal
intake_id: "test"
recommended_command: "orchestrator:dispatch"
pending_approval: true
scope_tier: "$1"
intensity: "$2"
conversus_gate: "$3"
design_gate: "$4"
low_confidence: $5
---
EOF
}

check_reason() {
  # args: $1=label $2=expected_reason $3=proposal_path
  local out
  out=$(bash "$GATE" --proposal "$3" --mode check-fast-path)
  echo "$out" | grep -q '^fast_path_eligible=false$' \
    || { echo "FAIL: $1 verdict not false (got: $out)"; return 1; }
  echo "$out" | grep -q "^reason=$2\$" \
    || { echo "FAIL: $1 reason wrong (expected: $2; got: $out)"; return 1; }
  echo "  ok: $1 → reason=$2"
  return 0
}

rc=0
p1="$tmp/p1.md"; write_proposal B Quick    none none false "$p1"
check_reason "tier-B"          tier-not-A          "$p1" || rc=1

p2="$tmp/p2.md"; write_proposal A Standard none none false "$p2"
check_reason "intensity-Std"   intensity-not-Quick "$p2" || rc=1

p3="$tmp/p3.md"; write_proposal A Quick    required none false "$p3"
check_reason "conversus-on"    conversus-gated     "$p3" || rc=1

p4="$tmp/p4.md"; write_proposal A Quick    none required false "$p4"
check_reason "design-on"       design-gated        "$p4" || rc=1

p5="$tmp/p5.md"; write_proposal A Quick    none none true  "$p5"
check_reason "low-conf"        low-confidence      "$p5" || rc=1

if [ $rc -eq 0 ]; then
  echo "PASS: test-fast-path-condition-violation — five disqualifying conditions all caught with correct reason"
fi
exit $rc
