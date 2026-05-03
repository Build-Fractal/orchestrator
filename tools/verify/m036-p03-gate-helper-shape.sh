#!/usr/bin/env bash
# tools/verify/m036-p03-gate-helper-shape.sh -- M036 P03 T03.
# Asserts gate helper exists, executable, exposes the documented funcs.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/lib/extract-tier-2-gate.sh"
fail=0
if [ -f "$LIB" ] && [ -x "$LIB" ]; then
  echo "PASS: exists+executable $LIB"
else
  echo "FAIL: missing or non-executable $LIB"
  fail=$((fail + 1))
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$LIB"; then
    echo "PASS: '$pat' in $(basename "$LIB")"
  else
    echo "FAIL: '$pat' missing in $(basename "$LIB")"
    fail=$((fail + 1))
  fi
}
checkpat "extract_tier_2_invoke_gate()"
checkpat "extract_tier_2_promote_or_retain()"
checkpat "tier-2-fidelity"
checkpat ".pass.md"
checkpat ".block.md"
echo "SUMMARY: m036-p03-gate-helper-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
