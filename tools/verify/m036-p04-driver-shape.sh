#!/usr/bin/env bash
# tools/verify/m036-p04-driver-shape.sh -- M036 P04 T02.
# Asserts scripts/knowledge/ingest-reference.sh exists, is executable,
# and exposes the documented flags + stdout protocol per the M036 P04
# contract.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DRV="$ROOT/scripts/knowledge/ingest-reference.sh"
fail=0
if [ -f "$DRV" ]; then
  echo "PASS: driver exists $DRV"
else
  echo "FAIL: driver missing $DRV"
  fail=$((fail + 1))
fi
if [ -x "$DRV" ]; then
  echo "PASS: driver executable"
else
  echo "FAIL: driver not executable"
  fail=$((fail + 1))
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
checkpat "--reference-root"
checkpat "--no-index-rebuild"
checkpat "CREATED:"
checkpat "SKIPPED:"
checkpat "REJECTED:"
checkpat "BLOCKED:"
checkpat "SUMMARY: ingest-reference.sh"
checkpat "classify-reference.sh"
checkpat "rebuild-index.sh"
checkpat "content_hash"
echo "SUMMARY: m036-p04-driver-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
