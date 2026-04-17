#!/usr/bin/env bash
# scripts/verify/m011-p06-commands-preserve-references.sh
# Regression guard: T01's edit to commands/evaluate.md must not delete
# any previously-listed Reference File bullet from evaluate.md or
# roadmap.md. Extends the P05/T03 preserved-references check to cover
# P06-era content.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

EVAL_DOC="$REPO/commands/evaluate.md"
ROAD_DOC="$REPO/commands/roadmap.md"

# These bullets match the post-P05 state of evaluate.md and roadmap.md
# exactly. T01's additive edit to evaluate.md must not drop any of them.
EVAL_REQUIRED="
templates/evaluation.md
scripts/state/read-config.sh
scripts/state/spec-metrics.sh
scripts/lifecycle/scaffold.sh
references/tier-definitions.md
references/installation.md
"

ROAD_REQUIRED="
templates/roadmap.md
scripts/state/derive-phase.sh
scripts/state/read-config.sh
scripts/lifecycle/scaffold.sh
scripts/dispatch/scope-filter.sh
scripts/knowledge/spec-story-graph.sh
scripts/knowledge/traverse-graph.sh
scripts/engine/intensity-gate.sh
scripts/state/spec-metrics.sh
references/tier-definitions.md
scripts/verify/check-boundary-map.sh
references/state-machine.md
"

fail=0

check_doc() {
  local doc="$1" label="$2" patterns="$3"
  local p
  for p in $patterns; do
    if ! grep -Fq "$p" "$doc"; then
      printf 'FAIL[%s]: missing reference: %s\n' "$label" "$p"
      fail=1
    fi
  done
}

check_doc "$EVAL_DOC" evaluate.md "$EVAL_REQUIRED"
check_doc "$ROAD_DOC" roadmap.md "$ROAD_REQUIRED"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: evaluate.md and roadmap.md preserve all prior Reference File bullets"
