#!/usr/bin/env bash
# scripts/intake/spec-shape-classify.sh
# M024/P02/T01 — Spec-branch axis classifier (replaces P01 stubs for input_shape=spec).
#
# Inputs:
#   --spec-path <path>   Path to a feature spec (file with `type: feature-spec` frontmatter).
#
# Output (stdout, five lines):
#   scope_tier=<A|B|C>
#   decomposition=<single-task|single-phase|milestone-with-phases>
#   recommended_command=orchestrator:roadmap
#   metrics_source=<spec_chunks|raw_spec>
#   rationale_spec=<one-line evidence string>
#
# Exit 0 on success, 2 on usage error, 1 on internal error (spec missing / bad frontmatter).

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC_METRICS="$ROOT/scripts/state/spec-metrics.sh"

usage() {
  echo "usage: spec-shape-classify.sh --spec-path <path>" >&2
  exit 2
}

SPEC_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --spec-path) SPEC_PATH="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

[ -n "$SPEC_PATH" ] || usage
[ -f "$SPEC_PATH" ] || { echo "spec-shape-classify.sh: spec not found: $SPEC_PATH" >&2; exit 1; }

# Validate the spec carries the M014 interim manifest frontmatter.
if ! head -30 "$SPEC_PATH" | grep -q '^type: feature-spec'; then
  echo "spec-shape-classify.sh: not a feature-spec frontmatter: $SPEC_PATH" >&2
  exit 1
fi

# Derive slug from the spec's parent dir name (e.g. 023-github-native-integration).
slug=$(basename "$(dirname "$SPEC_PATH")")

# Default counts (raw-spec fallback).
metrics_source="raw_spec"
story_count=0
fr_count=0
ac_count=0

# Chunks-first path: invoke spec-metrics.sh if its tree is reachable.
proj_root=$(dirname "$(dirname "$SPEC_PATH")")
orch_root="$proj_root/.orchestrator"
if [ -d "$orch_root" ] && [ -x "$SPEC_METRICS" ]; then
  sm_out=$(bash "$SPEC_METRICS" "$orch_root" 2>/dev/null || true)
  chunks_present=$(echo "$sm_out" | sed -n 's/^spec_chunks_present=//p')
  if [ "$chunks_present" = "true" ]; then
    metrics_source="spec_chunks"
    story_count=$(echo "$sm_out" | sed -n 's/^story_count=//p')
    fr_count=$(echo "$sm_out" | sed -n 's/^requirement_count=//p')
    ac_count=$(echo "$sm_out" | sed -n 's/^acceptance_count=//p')
  fi
fi

# Raw-spec fallback if chunks did not provide values.
if [ "$metrics_source" = "raw_spec" ]; then
  story_count=$(grep -cE '^### User Story|^- \*\*US-' "$SPEC_PATH" || true)
  fr_count=$(grep -cE '^- \*\*FR-' "$SPEC_PATH" || true)
  ac_count=$(grep -cE '^[0-9]+\. \*\*Given\*\*|^- \*\*Given\*\*' "$SPEC_PATH" || true)
fi

# Tier classification (NG-1: inherited from commands/evaluate.md, not re-tuned).
tier="B"
decomposition="single-phase"
if [ "$fr_count" -ge 10 ] || [ "$ac_count" -ge 15 ] || [ "$story_count" -ge 4 ]; then
  tier="C"
  decomposition="milestone-with-phases"
elif [ "$fr_count" -le 3 ] && [ "$ac_count" -le 5 ] && [ "$story_count" -le 1 ]; then
  tier="A"
  decomposition="single-task"
fi

echo "scope_tier=$tier"
echo "decomposition=$decomposition"
echo "recommended_command=orchestrator:roadmap"
echo "metrics_source=$metrics_source"
echo "rationale_spec=spec $slug — metrics_source=$metrics_source; stories=$story_count, FRs=$fr_count, ACs=$ac_count — Tier $tier $decomposition"
exit 0
