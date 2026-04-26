#!/usr/bin/env bash
# scripts/verify/m024-p04-proposal-emit-fast-path.sh
# Verifies proposal-emit.sh sets auto_proceeded: true on a Tier-A-eligible input.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"
READ_CONFIG="$ROOT/scripts/state/read-config.sh"

[ -x "$EMIT" ]        || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$GATE" ]        || { echo "FAIL: $GATE not executable"; exit 1; }
[ -x "$READ_CONFIG" ] || { echo "FAIL: $READ_CONFIG not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Tier A trivial input — short enough that:
#   shape-detect           → input_shape=idea, shape_classification=high
#   intensity-recommend    → intensity=Quick (scope=trivial, risk_level=low — no verb-driven risk signal)
#   paragraph-classify     → scope_tier=A, decomposition=single-task, recommended_command=dispatch
#   design_gate / conversus_gate stay at P01 "none" defaults
# Original P04 plan used "fix typo in commands/status.md line 12 sope to scope"
# but the verb "fix" + path-shape input triggers risk_level=medium, blocking Quick.
# "rename TODO comment" is verb-light enough to land Quick naturally.
trivial="rename TODO comment"
emit_out=$(bash "$EMIT" --input "$trivial" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# Sanity — the four conditions must hold in the rendered proposal frontmatter.
grep -q '^scope_tier: "A"$'      "$proposal" || { echo "FAIL: scope_tier not A"; exit 1; }
grep -q '^conversus_gate: "none"$' "$proposal" || { echo "FAIL: conversus_gate not none"; exit 1; }
grep -q '^design_gate: "none"$'  "$proposal" || { echo "FAIL: design_gate not none"; exit 1; }
intensity_line=$(grep '^intensity: ' "$proposal" | head -1)
case "$intensity_line" in
  'intensity: "Quick"') ;;
  *) echo "FAIL: intensity not Quick (got: $intensity_line) — fast-path cannot fire on this fixture; revisit intensity-recommend.sh thresholds"; exit 1 ;;
esac

# The load-bearing assertion — auto_proceeded must be true on a four-condition input.
grep -q '^auto_proceeded: true$' "$proposal" \
  || { echo "FAIL: auto_proceeded not flipped to true on Tier-A fast-path input"; exit 1; }

# The pending_approval invariant: when auto_proceeded=true, pending_approval is still
# the P01 default true at emit time — the route-to-dispatch script is what eventually
# supersedes the operator gate. (P04 only flips auto_proceeded; P03's gate behavior
# for non-fast-path proposals is unchanged.)
grep -q '^pending_approval: true$' "$proposal" \
  || { echo "FAIL: pending_approval should remain true at emit time (route-to-dispatch finalizes)"; exit 1; }

echo "PASS: proposal-emit.sh — Tier-A fast-path input flips auto_proceeded to true"
exit 0
