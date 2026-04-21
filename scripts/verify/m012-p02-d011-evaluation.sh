#!/usr/bin/env bash
# scripts/verify/m012-p02-d011-evaluation.sh — M012/P02 gate 9.
#
# Asserts .orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md:
#   - exists, is ≥ 30 lines
#   - frontmatter has decision: D011 and milestone: M012
#   - body contains the literal "M020 promoted" conclusion
#   - body enumerates all three criteria rows
#     (Cross-refs, Reviewed, query surface)
#   - references DECISIONS.md and M012-CONTEXT.md
#
# Bash 3.2 compatible.

set -u

ROOT="${1:-$(pwd)}"
f="$ROOT/.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md"

if [ ! -f "$f" ]; then
  printf 'FAIL: %s missing\n' "$f"
  exit 1
fi

lines=$(wc -l < "$f" | tr -d ' ')
if [ "$lines" -lt 30 ]; then
  printf 'FAIL: D011-EVALUATION.md %s lines (< 30)\n' "$lines"
  exit 1
fi

# Frontmatter sanity (within first 10 lines).
if ! head -n 10 "$f" | grep -qE '^decision:[[:space:]]*"?D011"?'; then
  printf 'FAIL: frontmatter missing decision: D011\n'
  exit 1
fi

if ! head -n 10 "$f" | grep -qE '^milestone:[[:space:]]*"?M012"?'; then
  printf 'FAIL: frontmatter missing milestone: M012\n'
  exit 1
fi

# Conclusion.
if ! grep -qF 'M020 promoted' "$f"; then
  printf 'FAIL: missing "M020 promoted" conclusion\n'
  exit 1
fi

# Three criteria rows.
if ! grep -qE 'Cross-refs' "$f"; then
  printf 'FAIL: missing criterion (a) Cross-refs row\n'
  exit 1
fi

if ! grep -qE 'Reviewed' "$f"; then
  printf 'FAIL: missing criterion (b) Reviewed row\n'
  exit 1
fi

if ! grep -qE 'query surface' "$f"; then
  printf 'FAIL: missing criterion (c) query surface row\n'
  exit 1
fi

# References block cites both upstream artifacts.
if ! grep -qF 'DECISIONS.md' "$f"; then
  printf 'FAIL: missing DECISIONS.md reference\n'
  exit 1
fi

if ! grep -qF 'M012-CONTEXT.md' "$f"; then
  printf 'FAIL: missing M012-CONTEXT.md reference\n'
  exit 1
fi

printf 'PASS: D011-EVALUATION.md structured correctly (%s lines)\n' "$lines"
exit 0
