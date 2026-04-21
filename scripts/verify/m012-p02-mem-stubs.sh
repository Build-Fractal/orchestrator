#!/usr/bin/env bash
# scripts/verify/m012-p02-mem-stubs.sh — M012/P02 gate 2.
#
# Asserts:
#   - wiki/docs/knowledge/<category>/MEM###.md exists for every
#     knowledge/<category>/MEM*.md source.
#   - Each stub is ≤ 25 lines.
#   - Each stub carries exactly one include-markdown directive.
#   - Four section-index files are present (top-level + 3 categories).
#
# Bash 3.2 compatible — uses /tmp list files to avoid exit-in-subshell.

set -u

ROOT="${1:-$(pwd)}"

src_count=$(find "$ROOT/knowledge" -type f -name 'MEM*.md' 2>/dev/null | wc -l | tr -d ' ')
stub_count=$(find "$ROOT/wiki/docs/knowledge" -type f -name 'MEM*.md' 2>/dev/null \
  | grep -v '/index.md$' \
  | wc -l | tr -d ' ')

if [ "$src_count" != "$stub_count" ]; then
  printf 'FAIL: MEM stub count %s != source count %s\n' "$stub_count" "$src_count"
  exit 1
fi

fails="/tmp/m012-p02-mem-stubs.$$"
: > "$fails"

stublist="/tmp/m012-p02-mem-stubs.list.$$"
find "$ROOT/wiki/docs/knowledge" -type f -name 'MEM*.md' 2>/dev/null \
  | grep -v '/index.md$' > "$stublist"

while IFS= read -r stub; do
  [ -n "$stub" ] || continue
  lines=$(wc -l < "$stub" | tr -d ' ')
  if [ "$lines" -gt 25 ]; then
    printf 'FAIL: %s has %s lines (> 25)\n' "$stub" "$lines" >> "$fails"
  fi
  incs=$(grep -c 'include-markdown' "$stub")
  if [ "$incs" != "1" ]; then
    printf 'FAIL: %s has %s include-markdown directives (expected 1)\n' "$stub" "$incs" >> "$fails"
  fi
done < "$stublist"
rm -f "$stublist"

# Section indexes.
for p in \
  "$ROOT/wiki/docs/knowledge/index.md" \
  "$ROOT/wiki/docs/knowledge/patterns/index.md" \
  "$ROOT/wiki/docs/knowledge/conventions/index.md" \
  "$ROOT/wiki/docs/knowledge/lessons/index.md"; do
  if [ ! -f "$p" ]; then
    printf 'FAIL: missing section index %s\n' "$p" >> "$fails"
    continue
  fi
  if ! grep -qF 'Auto-generated section index' "$p"; then
    printf 'FAIL: %s missing "Auto-generated section index" probe\n' "$p" >> "$fails"
  fi
done

if [ -s "$fails" ]; then
  cat "$fails"
  rm -f "$fails"
  exit 1
fi
rm -f "$fails"

printf 'PASS: %s MEM stubs + 4 section indexes present\n' "$stub_count"
exit 0
