#!/usr/bin/env bash
# tools/verify/m036-p03-conversus-preset-shape.sh -- M036 P03 T01.
# Asserts the tier-2-fidelity conversus preset exists and declares the
# required agent + arbiter shape per FR-18.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
PRESET="$ROOT/templates/conversus-presets/tier-2-fidelity.yml"
fail=0
if [ -f "$PRESET" ]; then
  echo "PASS: preset exists $PRESET"
else
  echo "FAIL: preset missing $PRESET"
  fail=$((fail + 1))
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$PRESET"; then
    echo "PASS: '$pat' in $(basename "$PRESET")"
  else
    echo "FAIL: '$pat' missing in $(basename "$PRESET")"
    fail=$((fail + 1))
  fi
}
checkpat "preset_name: tier-2-fidelity"
checkpat "extractor-advocate"
checkpat "fidelity-advocate"
checkpat "verdict_contract: PASS|BLOCK"
checkpat "grounding_file: .orchestrator/memory/constitution.md"
echo "SUMMARY: m036-p03-conversus-preset-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
