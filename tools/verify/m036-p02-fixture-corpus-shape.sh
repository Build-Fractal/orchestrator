#!/usr/bin/env bash
# tools/verify/m036-p02-fixture-corpus-shape.sh -- M036 P02 T01.
# Asserts the 3-doc fixture corpus exists (PDF, DOCX, MD).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DIR="$ROOT/tests/fixtures/m036"
fail=0
check() {
  local p="$1"
  if [ -f "$DIR/$p" ]; then
    echo "PASS: exists $p"
  else
    echo "FAIL: missing $p"
    fail=$((fail + 1))
  fi
}
check "extract-manifest.yaml"
check "sample.pdf"
check "sample.docx"
check "sample.md"
echo "SUMMARY: m036-p02-fixture-corpus-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
