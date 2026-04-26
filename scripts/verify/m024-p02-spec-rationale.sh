#!/usr/bin/env bash
# scripts/verify/m024-p02-spec-rationale.sh
# Verifies proposal-emit.sh wires the spec-branch rationale slot — input_shape
# rationale carries the spec_rationale string from the classifier (not the P01 stub).
#
# Note: T03 plan named specs/023-github-native-integration/spec.md as the
# fixture, but that spec lacks the M014 `type: feature-spec` frontmatter that
# spec-shape-classify.sh requires. We mirror T01's precedent and use spec 028
# (the in-repo M014-migrated spec) for the emitter wiring assertion.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
SPEC="$ROOT/specs/028-universal-intake-routing/spec.md"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -f "$SPEC" ] || { echo "FAIL: fixture spec missing: $SPEC"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

emit_out=$(bash "$EMIT" --spec-path "$SPEC" --intake-root "$tmp/intake")
proposal_path=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal_path" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# input_shape rationale slot must NOT carry P01 stub for spec inputs.
# It must instead reference the spec slug + metrics_source.
if grep -E 'rationale_input_shape.*P01 stub' "$proposal_path" >/dev/null 2>&1; then
  echo "FAIL: spec proposal carries P01-stub rationale on input_shape slot"
  exit 1
fi

# Affirmative: the spec rationale string ("spec <slug> — metrics_source=...") appears.
if ! grep -q 'spec 028-universal-intake-routing' "$proposal_path"; then
  echo "FAIL: spec rationale does not reference slug 028-universal-intake-routing"
  exit 1
fi
if ! grep -qE 'metrics_source=(spec_chunks|raw_spec)' "$proposal_path"; then
  echo "FAIL: spec rationale missing metrics_source signal"
  exit 1
fi

echo "PASS: spec-rationale wiring — input_shape slot carries spec rationale, no P01 stub"
exit 0
