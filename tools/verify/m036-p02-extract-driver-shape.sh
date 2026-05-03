#!/usr/bin/env bash
# tools/verify/m036-p02-extract-driver-shape.sh -- M036 P02 T02.
# Asserts the extract driver exists, executable, declares --manifest,
# and sources the two T02 lib helpers.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
LIB1="$ROOT/scripts/knowledge/lib/extract-manifest.sh"
LIB2="$ROOT/scripts/knowledge/lib/extract-binary-preservation.sh"
fail=0
checkfile() {
  local p="$1"
  if [ -f "$p" ] && [ -x "$p" ]; then
    echo "PASS: exists+executable $p"
  else
    echo "FAIL: missing or non-executable $p"
    fail=$((fail + 1))
  fi
}
checkfile "$DRV"
checkfile "$LIB1"
checkfile "$LIB2"
checkpat() {
  local p="$1"
  local pat="$2"
  if grep -qF -e "$pat" "$p"; then
    echo "PASS: '$pat' in $(basename "$p")"
  else
    echo "FAIL: '$pat' missing in $(basename "$p")"
    fail=$((fail + 1))
  fi
}
checkpat "$DRV" "--manifest"
checkpat "$DRV" "EXTRACTED:"
checkpat "$DRV" "SKIPPED:"
checkpat "$DRV" "extract-manifest.sh"
checkpat "$DRV" "extract-binary-preservation.sh"
checkpat "$LIB1" "extract_manifest_doc_count"
checkpat "$LIB2" "preservation_sha256"
echo "SUMMARY: m036-p02-extract-driver-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
