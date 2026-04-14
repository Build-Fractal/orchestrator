#!/usr/bin/env bash
# m008-p04-derive-phase-no-hardcode.sh -- derive-phase.sh references resolve-root.sh in its NOTE/comments
# and contains no uncommented `.specify/orchestrator` default path.
set -u

SCRIPT="scripts/state/derive-phase.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT missing"
  exit 1
fi

# Must mention resolve-root.sh somewhere (documentation or call)
if ! grep -q 'resolve-root.sh' "$SCRIPT"; then
  echo "FAIL: $SCRIPT does not reference resolve-root.sh"
  exit 1
fi

# Strip comment lines and blank lines, then scan the remainder for literal
# `.specify/orchestrator` as a hardcoded path. If any survive, that is a
# hardcoded default that P04 wanted removed.
non_comment="$(grep -v '^[[:space:]]*#' "$SCRIPT" | grep -v '^[[:space:]]*$' || true)"
if echo "$non_comment" | grep -q '\.specify/orchestrator'; then
  echo "FAIL: non-comment line in $SCRIPT still hardcodes .specify/orchestrator:"
  echo "$non_comment" | grep '\.specify/orchestrator'
  exit 1
fi

echo "PASS: derive-phase.sh references resolve-root.sh and has no hardcoded .specify/orchestrator default"
exit 0
