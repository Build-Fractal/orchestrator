#!/usr/bin/env bash
# tools/verify/m036-p04-classifier-rejects-unknown.sh -- M036 P04 T01.
# Drives classify_reference_file against the unknown-category negative
# fixture. Asserts return code 1 + stderr names "taxonomy".
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/classify-reference.sh"
FX="$ROOT/tests/fixtures/m036-p04-reference-corpus/_negative/unknown-category/REF-blog-post-fixture.md"
fail=0
if [ ! -f "$LIB" ] || [ ! -f "$FX" ]; then
  echo "FAIL: prerequisite missing (LIB=$LIB FX=$FX)"
  echo "SUMMARY: m036-p04-classifier-rejects-unknown.sh fail=1"
  exit 1
fi
# shellcheck disable=SC1090
. "$LIB"
set +e
classify_reference_file "$FX" 2>/tmp/m036-p04-classifier-rejects-unknown-err.$$.txt
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "PASS: classifier rejected unknown-category fixture (rc=$rc)"
else
  echo "FAIL: classifier accepted unknown-category fixture (rc=$rc)"
  fail=$((fail + 1))
fi
if grep -qF -e "taxonomy" /tmp/m036-p04-classifier-rejects-unknown-err.$$.txt; then
  echo "PASS: stderr names 'taxonomy'"
else
  echo "FAIL: stderr does not name 'taxonomy'"
  fail=$((fail + 1))
fi
rm -f /tmp/m036-p04-classifier-rejects-unknown-err.$$.txt
echo "SUMMARY: m036-p04-classifier-rejects-unknown.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
