#!/usr/bin/env bash
# tools/verify/m034-p02-phase-suite.sh — M034 P02 T06 phase-suite aggregator.
#
# The single entry point that orchestrator:verify P02 and the phase Must-Have
# `Check:` commands resolve to. It runs the five P02 slice verifiers in order
# (plain `bash <path>` — never run-probe, per plan-time discipline rule 4),
# printing each one's output, and additionally asserts the FR-6 interactive-cc
# renderer surface is present and well-formed.
#
# Prints "PASS: m034-p02 phase-suite (5/5 slices + FR-6 surface)" + exit 0 iff
# every slice exited 0 AND the FR-6 surface is present:
#   - references/interactive-review-renderer.md exists and contains AskUserQuestion
#   - scripts/lifecycle/interactive-review.sh contains interactive-review-descriptor
# Otherwise prints "FAIL: m034-p02 phase-suite — <which failed>" + exit 1.
# Bash 3.2 / POSIX-sh single file (CON-1 / AD-19).

# Resolve repo root from this script's location (tools/verify/ -> repo root).
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

FAILED=""

for slice in renderer-probe test-responses auto-policies resume-roundtrip boundary-translation; do
  verifier="$REPO_ROOT/tools/verify/m034-p02-$slice.sh"
  echo "--- m034-p02-$slice ---"
  if [ ! -f "$verifier" ]; then
    echo "slice verifier missing: $verifier"
    FAILED="$FAILED slice:$slice(missing)"
    continue
  fi
  bash "$verifier"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    FAILED="$FAILED slice:$slice(exit $rc)"
  fi
done

# --- FR-6 interactive-cc renderer surface assertion. -------------------------
RENDERER_DOC="$REPO_ROOT/references/interactive-review-renderer.md"
INTERACTIVE_SH="$REPO_ROOT/scripts/lifecycle/interactive-review.sh"
echo "--- FR-6 surface (renderer doc + descriptor type) ---"
if [ ! -f "$RENDERER_DOC" ]; then
  echo "FR-6 surface missing: $RENDERER_DOC"
  FAILED="$FAILED fr6:renderer-doc-missing"
elif ! grep -q 'AskUserQuestion' "$RENDERER_DOC"; then
  echo "FR-6 surface missing token: AskUserQuestion in renderer doc"
  FAILED="$FAILED fr6:askuserquestion"
fi
if [ ! -f "$INTERACTIVE_SH" ]; then
  echo "FR-6 surface missing: $INTERACTIVE_SH"
  FAILED="$FAILED fr6:interactive-sh-missing"
elif ! grep -q 'interactive-review-descriptor' "$INTERACTIVE_SH"; then
  echo "FR-6 surface missing token: interactive-review-descriptor in interactive-review.sh"
  FAILED="$FAILED fr6:descriptor-type"
fi

if [ -z "$FAILED" ]; then
  echo "PASS: m034-p02 phase-suite (5/5 slices + FR-6 surface)"
  exit 0
fi

echo "FAIL: m034-p02 phase-suite —$FAILED"
exit 1
