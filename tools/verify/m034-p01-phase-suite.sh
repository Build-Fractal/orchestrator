#!/usr/bin/env bash
# tools/verify/m034-p01-phase-suite.sh — M034 P01 T05 phase-suite aggregator.
#
# The single entry point that orchestrator:verify P01 and the phase
# Must-Have `Check:` commands resolve to. It runs the four T01–T04 slice
# verifiers in order (plain `bash <path>` — never run-probe, per plan-time
# discipline rule 4), printing each one's output, and asserts the plan-time
# PC-3/4/5 addendum is present and well-formed.
#
# Prints "PASS: m034-p01 phase-suite (4/4 slices + addendum)" + exit 0 iff
# every slice exited 0 AND the addendum carries PC-3, PC-4, PC-5. Otherwise
# prints "FAIL: m034-p01 phase-suite — <which failed>" + exit 1.
# Bash 3.2 / POSIX-sh single file (CON-1 / AD-19).

# Resolve repo root from this script's location (tools/verify/ -> repo root).
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

FAILED=""

for slice in schema-shape writer producer surfacing; do
  verifier="$REPO_ROOT/tools/verify/m034-p01-$slice.sh"
  echo "--- m034-p01-$slice ---"
  bash "$verifier"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    FAILED="$FAILED slice:$slice(exit $rc)"
  fi
done

ADDENDUM="$REPO_ROOT/.orchestrator/milestones/M034/M034-P01-ADDENDUM.md"
echo "--- addendum PC-3/PC-4/PC-5 ---"
if [ ! -f "$ADDENDUM" ]; then
  echo "addendum missing: $ADDENDUM"
  FAILED="$FAILED addendum:missing"
else
  for pc in PC-3 PC-4 PC-5; do
    if ! grep -q "$pc" "$ADDENDUM"; then
      echo "addendum missing token: $pc"
      FAILED="$FAILED addendum:$pc"
    fi
  done
fi

if [ -z "$FAILED" ]; then
  echo "PASS: m034-p01 phase-suite (4/4 slices + addendum)"
  exit 0
fi

echo "FAIL: m034-p01 phase-suite —$FAILED"
exit 1
