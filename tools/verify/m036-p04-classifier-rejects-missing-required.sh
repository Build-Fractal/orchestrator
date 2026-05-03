#!/usr/bin/env bash
# tools/verify/m036-p04-classifier-rejects-missing-required.sh -- M036 P04 T01.
# Drives classify_reference_required_fields against the missing-source
# negative fixture. Asserts return code 1 + stderr names "source".
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/classify-reference.sh"
FX="$ROOT/tests/fixtures/m036-p04-reference-corpus/_negative/missing-source/REF-cms-rule-no-source.md"
fail=0
if [ ! -f "$LIB" ] || [ ! -f "$FX" ]; then
  echo "FAIL: prerequisite missing (LIB=$LIB FX=$FX)"
  echo "SUMMARY: m036-p04-classifier-rejects-missing-required.sh fail=1"
  exit 1
fi
# shellcheck disable=SC1090
. "$LIB"
set +e
classify_reference_required_fields "$FX" 2>/tmp/m036-p04-classifier-rejects-missing-required-err.$$.txt
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "PASS: classifier rejected missing-source fixture (rc=$rc)"
else
  echo "FAIL: classifier accepted missing-source fixture (rc=$rc)"
  fail=$((fail + 1))
fi
if grep -qF -e "source" /tmp/m036-p04-classifier-rejects-missing-required-err.$$.txt; then
  echo "PASS: stderr names 'source'"
else
  echo "FAIL: stderr does not name 'source'"
  fail=$((fail + 1))
fi
rm -f /tmp/m036-p04-classifier-rejects-missing-required-err.$$.txt
echo "SUMMARY: m036-p04-classifier-rejects-missing-required.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
