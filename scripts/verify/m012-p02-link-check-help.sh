#!/usr/bin/env bash
# scripts/verify/m012-p02-link-check-help.sh — M012/P02 gate 5.
#
# Asserts `bash scripts/diagnostics/wiki-link-check.sh --help` exits 0 and
# its output mentions --site, --root, --strict, and the classification
# rule keywords (In-scope, Out-of-scope, Broken).
#
# Bash 3.2 compatible.

set -u

ROOT="${1:-$(pwd)}"
script="$ROOT/scripts/diagnostics/wiki-link-check.sh"

if [ ! -f "$script" ]; then
  printf 'FAIL: %s missing\n' "$script"
  exit 1
fi

out=$(bash "$script" --help 2>&1)
rc=$?

if [ "$rc" != "0" ]; then
  printf 'FAIL: --help exit %s\n%s\n' "$rc" "$out"
  exit 1
fi

for kw in "--site" "--root" "--strict" "In-scope" "Out-of-scope" "Broken"; do
  if ! echo "$out" | grep -qF -e "$kw"; then
    printf 'FAIL: --help missing keyword: %s\n%s\n' "$kw" "$out"
    exit 1
  fi
done

printf 'PASS: --help enumerates all flags and classification rules\n'
exit 0
