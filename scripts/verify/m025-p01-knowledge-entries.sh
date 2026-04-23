#!/usr/bin/env bash
# scripts/verify/m025-p01-knowledge-entries.sh -- M025/P01/T03 gate
# (will fail until T04 lands the knowledge entries):
#   - knowledge/lessons/MEM026.md exists; contains commit sha d33b8a7 and
#     the M013/P04/T04 regression reference.
#   - A matching pattern file (knowledge/patterns/MEM027.md or the next
#     available number) exists with merge-not-overwrite content.
#   - Both are indexed in KNOWLEDGE-INDEX.md.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

LESSON="${REPO_ROOT}/knowledge/lessons/MEM026.md"
INDEX="${REPO_ROOT}/KNOWLEDGE-INDEX.md"

# Lesson MEM026.
if [ ! -f "$LESSON" ]; then
  fail "knowledge/lessons/MEM026.md missing"
else
  pass "knowledge/lessons/MEM026.md exists"
  if grep -n 'd33b8a7' "$LESSON" >/dev/null 2>&1; then
    pass "MEM026.md references commit d33b8a7"
  else
    fail "MEM026.md missing commit sha d33b8a7"
  fi
  if grep -nE 'M013/P04/T04' "$LESSON" >/dev/null 2>&1; then
    pass "MEM026.md references M013/P04/T04"
  else
    fail "MEM026.md missing M013/P04/T04 reference"
  fi
fi

# Pattern (next available number after 026 -- T04 picks).
PATTERN_HIT=""
for n in 027 028 029 030; do
  candidate="${REPO_ROOT}/knowledge/patterns/MEM${n}.md"
  if [ -f "$candidate" ]; then
    if grep -n 'merge-not-overwrite' "$candidate" >/dev/null 2>&1; then
      PATTERN_HIT="knowledge/patterns/MEM${n}.md"
      break
    fi
  fi
done
if [ -n "$PATTERN_HIT" ]; then
  pass "pattern file present: ${PATTERN_HIT}"
else
  fail "no knowledge/patterns/MEM0##.md found containing 'merge-not-overwrite'"
fi

# Index lists both.
if [ ! -f "$INDEX" ]; then
  fail "KNOWLEDGE-INDEX.md missing"
else
  if grep -n 'MEM026' "$INDEX" >/dev/null 2>&1; then
    pass "KNOWLEDGE-INDEX.md lists MEM026"
  else
    fail "KNOWLEDGE-INDEX.md missing MEM026"
  fi
  if [ -n "$PATTERN_HIT" ]; then
    pn="$(basename "$PATTERN_HIT" .md)"
    if grep -n "$pn" "$INDEX" >/dev/null 2>&1; then
      pass "KNOWLEDGE-INDEX.md lists ${pn}"
    else
      fail "KNOWLEDGE-INDEX.md missing ${pn}"
    fi
  fi
fi

echo "SUMMARY: m025-p01-knowledge-entries.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m025-p01-knowledge-entries.sh"
  exit 0
fi
echo "FAIL: m025-p01-knowledge-entries.sh" >&2
exit 1
