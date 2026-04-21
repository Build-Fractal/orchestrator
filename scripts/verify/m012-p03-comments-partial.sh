#!/usr/bin/env bash
# scripts/verify/m012-p03-comments-partial.sh — M012/P03 T01 gate.
#
# Asserts wiki/overrides/partials/comments.html exists and carries the
# Giscus loader script with the required data-attrs. Read-only.
# Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

PARTIAL="$ROOT/wiki/overrides/partials/comments.html"

if [ ! -f "$PARTIAL" ]; then
  printf 'FAIL: %s not found\n' "$PARTIAL" >&2
  exit 1
fi

lines=$(wc -l < "$PARTIAL" | tr -d '[:space:]')
if [ "$lines" -lt 25 ]; then
  printf 'FAIL: %s too short: %d < 25 lines\n' "$PARTIAL" "$lines" >&2
  exit 1
fi

for needle in 'giscus.app/client.js' 'data-repo=' 'data-repo-id=' 'data-category=' 'data-mapping='; do
  if ! grep -qF "$needle" "$PARTIAL"; then
    printf 'FAIL: %s missing %s\n' "$PARTIAL" "$needle" >&2
    exit 1
  fi
done

printf 'PASS: comments partial looks well-formed (%d lines)\n' "$lines"
exit 0
