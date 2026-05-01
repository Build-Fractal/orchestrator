#!/usr/bin/env bash
# tools/verify/p06-shadow-off-byte-equality.sh — wraps p02-additive-schema.sh
# to confirm dispatch-interface shadow-OFF emit is byte-identical to
# pre-amendment HEAD after T02's character-field amendment lands. Mirrors
# P05/T01's doctor-config-check delegate-and-pass-through pattern.
#
# AD-19 single-script-file shape. Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

bash "$PROJECT_ROOT/tools/verify/p02-additive-schema.sh" > /dev/null 2>&1
rc=$?

pass=0
fail=0
if [ "$rc" -eq 0 ]; then
  pass=1
  echo "OK: p02-additive-schema.sh exited 0 (shadow-off byte-equality preserved)"
else
  fail=1
  echo "FAIL: p02-additive-schema.sh exited $rc — T02 amendment broke shadow-off byte-equality"
fi

echo "SUMMARY: p06-shadow-off-byte-equality.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
