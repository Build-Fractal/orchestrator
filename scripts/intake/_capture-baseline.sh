#!/usr/bin/env bash
# scripts/intake/_capture-baseline.sh
# M024/P02/T03 — One-shot baseline capture for tests/fixtures/evaluate-pre-m024-baseline.txt.
# Re-runs the same raw-spec grep counts that scripts/intake/spec-shape-classify.sh uses.
#
# Invoked once at T03 author time. Not part of the verify suite; the baseline is the
# committed artifact, not the script.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC="$ROOT/specs/023-github-native-integration/spec.md"
[ -f "$SPEC" ] || { echo "missing: $SPEC" >&2; exit 1; }

story_count=$(grep -cE '^### User Story|^- \*\*US-' "$SPEC" || true)
fr_count=$(grep -cE '^- \*\*FR-' "$SPEC" || true)
ac_count=$(grep -cE '^[0-9]+\. \*\*Given\*\*|^- \*\*Given\*\*' "$SPEC" || true)

cat <<EOF
# tests/fixtures/evaluate-pre-m024-baseline.txt
# M024/P02/T03 — Pre-M024 evaluation baseline for specs/023-github-native-integration/spec.md.
# Captured: $(date -u +%Y-%m-%d)
# Re-capture if commands/evaluate.md ## Scope Analysis metric extraction changes.
metrics_source=raw_spec
story_count=$story_count
requirement_count=$fr_count
acceptance_count=$ac_count
EOF
