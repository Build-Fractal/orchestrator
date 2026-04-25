#!/usr/bin/env bash
# scripts/verify/m026-p03-mem-graduation.sh
# Verifies M026/P03/T03: two graduated MEM entries exist and KNOWLEDGE-INDEX is rebuilt.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

pass=0; fail=0
_pass() { pass=$((pass+1)); echo "PASS: $1"; }
_fail() { fail=$((fail+1)); echo "FAIL: $1"; }

MEM029="${REPO_ROOT}/knowledge/patterns/MEM029.md"
MEM030="${REPO_ROOT}/knowledge/conventions/MEM030.md"
INDEX="${REPO_ROOT}/KNOWLEDGE-INDEX.md"

for f in "$MEM029" "$MEM030"; do
  base="$(basename "$f")"
  if [ ! -f "$f" ]; then _fail "${base}: file missing"; continue; fi
  if grep -q '^id: MEM' "$f"; then _pass "${base}: has frontmatter id field"; else _fail "${base}: missing 'id:' frontmatter"; fi
  if grep -q '^source_unit: "M026/P02"' "$f"; then _pass "${base}: source_unit pinned to M026/P02"; else _fail "${base}: source_unit not pinned to M026/P02"; fi
  if grep -q '^category:' "$f"; then _pass "${base}: has category field"; else _fail "${base}: missing 'category:' frontmatter"; fi
done

if grep -qE '^MEM029 ' "$INDEX"; then _pass "KNOWLEDGE-INDEX.md lists MEM029"; else _fail "KNOWLEDGE-INDEX.md missing MEM029"; fi
if grep -qE '^MEM030 ' "$INDEX"; then _pass "KNOWLEDGE-INDEX.md lists MEM030"; else _fail "KNOWLEDGE-INDEX.md missing MEM030"; fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then exit 1; fi
echo "PASS: $(basename "$0")"
exit 0
