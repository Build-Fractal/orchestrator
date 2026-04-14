#!/usr/bin/env bash
# scripts/verify/m004-p07-extension-recipe.sh — Verify extension.yml registers check-recipe.sh
set -eu
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PASS=0; FAIL=0

ext="$PROJECT_ROOT/extension.yml"

if grep -q 'check-recipe.sh' "$ext"; then
  echo "PASS: extension.yml registers check-recipe.sh"
  PASS=$((PASS + 1))
else
  echo "FAIL: extension.yml does not register check-recipe.sh"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
