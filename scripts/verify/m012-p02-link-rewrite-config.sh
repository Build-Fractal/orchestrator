#!/usr/bin/env bash
# scripts/verify/m012-p02-link-rewrite-config.sh — M012/P02 gate 1.
#
# Asserts wiki/mkdocs.yml has:
#   - rewrite_relative_urls: true   (include-markdown plugin option)
#   - a "- toc" entry under markdown_extensions
#   - permalink: true               (under toc)
#
# Bash 3.2 compatible.

set -u

ROOT="${1:-$(pwd)}"
ymlfile="$ROOT/wiki/mkdocs.yml"

if [ ! -f "$ymlfile" ]; then
  printf 'FAIL: mkdocs.yml missing: %s\n' "$ymlfile"
  exit 1
fi

if ! grep -qF 'rewrite_relative_urls: true' "$ymlfile"; then
  printf 'FAIL: missing "rewrite_relative_urls: true" in %s\n' "$ymlfile"
  exit 1
fi

if ! grep -qE '^[[:space:]]*-[[:space:]]*toc' "$ymlfile"; then
  printf 'FAIL: missing "- toc" in markdown_extensions of %s\n' "$ymlfile"
  exit 1
fi

if ! grep -qE 'permalink:[[:space:]]*true' "$ymlfile"; then
  printf 'FAIL: missing "permalink: true" under toc in %s\n' "$ymlfile"
  exit 1
fi

printf 'PASS: link-rewrite config present (rewrite_relative_urls + toc.permalink)\n'
exit 0
