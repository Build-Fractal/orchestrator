#!/usr/bin/env bash
# tools/verify/m036-p02-fixture-manifest-shape.sh -- M036 P02 T01.
# Asserts the fixture manifest declares 3 documents covering 3 of the
# four taxonomy categories (cms-rule, training-material, glossary).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
M="$ROOT/tests/fixtures/m036/extract-manifest.yaml"
fail=0
if [ ! -f "$M" ]; then
  echo "FAIL: missing $M"
  exit 1
fi
check() {
  local pattern="$1"
  if grep -qF "$pattern" "$M"; then
    echo "PASS: contains '$pattern'"
  else
    echo "FAIL: missing '$pattern'"
    fail=$((fail + 1))
  fi
}
check "documents:"
check "cite_id:"
check "category: \"cms-rule\""
check "category: \"training-material\""
check "category: \"glossary\""
check "summary_mode:"
check "summary:"
echo "SUMMARY: m036-p02-fixture-manifest-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
