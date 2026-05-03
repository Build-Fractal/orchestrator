#!/usr/bin/env bash
# tools/verify/m036-p03-m030-task-type-extraction.sh -- M036 P03 T01.
# Asserts templates/model-routing.yml carries the additive
# task_type.extraction row pointing at "smart" for claude-code, and
# CON-3 closure is preserved (no NEW hardcoded model IDs added outside
# the existing resolution: block).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
ROUTING="$ROOT/templates/model-routing.yml"
fail=0
if [ ! -f "$ROUTING" ]; then
  echo "FAIL: routing file missing $ROUTING"
  echo "SUMMARY: m036-p03-m030-task-type-extraction.sh fail=1"
  exit 1
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$ROUTING"; then
    echo "PASS: '$pat' in $(basename "$ROUTING")"
  else
    echo "FAIL: '$pat' missing in $(basename "$ROUTING")"
    fail=$((fail + 1))
  fi
}
checkpat "task_type:"
checkpat "extraction:"
checkpat "claude-code: smart"
checkpat "FR-19"
# CON-3 spot-check: count hardcoded model IDs. Pre-T01 baseline = 6
# matches: 3 occurrences inside the resolution: block (the actual
# CON-3-governed pins) plus 3 in the documentation comment block above
# resolution: that names them by reference. T01 amendment must NOT add
# a seventh — the task_type: rows are required to be symbolic.
hardcoded=$(grep -cE 'claude-(haiku|sonnet|opus)-4-' "$ROUTING")
if [ "$hardcoded" -eq 6 ]; then
  echo "PASS: hardcoded model ID count preserved at 6 (CON-3 closure: 3 resolution + 3 doc-comment)"
else
  echo "FAIL: hardcoded model ID count drifted ($hardcoded; expected 6 — CON-3 violation)"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p03-m030-task-type-extraction.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
