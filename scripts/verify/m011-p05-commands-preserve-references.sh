#!/usr/bin/env bash
# scripts/verify/m011-p05-commands-preserve-references.sh
# Regression guard: T01/T02 edits must not delete any previously-listed
# Reference File bullet from evaluate.md or roadmap.md.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

EVAL_DOC="$REPO/commands/evaluate.md"
ROAD_DOC="$REPO/commands/roadmap.md"

EVAL_REQUIRED="
templates/evaluation.md
scripts/state/read-config.sh
scripts/lifecycle/scaffold.sh
references/tier-definitions.md
references/installation.md
"

ROAD_REQUIRED="
templates/roadmap.md
scripts/state/derive-phase.sh
scripts/state/read-config.sh
scripts/lifecycle/scaffold.sh
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
