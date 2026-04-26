#!/usr/bin/env bash
# scripts/verify/m024-p03-paragraph-classify.sh
# Verifies paragraph-classify.sh produces non-stub axis values across the three
# tier-bucket cases AND that proposal-emit.sh wires the classifier when input_shape=paragraph.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLASSIFY="$ROOT/scripts/intake/paragraph-classify.sh"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$CLASSIFY" ] || { echo "FAIL: $CLASSIFY not executable"; exit 1; }
[ -x "$EMIT" ]     || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Tier A case (~15 words, no markers).
out_a=$(bash "$CLASSIFY" --input "Add a last-seen timestamp to the status command output and cache it for five seconds.")
echo "$out_a" | grep -q '^scope_tier=A$'         || { echo "FAIL: tier-A case did not classify A — got: $out_a"; exit 1; }
echo "$out_a" | grep -q '^decomposition=single-task$' || { echo "FAIL: tier-A decomposition wrong"; exit 1; }
echo "$out_a" | grep -q '^recommended_command=orchestrator:dispatch$' || { echo "FAIL: tier-A command wrong"; exit 1; }

# Tier B case (50-ish words, no Tier-C markers).
para_b="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers that need fresh data. Also consider a verbose mode that prints the underlying lock-manager state for debugging stuck locks across runs."
out_b=$(bash "$CLASSIFY" --input "$para_b")
echo "$out_b" | grep -q '^scope_tier=B$'         || { echo "FAIL: tier-B case did not classify B — got: $out_b"; exit 1; }
echo "$out_b" | grep -q '^decomposition=single-phase$' || { echo "FAIL: tier-B decomposition wrong"; exit 1; }
echo "$out_b" | grep -q '^recommended_command=orchestrator:specify$' || { echo "FAIL: tier-B command wrong"; exit 1; }

# Tier C case — milestone marker triggers C.
para_c="Plan a new milestone with multiple phases that overhauls the status command surface."
out_c=$(bash "$CLASSIFY" --input "$para_c")
echo "$out_c" | grep -q '^scope_tier=C$'         || { echo "FAIL: tier-C case did not classify C — got: $out_c"; exit 1; }
echo "$out_c" | grep -q '^decomposition=milestone-with-phases$' || { echo "FAIL: tier-C decomposition wrong"; exit 1; }

# End-to-end: emitter consumes classifier on paragraph branch.
emit_out=$(bash "$EMIT" --input "$para_b" --intake-root "$tmp/intake")
proposal_path=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal_path" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }
grep -q '^scope_tier: "B"' "$proposal_path"      || { echo "FAIL: proposal scope_tier not B"; exit 1; }
grep -q '^decomposition: "single-phase"' "$proposal_path" || { echo "FAIL: proposal decomposition not single-phase"; exit 1; }
if grep -q 'P01 stub — deep classifier ships' "$proposal_path"; then
  # P01 stub may still appear for design_gate / conversus_gate / input_shape — those are not P03 scope.
  # But it MUST NOT appear in the scope_tier or decomposition rationale lines.
  if grep -E '(rationale_scope_tier|rationale_decomposition|Rationale.*Tier).*P01 stub' "$proposal_path" >/dev/null 2>&1; then
    echo "FAIL: paragraph proposal still carries P01-stub rationale on scope_tier/decomposition"
    exit 1
  fi
fi

echo "PASS: paragraph-classify.sh — tier A/B/C cases + emitter wiring"
exit 0
