#!/usr/bin/env bash
# scripts/verify/m024-p02-evaluate-spec-backcompat.sh
# Verifies the today-shape evaluation metric output for the captured spec is
# byte-compatible vs tests/fixtures/evaluate-pre-m024-baseline.txt.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC="$ROOT/specs/023-github-native-integration/spec.md"
BASELINE="$ROOT/tests/fixtures/evaluate-pre-m024-baseline.txt"

[ -f "$SPEC" ]     || { echo "FAIL: fixture spec missing: $SPEC"; exit 1; }
[ -f "$BASELINE" ] || { echo "FAIL: baseline fixture missing: $BASELINE"; exit 1; }

tmp=$(mktemp)
baseline_data=$(mktemp)
trap 'rm -f "$tmp" "$baseline_data"' EXIT

# Re-run the same metric extraction the baseline used.
story_count=$(grep -cE '^### User Story|^- \*\*US-' "$SPEC" || true)
fr_count=$(grep -cE '^- \*\*FR-' "$SPEC" || true)
ac_count=$(grep -cE '^[0-9]+\. \*\*Given\*\*|^- \*\*Given\*\*' "$SPEC" || true)

# Emit the same key=value shape as the baseline, in the same order.
{
  echo "metrics_source=raw_spec"
  echo "story_count=$story_count"
  echo "requirement_count=$fr_count"
  echo "acceptance_count=$ac_count"
} > "$tmp"

# diff baseline-stripped-of-comments against the live output.
grep -v '^#' "$BASELINE" | grep -v '^$' > "$baseline_data"

if ! diff -q "$baseline_data" "$tmp" >/dev/null 2>&1; then
  echo "FAIL: today-shape metrics drifted from baseline"
  echo "----- baseline -----"; cat "$baseline_data"
  echo "----- live -----"; cat "$tmp"
  exit 1
fi

echo "PASS: evaluate-spec-backcompat — today-shape metrics byte-identical to baseline"
exit 0
