#!/usr/bin/env bash
# scripts/verify/m024-p04-fast-path-check.sh
# Verifies the --mode check-fast-path read-only verdict on hand-crafted proposals.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$ROOT/scripts/intake/approval-gate.sh"

[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Helper: write a minimal proposal frontmatter for a given (tier, intensity, conv, design, lowconf) tuple.
write_proposal() {
  # args: $1=tier $2=intensity $3=conversus_gate $4=design_gate $5=low_confidence  $6=out_path
  cat > "$6" <<EOF
---
schema_version: "1.0"
type: intake-proposal
intake_id: "test"
scope_tier: "$1"
intensity: "$2"
conversus_gate: "$3"
design_gate: "$4"
low_confidence: $5
---
EOF
}

# Eligible proposal — all four conditions met, low_confidence=false.
p1="$tmp/p1.md"
write_proposal A Quick none none false "$p1"
out=$(bash "$GATE" --proposal "$p1" --mode check-fast-path)
echo "$out" | grep -q '^fast_path_eligible=true$'   || { echo "FAIL: eligible proposal verdict not true (got: $out)"; exit 1; }
echo "$out" | grep -q '^reason=all-conditions-met$' || { echo "FAIL: eligible reason wrong (got: $out)"; exit 1; }

# Tier B → tier-not-A.
p2="$tmp/p2.md"
write_proposal B Quick none none false "$p2"
out=$(bash "$GATE" --proposal "$p2" --mode check-fast-path)
echo "$out" | grep -q '^fast_path_eligible=false$' || { echo "FAIL: tier-B verdict not false (got: $out)"; exit 1; }
echo "$out" | grep -q '^reason=tier-not-A$'        || { echo "FAIL: tier-B reason wrong (got: $out)"; exit 1; }

# Tier A but Standard intensity → intensity-not-Quick.
p3="$tmp/p3.md"
write_proposal A Standard none none false "$p3"
out=$(bash "$GATE" --proposal "$p3" --mode check-fast-path)
echo "$out" | grep -q '^reason=intensity-not-Quick$' || { echo "FAIL: standard-intensity reason wrong (got: $out)"; exit 1; }

# Conversus-gated → conversus-gated.
p4="$tmp/p4.md"
write_proposal A Quick required none false "$p4"
out=$(bash "$GATE" --proposal "$p4" --mode check-fast-path)
echo "$out" | grep -q '^reason=conversus-gated$' || { echo "FAIL: conversus reason wrong (got: $out)"; exit 1; }

# Design-gated → design-gated.
p5="$tmp/p5.md"
write_proposal A Quick none required false "$p5"
out=$(bash "$GATE" --proposal "$p5" --mode check-fast-path)
echo "$out" | grep -q '^reason=design-gated$' || { echo "FAIL: design reason wrong (got: $out)"; exit 1; }

# Low-confidence guard → low-confidence.
p6="$tmp/p6.md"
write_proposal A Quick none none true "$p6"
out=$(bash "$GATE" --proposal "$p6" --mode check-fast-path)
echo "$out" | grep -q '^reason=low-confidence$' || { echo "FAIL: low-confidence reason wrong (got: $out)"; exit 1; }

# Read-only check: no .bak file, no frontmatter mutation. Compare frontmatter pre/post.
pre=$(shasum -a 256 "$p1" | cut -c1-16)
bash "$GATE" --proposal "$p1" --mode check-fast-path >/dev/null
post=$(shasum -a 256 "$p1" | cut -c1-16)
[ "$pre" = "$post" ] || { echo "FAIL: check-fast-path mutated proposal (pre=$pre post=$post)"; exit 1; }
[ ! -f "${p1}.bak" ] || { echo "FAIL: check-fast-path left a .bak file"; exit 1; }

# Unknown mode → exit 2.
if bash "$GATE" --proposal "$p1" --mode frobnicate >/dev/null 2>&1; then
  echo "FAIL: unknown mode should exit non-zero"
  exit 1
fi

# Verb path still works (regression — approve verb on a fresh hand-crafted proposal needs recommended_command + pending_approval).
p7="$tmp/p7.md"
cat > "$p7" <<EOF
---
schema_version: "1.0"
type: intake-proposal
intake_id: "test"
recommended_command: "orchestrator:dispatch"
pending_approval: true
approved_at: null
cancelled_at: null
---
EOF
ap_out=$(bash "$GATE" --proposal "$p7" --verb approve)
echo "$ap_out" | grep -q '^recommended_command_invoke=orchestrator:dispatch$' \
  || { echo "FAIL: approve verb regression (got: $ap_out)"; exit 1; }

echo "PASS: approval-gate.sh --mode check-fast-path — six branches + read-only invariant + verb regression"
exit 0
