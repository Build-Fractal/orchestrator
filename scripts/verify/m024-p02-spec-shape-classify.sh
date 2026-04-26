#!/usr/bin/env bash
# scripts/verify/m024-p02-spec-shape-classify.sh
# Verifies spec-shape-classify.sh produces non-stub axis values across tier
# buckets AND that proposal-emit.sh wires the classifier when input_shape=spec.
#
# Note: planned fixture was specs/023-github-native-integration/spec.md, but
# that spec lacks the M014 `type: feature-spec` frontmatter. We use spec 028
# (in-repo, M014-migrated) instead. Open question logged in T01 summary.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLASSIFY="$ROOT/scripts/intake/spec-shape-classify.sh"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$CLASSIFY" ] || { echo "FAIL: $CLASSIFY not executable"; exit 1; }
[ -x "$EMIT" ]     || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Use an existing in-repo spec carrying M014 `type: feature-spec` frontmatter.
SPEC="$ROOT/specs/028-universal-intake-routing/spec.md"
[ -f "$SPEC" ] || { echo "FAIL: fixture spec missing: $SPEC"; exit 1; }

out=$(bash "$CLASSIFY" --spec-path "$SPEC")
echo "$out" | grep -qE '^scope_tier=[ABC]$'                    || { echo "FAIL: scope_tier not A/B/C — got: $out"; exit 1; }
echo "$out" | grep -qE '^decomposition=(single-task|single-phase|milestone-with-phases)$' || { echo "FAIL: decomposition wrong"; exit 1; }
echo "$out" | grep -q  '^recommended_command=orchestrator:roadmap$' || { echo "FAIL: recommended_command not orchestrator:roadmap"; exit 1; }
echo "$out" | grep -qE '^metrics_source=(spec_chunks|raw_spec)$' || { echo "FAIL: metrics_source wrong"; exit 1; }
echo "$out" | grep -q  '^rationale_spec=spec '                  || { echo "FAIL: rationale_spec missing slug prefix"; exit 1; }

# End-to-end: emitter consumes classifier on spec branch.
emit_out=$(bash "$EMIT" --spec-path "$SPEC" --intake-root "$tmp/intake")
proposal_path=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal_path" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

grep -qE '^scope_tier: "[ABC]"' "$proposal_path"            || { echo "FAIL: proposal scope_tier missing"; exit 1; }
grep -qE '^decomposition: "(single-task|single-phase|milestone-with-phases)"' "$proposal_path" || { echo "FAIL: proposal decomposition missing"; exit 1; }
grep -q  '^recommended_command: "orchestrator:roadmap"' "$proposal_path" || { echo "FAIL: proposal recommended_command not roadmap"; exit 1; }

# P01 stub MUST NOT appear on scope_tier or decomposition slots for spec inputs.
if grep -E '(rationale_scope_tier|rationale_decomposition|Rationale.*Tier).*P01 stub' "$proposal_path" >/dev/null 2>&1; then
  echo "FAIL: spec proposal still carries P01-stub rationale on scope_tier/decomposition"
  exit 1
fi

echo "PASS: spec-shape-classify.sh — tier classification + emitter wiring"
exit 0
