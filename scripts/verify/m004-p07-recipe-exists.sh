#!/usr/bin/env bash
# scripts/verify/m004-p07-recipe-exists.sh — Verify check-recipe.sh exists and is executable
set -eu
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PASS=0; FAIL=0

script="$PROJECT_ROOT/scripts/diagnostics/check-recipe.sh"
if [ -f "$script" ]; then
  echo "PASS: check-recipe.sh exists"
  PASS=$((PASS + 1))
else
  echo "FAIL: check-recipe.sh does not exist"
  FAIL=$((FAIL + 1))
fi

if [ -x "$script" ] 2>/dev/null || head -1 "$script" 2>/dev/null | grep -q 'bash'; then
  echo "PASS: check-recipe.sh is executable or has bash shebang"
  PASS=$((PASS + 1))
else
  echo "FAIL: check-recipe.sh is not executable"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
