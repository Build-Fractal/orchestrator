#!/usr/bin/env bash
# scripts/verify/m012-p02-readme-policy.sh — M012/P02 gate 6.
#
# Asserts wiki/README.md has three required headings:
#   ## Link resolution
#   ## Running the link checker
#   ## Pre-deploy integration (P04)
# plus mentions wiki-link-check.sh and "mkdocs build --strict", and has
# at least 80 lines.
#
# Bash 3.2 compatible.

set -u

ROOT="${1:-$(pwd)}"
f="$ROOT/wiki/README.md"

if [ ! -f "$f" ]; then
  printf 'FAIL: %s missing\n' "$f"
  exit 1
fi

# Three required headings (exact match, anchored).
hdr1='^## Link resolution$'
hdr2='^## Running the link checker$'
hdr3='^## Pre-deploy integration \(P04\)$'

for hdr in "$hdr1" "$hdr2" "$hdr3"; do
  count=$(grep -c -E "$hdr" "$f")
  if [ "$count" != "1" ]; then
    printf 'FAIL: %s — expected 1 match for /%s/, got %s\n' "$f" "$hdr" "$count"
    exit 1
  fi
done

if ! grep -qF 'wiki-link-check.sh' "$f"; then
  printf 'FAIL: README missing wiki-link-check.sh reference\n'
  exit 1
fi

if ! grep -qF 'mkdocs build --strict' "$f"; then
  printf 'FAIL: README missing "mkdocs build --strict" reference\n'
  exit 1
fi

lines=$(wc -l < "$f" | tr -d ' ')
if [ "$lines" -lt 80 ]; then
  printf 'FAIL: README %s lines (< 80)\n' "$lines"
  exit 1
fi

printf 'PASS: README policy sections present (%s lines)\n' "$lines"
exit 0
