#!/usr/bin/env bash
# tools/verify/m035-p03-release-workflow-con6-homebrew.sh
set -u

pass=0
fail=0
WF=".github/workflows/release.yml"

if [ ! -f "$WF" ]; then
  echo "FAIL: $WF missing"
  echo "BATTERY: pass=0 fail=1"
  exit 1
fi
pass=$((pass + 1))

if grep -qF 'CON-6 — assert no HOMEBREW_TAP_TOKEN access' "$WF"; then
  pass=$((pass + 1))
else
  echo "FAIL: pr-validate missing CON-6 HOMEBREW_TAP_TOKEN negative-assertion step"
  fail=$((fail + 1))
fi

if grep -qF 'HOMEBREW_TAP_TOKEN visible to pr-validate job' "$WF"; then
  pass=$((pass + 1))
else
  echo "FAIL: CON-6 negative-assertion missing FAIL message"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
