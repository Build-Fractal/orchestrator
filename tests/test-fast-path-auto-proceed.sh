#!/usr/bin/env bash
# tests/test-fast-path-auto-proceed.sh
# M024/P04 phase test — Tier-A trivial input lands auto_proceeded: true.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Tier A trivial fixture. Per T03 SUMMARY, the original plan-supplied fixture
# ("fix typo in commands/status.md line 12 sope to scope") has the verb "fix"
# which intensity-recommend.sh classifies as risk_level=medium → Standard,
# blocking the Quick condition. "rename TODO comment" is verb-light enough to
# satisfy intensity=Quick + shape_classification=high naturally.
trivial="rename TODO comment"
emit_out=$(bash "$EMIT" --input "$trivial" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter produced no proposal"; exit 1; }

grep -q '^auto_proceeded: true$' "$proposal" \
  || { echo "FAIL: trivial Tier-A input did not flip auto_proceeded to true"; exit 1; }
grep -q '^scope_tier: "A"$' "$proposal" \
  || { echo "FAIL: scope_tier not A"; exit 1; }
grep -q '^intensity: "Quick"$' "$proposal" \
  || { echo "FAIL: intensity not Quick"; exit 1; }
grep -q '^conversus_gate: "none"$' "$proposal" \
  || { echo "FAIL: conversus_gate not none"; exit 1; }
grep -q '^design_gate: "none"$' "$proposal" \
  || { echo "FAIL: design_gate not none"; exit 1; }

echo "PASS: test-fast-path-auto-proceed — Tier-A trivial input → auto_proceeded: true"
exit 0
