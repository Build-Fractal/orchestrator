#!/usr/bin/env bash
# scripts/verify/m012-p01-index-placeholder.sh — wiki/docs/index.md is a
# placeholder.
#
# Checks: file exists, contains the word "placeholder" (case-insensitive),
# line count <= 30.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
INDEX="$ROOT/wiki/docs/index.md"

FAIL_COUNT=0
fail() {
  printf 'FAIL: m012-p01-index-placeholder %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

if [ ! -f "$INDEX" ]; then
  fail "wiki/docs/index.md not found"
  exit 1
fi

if ! grep -qi 'placeholder' "$INDEX"; then
  fail "wiki/docs/index.md does not contain the word 'placeholder'"
fi

LC=$(wc -l < "$INDEX" | tr -d ' ')
[ -z "$LC" ] && LC=0
if [ "$LC" -gt 30 ]; then
  fail "wiki/docs/index.md exceeds 30 lines (found $LC)"
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m012-p01-index-placeholder wiki/docs/index.md is a %s-line placeholder\n' "$LC"
  exit 0
fi
exit 1
