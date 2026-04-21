#!/usr/bin/env bash
# scripts/verify/m012-p03-smoke-contract.sh — M012/P03 T03 gate.
#
# Fixture-driven: builds a tmp HTML tree and asserts smoke script outcomes.
# Mixed fixture (one good, one bad) -> exit 1 + FAIL: line on stderr.
# All-good fixture                    -> exit 0 + PASS: line on stdout.
# Writes only to /tmp; cleans up on exit. Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

GATE="$ROOT/scripts/diagnostics/wiki-giscus-smoke.sh"
if [ ! -f "$GATE" ]; then
  printf 'FAIL: %s not found\n' "$GATE" >&2
  exit 1
fi
if [ ! -x "$GATE" ]; then
  printf 'FAIL: %s not executable\n' "$GATE" >&2
  exit 1
fi

FIX=$(mktemp -d -t m012-p03-smoke.XXXXXX)
MIXED_OUT="/tmp/m012-p03-smoke-mixed.$$.out"
MIXED_ERR="/tmp/m012-p03-smoke-mixed.$$.err"
GOOD_OUT="/tmp/m012-p03-smoke-good.$$.out"
GOOD_ERR="/tmp/m012-p03-smoke-good.$$.err"
# shellcheck disable=SC2064
trap "rm -rf '$FIX'; rm -f '$MIXED_OUT' '$MIXED_ERR' '$GOOD_OUT' '$GOOD_ERR'" EXIT INT TERM

printf '<html><body><script src="https://giscus.app/client.js"></script></body></html>\n' > "$FIX/good.html"
printf '<html><body>hello no giscus</body></html>\n' > "$FIX/bad.html"

rc=0
bash "$GATE" --site "$FIX" >"$MIXED_OUT" 2>"$MIXED_ERR" || rc=$?
if [ "$rc" -ne 1 ]; then
  printf 'FAIL: expected exit 1 on mixed fixture; got %d\n' "$rc" >&2
  exit 1
fi
if ! grep -qF 'FAIL:' "$MIXED_ERR"; then
  printf 'FAIL: expected FAIL: line on stderr for mixed fixture (err=%s)\n' "$MIXED_ERR" >&2
  exit 1
fi

# Replace the bad file; rerun.
printf '<html><body><script src="https://giscus.app/client.js"></script></body></html>\n' > "$FIX/bad.html"
rc=0
bash "$GATE" --site "$FIX" >"$GOOD_OUT" 2>"$GOOD_ERR" || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: expected exit 0 on all-good fixture; got %d (err=%s)\n' "$rc" "$GOOD_ERR" >&2
  exit 1
fi
if ! grep -q '^PASS:' "$GOOD_OUT"; then
  printf 'FAIL: expected PASS: line on stdout for all-good fixture (out=%s)\n' "$GOOD_OUT" >&2
  exit 1
fi

printf 'PASS: smoke script contract (mixed -> FAIL exit 1, all-good -> PASS exit 0)\n'
exit 0
