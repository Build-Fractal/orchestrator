#!/usr/bin/env bash
# tools/verify/m036-p07-handler-shape.sh — M036 P07 T01 handler-shape
# verifier. Asserts scripts/dispatch/lib/section-handlers.sh defines
# handle_reference() and the dispatcher routes source: reference to it.
# Single-script-file shape (AD-19). Bash 3.2 / POSIX-sh.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F="$ROOT/scripts/dispatch/lib/section-handlers.sh"
pass=0
fail=0

check() {
  local label="$1" pattern="$2"
  if grep -qF -e "$pattern" "$F"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (missing token: $pattern)"
    fail=$((fail + 1))
  fi
}

if [ ! -f "$F" ]; then
  echo "FAIL: $F not found"
  echo "SUMMARY: m036-p07-handler-shape.sh pass=0 fail=1"
  exit 1
fi

check "handle-reference-defn"   "handle_reference()"
check "dispatcher-case-arm"     "reference)"
check "dispatcher-invocation"   'handle_reference "$orch_root"'
check "stub-comment-T01"        "T01 stub"

echo "SUMMARY: m036-p07-handler-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
