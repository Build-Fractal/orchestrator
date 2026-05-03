#!/usr/bin/env bash
# tools/verify/m036-p04-test-harness.sh -- M036 P04 T04.
# Permissive harness-shape verifier: asserts tests/test-reference-ingest-
# fixture.sh exists, is executable, runs to completion (rc<=1 -- rc=1 is
# fail-mode-but-still-emitted-BATTERY whereas rc=2+ would be syntax/abort),
# and emits a well-formed BATTERY: line as last stdout.
# Permissive on per-doc pass/fail count to capture shape contract without
# coupling to per-fixture-pass count. Pattern from M036/P03/T04.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
HARNESS="$ROOT/tests/test-reference-ingest-fixture.sh"
fail=0
if [ -f "$HARNESS" ]; then
  echo "PASS: harness exists $HARNESS"
else
  echo "FAIL: harness missing $HARNESS"
  echo "SUMMARY: m036-p04-test-harness.sh fail=1"
  exit 1
fi
if [ -x "$HARNESS" ]; then
  echo "PASS: harness executable"
else
  echo "FAIL: harness not executable"
  fail=$((fail + 1))
fi
OUT="$(mktemp "${TMPDIR:-/tmp}/m036-p04-test-harness.XXXXXX.txt")"
ORCHESTRATOR_ROOT="$ROOT" bash "$HARNESS" > "$OUT" 2>&1
rc=$?
if [ "$rc" -le 1 ]; then
  echo "PASS: harness rc=$rc (<=1 permissive)"
else
  echo "FAIL: harness rc=$rc (>1; syntax/abort)"
  fail=$((fail + 1))
fi
last_line="$(tail -n 1 "$OUT")"
if echo "$last_line" | grep -qE '^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$'; then
  echo "PASS: last line is well-formed BATTERY: $last_line"
else
  echo "FAIL: last line malformed: $last_line"
  fail=$((fail + 1))
fi
rm -f "$OUT"
echo "SUMMARY: m036-p04-test-harness.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
