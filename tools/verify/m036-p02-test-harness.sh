#!/usr/bin/env bash
# tools/verify/m036-p02-test-harness.sh -- M036 P02 T04.
# Asserts the SC-10 harness exists, executable, runs to completion,
# and emits a BATTERY: line. Permissive on per-doc PASS/SKIP counts so
# host-tooling absence doesn't false-FAIL.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
H="$ROOT/tests/test-tier-0-manifest.sh"
fail=0
if [ ! -f "$H" ]; then
  echo "FAIL: missing $H"
  exit 1
fi
if [ ! -x "$H" ]; then
  echo "FAIL: not executable $H"
  fail=$((fail + 1))
else
  echo "PASS: harness executable"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p02-tharn.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
set +e
ORCHESTRATOR_ROOT="$ROOT" bash "$H" >"$WORK/out.txt" 2>"$WORK/err.txt"
rc=$?
set -e

if [ "$rc" -le 1 ]; then
  echo "PASS: harness ran to completion (rc=$rc)"
else
  echo "FAIL: harness rc=$rc (expected 0 or 1; >1 means abort/syntax)"
  fail=$((fail + 1))
fi
if grep -qE '^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$' "$WORK/out.txt"; then
  echo "PASS: BATTERY: line emitted"
else
  echo "FAIL: BATTERY: line missing or malformed"
  fail=$((fail + 1))
fi

echo "SUMMARY: m036-p02-test-harness.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
