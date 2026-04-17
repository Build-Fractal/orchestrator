#!/usr/bin/env bash
# scripts/verify/m021-p01-readme-catalog.sh — Asserts scripts/util/README.md
# names each of the three P01 wrappers and documents usage for each.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
README="${REPO_ROOT}/scripts/util/README.md"

fail_count=0

if [ ! -f "$README" ]; then
  echo "FAIL: scripts/util/README.md not found"
  exit 1
fi

for w in with-env.sh read-range.sh run-probe.sh; do
  if grep -q "$w" "$README"; then
    echo "PASS: README names $w"
  else
    echo "FAIL: README missing $w"
    fail_count=$((fail_count + 1))
  fi
done

# Each wrapper section must include a Usage line.
for w in with-env.sh read-range.sh run-probe.sh; do
  if grep -qE "Usage.*${w}|${w}.*Usage" "$README"; then
    echo "PASS: README documents Usage for $w"
  else
    echo "FAIL: README missing Usage for $w"
    fail_count=$((fail_count + 1))
  fi
done

# Catalog header present.
if grep -qE '^## Wrapper Catalog' "$README"; then
  echo "PASS: README has Wrapper Catalog heading"
else
  echo "FAIL: README missing Wrapper Catalog heading"
  fail_count=$((fail_count + 1))
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p01-readme-catalog.sh"
  exit 0
fi
echo "FAIL: m021-p01-readme-catalog.sh ($fail_count failures)"
exit 1
