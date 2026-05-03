#!/usr/bin/env bash
# tools/verify/m036-p04-classifier-shape.sh -- M036 P04 T01.
# Asserts scripts/knowledge/classify-reference.sh exists, is executable,
# and exposes the two required pure functions
# (classify_reference_required_fields, classify_reference_file) plus
# the delegation to P00 T03's chunk-frontmatter validator.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/classify-reference.sh"
fail=0
if [ -f "$LIB" ]; then
  echo "PASS: lib exists $LIB"
else
  echo "FAIL: lib missing $LIB"
  fail=$((fail + 1))
fi
if [ -x "$LIB" ]; then
  echo "PASS: lib executable"
else
  echo "FAIL: lib not executable"
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
checkpat "classify_reference_required_fields()"
checkpat "classify_reference_file()"
checkpat "p00-validate-chunk-frontmatter.sh"
checkpat "source published version cite_id topic_tags applies_to_field"
checkpat "MEM004"
echo "SUMMARY: m036-p04-classifier-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
