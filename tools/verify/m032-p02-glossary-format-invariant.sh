#!/usr/bin/env bash
# tools/verify/m032-p02-glossary-format-invariant.sh
#
# M032/P02/T03 verifier: asserts the orchestrator-repo-level wiki/glossary.md
# satisfies the US-6 format invariant.
#
# Checks:
#   (a) wiki/glossary.md exists at the orchestrator-repo root.
#   (b) Contains at least three `### TERM` level-3 headings.
#   (c) Term headings are alphabetized at file scope.
#   (d) Each `### TERM` heading has non-empty body content within 2 lines below.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
# Exit 0 on PASS; 1 on FAIL.

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
G="$ROOT/wiki/glossary.md"

if [ ! -f "$G" ]; then
  echo "FAIL: $G missing"
  exit 1
fi

# At least three ### TERM headings
HC=$(grep -c '^### ' "$G" 2>/dev/null || echo 0)
if [ "$HC" -lt 3 ]; then
  echo "FAIL: $G has only $HC '### TERM' headings; need >= 3"
  exit 1
fi

# Alphabetized: extract terms, compare to sorted version
TERMS_TMP=$(mktemp)
SORTED_TMP=$(mktemp)
trap 'rm -f "$TERMS_TMP" "$SORTED_TMP"' EXIT

grep '^### ' "$G" | sed 's/^### //' > "$TERMS_TMP"
LC_ALL=C sort "$TERMS_TMP" > "$SORTED_TMP"
if ! diff -q "$TERMS_TMP" "$SORTED_TMP" >/dev/null 2>&1; then
  echo "FAIL: $G entries not alphabetized"
  exit 1
fi

# Format invariant: each ### heading has non-empty body content within
# 2 lines below the heading. The body MAY be preceded by one blank line
# (canonical markdown style: heading, blank, body).
awk '
  /^### / { h = NR; next }
  h && NR <= h + 2 && NF > 0 { h = 0 }
  END {
    if (h) {
      printf "FAIL: heading at line %d has no body within 2 lines\n", h
      exit 1
    }
  }
' "$G" || exit 1

echo "PASS: m032-p02-glossary-format-invariant"
exit 0
