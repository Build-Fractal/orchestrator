#!/usr/bin/env bash
# tools/verify/m036-p03-driver-tier-2-shape.sh -- M036 P03 T02.
# Asserts that scripts/knowledge/extract-reference.sh sources both new
# helpers (extract-tier-2-llm.sh + extract-tier-2-gate.sh authored in
# T03) and references the Tier 2 dispatch path. Cross-task ordering
# note: this verifier passes after T03 lands the gate helper +
# driver edits; T02 is responsible only for the llm helper part.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
fail=0
if [ ! -f "$DRV" ]; then
  echo "FAIL: driver missing $DRV"
  echo "SUMMARY: m036-p03-driver-tier-2-shape.sh fail=1"
  exit 1
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$DRV"; then
    echo "PASS: '$pat' in $(basename "$DRV")"
  else
    echo "FAIL: '$pat' missing in $(basename "$DRV")"
    fail=$((fail + 1))
  fi
}
checkpat "extract-tier-2-llm.sh"
checkpat "extract-tier-2-gate.sh"
checkpat "extract_tier_2_dispatch"
checkpat "extract_tier_2_invoke_gate"
checkpat "extract_tier_2_emit_unit_close"
checkpat "BLOCKED:"
echo "SUMMARY: m036-p03-driver-tier-2-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
