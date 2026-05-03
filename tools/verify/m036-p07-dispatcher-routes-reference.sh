#!/usr/bin/env bash
# tools/verify/m036-p07-dispatcher-routes-reference.sh — M036 P07 T03
# asserts build-context.sh's display-order/name/priority/volatility maps
# each contain a reference slot. AD-19 single-script-file shape.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F="$ROOT/scripts/dispatch/build-context.sh"
pass=0
fail=0
check() {
  local label="$1" pat="$2"
  if grep -qF -e "$pat" "$F"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (missing: $pat)"
    fail=$((fail + 1))
  fi
}
if [ ! -f "$F" ]; then
  echo "FAIL: $F not found"
  echo "SUMMARY: m036-p07-dispatcher-routes-reference.sh pass=0 fail=1"
  exit 1
fi
check "display-order-arm"      "reference)   echo 4"
check "display-name-arm"       'reference)    echo "Reference"'
check "display-priority-arm"   "spec_context|reference)"
check "volatility-arm"         '"Reference") echo "stable"'
check "omit-empty-extension"   '[ "$s_source" = "reference" ]'
echo "SUMMARY: m036-p07-dispatcher-routes-reference.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
