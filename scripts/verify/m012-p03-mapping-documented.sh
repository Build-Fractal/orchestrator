#!/usr/bin/env bash
# scripts/verify/m012-p03-mapping-documented.sh — M012/P03 T04 gate.
#
# Asserts wiki/README.md carries the Giscus mapping + remap sections
# referencing both the remap and smoke scripts. Read-only.
# Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

README="$ROOT/wiki/README.md"

if [ ! -f "$README" ]; then
  printf 'FAIL: %s not found\n' "$README" >&2
  exit 1
fi

if ! grep -qE '^## Giscus mapping' "$README"; then
  printf 'FAIL: %s missing "## Giscus mapping" heading\n' "$README" >&2
  exit 1
fi
if ! grep -qF 'pathname' "$README"; then
  printf 'FAIL: %s missing "pathname" discussion\n' "$README" >&2
  exit 1
fi
if ! grep -qF 'wiki-giscus-remap.sh' "$README"; then
  printf 'FAIL: %s missing wiki-giscus-remap.sh reference\n' "$README" >&2
  exit 1
fi
if ! grep -qF 'wiki-giscus-smoke.sh' "$README"; then
  printf 'FAIL: %s missing wiki-giscus-smoke.sh reference\n' "$README" >&2
  exit 1
fi

printf 'PASS: README Giscus mapping section well-documented\n'
exit 0
