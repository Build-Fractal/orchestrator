#!/usr/bin/env bash
# scripts/verify/m012-p01-serve-smoke.sh — mkdocs strict build probe.
#
# If `mkdocs` is not on PATH, emits `SKIP: mkdocs not installed` and exits 0.
# Otherwise runs `bash scripts/wiki/wiki-serve.sh --probe` which performs a
# strict mkdocs build into a throwaway site-dir, then reports pass/fail.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
PROBE="$ROOT/scripts/wiki/wiki-serve.sh"

if ! command -v mkdocs >/dev/null 2>&1; then
  printf 'SKIP: m012-p01-serve-smoke mkdocs not installed (Tier 1 static only; UAT covers build)\n'
  exit 0
fi

if [ ! -f "$PROBE" ]; then
  printf 'FAIL: m012-p01-serve-smoke scripts/wiki/wiki-serve.sh not found\n'
  exit 1
fi

LOG="/tmp/m012-p01-serve-smoke-$$.log"
trap 'rm -f "$LOG"' EXIT INT TERM

if bash "$PROBE" --probe > "$LOG" 2>&1; then
  printf 'PASS: m012-p01-serve-smoke mkdocs --strict build succeeded\n'
  exit 0
fi

printf 'FAIL: m012-p01-serve-smoke mkdocs --strict build failed; last log lines:\n'
tail -n 20 "$LOG" 2>/dev/null | sed 's/^/  /'
exit 1
