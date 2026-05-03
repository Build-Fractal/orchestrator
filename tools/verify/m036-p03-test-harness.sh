#!/usr/bin/env bash
# tools/verify/m036-p03-test-harness.sh -- M036 P03 T04.
# Asserts the SC-11 acceptance harness exists, executes (rc<=1
# permissive: rc=1 still emits BATTERY in fail mode), and emits a
# well-formed BATTERY: line.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
HARNESS="$ROOT/tests/test-tier-2-extraction-with-gate.sh"
fail=0
if [ -f "$HARNESS" ] && [ -x "$HARNESS" ]; then
  echo "PASS: harness exists+executable"
else
  echo "FAIL: harness missing or non-executable at $HARNESS"
  echo "SUMMARY: m036-p03-test-harness.sh fail=1"
  exit 1
fi
TMP="$(mktemp "${TMPDIR:-/tmp}/m036-p03-harness.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
set +e
bash "$HARNESS" >"$TMP" 2>/dev/null
rc=$?
set -e
if [ "$rc" -le 1 ]; then
  echo "PASS: harness rc=$rc (<=1 permissive)"
else
  echo "FAIL: harness rc=$rc (expected <=1)"
  fail=$((fail + 1))
fi
last="$(tail -n 1 "$TMP")"
case "$last" in
  "BATTERY: pass="*" fail="*" skip="*)
    echo "PASS: BATTERY line shape: $last"
    ;;
  *)
    echo "FAIL: BATTERY line shape unexpected: $last"
    fail=$((fail + 1))
    ;;
esac
echo "SUMMARY: m036-p03-test-harness.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
