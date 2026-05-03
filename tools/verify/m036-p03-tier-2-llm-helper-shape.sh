#!/usr/bin/env bash
# tools/verify/m036-p03-tier-2-llm-helper-shape.sh -- M036 P03 T02.
# Asserts the Tier 2 LLM helper exists, executable, exposes the two
# documented functions, and honors the EXTRACT_TIER_2_DISPATCH env var.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/lib/extract-tier-2-llm.sh"
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
checkpat "extract_tier_2_dispatch()"
checkpat "extract_tier_2_emit_unit_close()"
checkpat "EXTRACT_TIER_2_DISPATCH"
checkpat "stub:pass"
checkpat "stub:block"
checkpat "task_type"
echo "SUMMARY: m036-p03-tier-2-llm-helper-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
