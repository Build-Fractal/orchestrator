#!/usr/bin/env bash
# tools/verify/m036-p03-fixture-corpus-shape.sh -- M036 P03 T01.
# Asserts the P03 Tier 2 fixture corpus is on disk: sample.md exists,
# extract-manifest.yaml exists, manifest declares tier: 2 + summary_mode:
# auto for one document.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
FX="$ROOT/tests/fixtures/m036-p03-tier-2"
fail=0
checkfile() {
  local p="$1"
  if [ -f "$p" ]; then
    echo "PASS: exists $p"
  else
    echo "FAIL: missing $p"
    fail=$((fail + 1))
  fi
}
checkfile "$FX/sample.md"
checkfile "$FX/extract-manifest.yaml"
if [ -f "$FX/extract-manifest.yaml" ]; then
  if grep -qF -e "tier: 2" "$FX/extract-manifest.yaml"; then
    echo "PASS: manifest declares tier: 2"
  else
    echo "FAIL: manifest missing tier: 2"
    fail=$((fail + 1))
  fi
  if grep -qF -e 'summary_mode: "auto"' "$FX/extract-manifest.yaml"; then
    echo "PASS: manifest declares summary_mode: auto"
  else
    echo "FAIL: manifest missing summary_mode: auto"
    fail=$((fail + 1))
  fi
  if grep -qF -e 'cite_id: "tier2-fixture-01"' "$FX/extract-manifest.yaml"; then
    echo "PASS: manifest declares cite_id tier2-fixture-01"
  else
    echo "FAIL: manifest missing cite_id tier2-fixture-01"
    fail=$((fail + 1))
  fi
fi
echo "SUMMARY: m036-p03-fixture-corpus-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
