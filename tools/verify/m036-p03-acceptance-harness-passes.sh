#!/usr/bin/env bash
# tools/verify/m036-p03-acceptance-harness-passes.sh -- M036 P03 T04.
# Asserts the SC-11 acceptance harness exits 0 (fail=0). This is the
# strict pass-rate gate — the test-harness shape verifier above is
# permissive on rc<=1 (covers the rc=1 in-progress shape).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
HARNESS="$ROOT/tests/test-tier-2-extraction-with-gate.sh"
TMP="$(mktemp "${TMPDIR:-/tmp}/m036-p03-acceptance.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
set +e
bash "$HARNESS" >"$TMP" 2>/dev/null
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  echo "PASS: SC-11 + SC-12 acceptance harness rc=0"
  echo "SUMMARY: m036-p03-acceptance-harness-passes.sh fail=0"
  exit 0
fi
echo "FAIL: SC-11 + SC-12 acceptance harness rc=$rc"
tail -n 5 "$TMP" >&2
echo "SUMMARY: m036-p03-acceptance-harness-passes.sh fail=1"
exit 1
