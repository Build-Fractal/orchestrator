#!/usr/bin/env bash
# scripts/verify/m012-p03-config-loud-fail.sh — M012/P03 T02 gate.
#
# Exercises the config-check script under empty + populated env fixtures.
# Fixture A: all env vars unset -> expect exit 1 + >=4 FAIL: lines.
# Fixture B: all env vars set   -> expect exit 0 + PASS: line.
# Writes only to /tmp; cleans up on exit. Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

GATE="$ROOT/scripts/diagnostics/wiki-giscus-config-check.sh"
if [ ! -f "$GATE" ]; then
  printf 'FAIL: %s not found\n' "$GATE" >&2
  exit 1
fi
if [ ! -x "$GATE" ]; then
  printf 'FAIL: %s not executable\n' "$GATE" >&2
  exit 1
fi

EMPTY_ERR="/tmp/m012-p03-giscus-empty.$$.err"
EMPTY_OUT="/tmp/m012-p03-giscus-empty.$$.out"
FULL_OUT="/tmp/m012-p03-giscus-full.$$.out"
FULL_ERR="/tmp/m012-p03-giscus-full.$$.err"
# shellcheck disable=SC2064
trap "rm -f '$EMPTY_ERR' '$EMPTY_OUT' '$FULL_OUT' '$FULL_ERR'" EXIT INT TERM

# Fixture A: all empty -> expect non-zero exit.
rc=0
env -i PATH="$PATH" bash "$GATE" --quiet >"$EMPTY_OUT" 2>"$EMPTY_ERR" || rc=$?
if [ "$rc" -eq 0 ]; then
  printf 'FAIL: expected non-zero exit with no env vars; got 0\n' >&2
  exit 1
fi

fails=$(grep -c '^FAIL:' "$EMPTY_ERR" | tr -d '[:space:]')
if [ "$fails" -lt 4 ]; then
  printf 'FAIL: expected >=4 FAIL: lines on empty env; got %d (see %s)\n' "$fails" "$EMPTY_ERR" >&2
  exit 1
fi

# Fixture B: all populated -> expect exit 0.
rc=0
env -i PATH="$PATH" \
  GISCUS_REPO=a \
  GISCUS_REPO_ID=b \
  GISCUS_CATEGORY=c \
  GISCUS_CATEGORY_ID=d \
  bash "$GATE" >"$FULL_OUT" 2>"$FULL_ERR" || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: expected exit 0 with all GISCUS_* env vars set; got %d (stderr=%s)\n' "$rc" "$FULL_ERR" >&2
  exit 1
fi
if ! grep -q '^PASS:' "$FULL_OUT"; then
  printf 'FAIL: expected PASS: line on populated env (stdout=%s)\n' "$FULL_OUT" >&2
  exit 1
fi

printf 'PASS: config-check loud-fails on empty env (%d FAIL: lines), passes on populated env\n' "$fails"
exit 0
