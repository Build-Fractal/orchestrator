#!/usr/bin/env bash
# scripts/verify/m011-p07-commands-preserve-references.sh
# Regression guard: T03's edit to commands/ingest.md must not delete
# any of the Reference File bullets that P06 established, and the
# Reference File bullets in commands/evaluate.md and commands/roadmap.md
# must still be intact. Extends the P06 preserve-references pattern.
#
# Bash 3.2 compatible. Every token check uses grep -Fq -- "$tok" so
# BSD grep treats the --flag tokens as patterns, not options.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

EVAL_DOC="$REPO/commands/evaluate.md"
ROAD_DOC="$REPO/commands/roadmap.md"
INGEST_DOC="$REPO/commands/ingest.md"

# evaluate.md + roadmap.md bullets preserved from P06/T03.
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

# P06 ingest.md bullets that must still be present post-T03.
INGEST_REQUIRED_P06="
scripts/knowledge/ingest-spec.sh
scripts/knowledge/rebuild-index.sh
scripts/state/spec-metrics.sh
scripts/dispatch/scope-filter.sh
knowledge/spec/
templates/evaluation.md
"

# P07 ingest.md bullets added by T03 (the new shape-detect/normalize/gate
# entries). T04 locks these in as regression anchors going forward.
INGEST_REQUIRED_P07="
scripts/knowledge/detect-spec-shape.sh
scripts/knowledge/normalize-spec.sh
scripts/dispatch/adapters/tool/conversus.sh
commands/conversus-gate.md
scripts/engine/intensity-gate.sh
templates/spec-normalizer-prompt.md
templates/conversus-presets/normalize-fidelity.yml
templates/gate-result.md
"

fail=0

check_doc() {
  local doc="$1" label="$2" patterns="$3"
  local p
  for p in $patterns; do
    if ! grep -Fq -- "$p" "$doc"; then
      printf 'FAIL[%s]: missing reference: %s\n' "$label" "$p"
      fail=1
    fi
  done
}

check_doc "$EVAL_DOC" evaluate.md "$EVAL_REQUIRED"
check_doc "$ROAD_DOC" roadmap.md "$ROAD_REQUIRED"
check_doc "$INGEST_DOC" "ingest.md[P06]" "$INGEST_REQUIRED_P06"
check_doc "$INGEST_DOC" "ingest.md[P07]" "$INGEST_REQUIRED_P07"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: evaluate.md + roadmap.md + ingest.md preserve all prior Reference File bullets"
exit 0
