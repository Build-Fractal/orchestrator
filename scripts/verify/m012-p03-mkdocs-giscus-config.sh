#!/usr/bin/env bash
# scripts/verify/m012-p03-mkdocs-giscus-config.sh — M012/P03 T01 gate.
#
# Asserts wiki/mkdocs.yml declares theme.custom_dir + extra.giscus.*
# without breaking P01's nav-marker invariant. Read-only.
# Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

CFG="$ROOT/wiki/mkdocs.yml"

if [ ! -f "$CFG" ]; then
  printf 'FAIL: %s not found\n' "$CFG" >&2
  exit 1
fi

if ! grep -qE '^[[:space:]]+custom_dir:[[:space:]]+overrides' "$CFG"; then
  printf 'FAIL: %s missing "custom_dir: overrides" under theme:\n' "$CFG" >&2
  exit 1
fi

for key in 'repo:' 'repo_id:' 'category:' 'category_id:' 'mapping:'; do
  if ! grep -qE "^[[:space:]]+${key}" "$CFG"; then
    printf 'FAIL: %s missing extra.giscus.%s\n' "$CFG" "$key" >&2
    exit 1
  fi
done

env_count=$(grep -cE '!ENV \[GISCUS_[A-Z_]+,[[:space:]]*""\]' "$CFG" | tr -d '[:space:]')
if [ "$env_count" -lt 4 ]; then
  printf 'FAIL: expected >=4 !ENV GISCUS_* interpolations, found %d\n' "$env_count" >&2
  exit 1
fi

if ! grep -qE 'mapping:[[:space:]]*"pathname"' "$CFG"; then
  printf 'FAIL: %s mapping not set to "pathname"\n' "$CFG" >&2
  exit 1
fi

# P01 nav marker region must remain syntactically intact.
open_count=$(grep -cF '# >>> M012-P01 nav' "$CFG" | tr -d '[:space:]')
close_count=$(grep -cF '# <<< M012-P01 nav end' "$CFG" | tr -d '[:space:]')
if [ "$open_count" -ne 1 ] || [ "$close_count" -ne 1 ]; then
  printf 'FAIL: P01 nav markers corrupted (open=%d, close=%d)\n' "$open_count" "$close_count" >&2
  exit 1
fi

printf 'PASS: mkdocs.yml Giscus config well-formed (env_count=%d)\n' "$env_count"
exit 0
