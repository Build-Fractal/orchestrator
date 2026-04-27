#!/usr/bin/env bash
# scripts/verify/m018-p01-runtime-assumptions.sh — phase-truth verifier:
# "RUNTIME-ASSUMPTIONS.md (at repo root) carries an `### M018/P01:` entry
# with the four required subsections".
#
# Required subsections (literal substrings inside the entry body):
#   - **Claude Code assumption**
#   - **Codex/Cursor fallback**
#   - **Milestone / phase**
#   - **M009 obligation**
#
# AD-19 single-script-file shape, bash 3.2, MEM001 PASS/FAIL, exit 0/1.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUNTIME_FILE="$REPO_ROOT/RUNTIME-ASSUMPTIONS.md"

if [ ! -f "$RUNTIME_FILE" ]; then
  printf 'FAIL: RUNTIME-ASSUMPTIONS.md missing at %s\n' "$RUNTIME_FILE" >&2
  exit 1
fi

# Slice the M018/P01 entry: from `### M018/P01:` up to (but not including)
# the next `### ` heading or end of file.
ENTRY_FILE=$(mktemp)
trap 'rm -f "$ENTRY_FILE"' EXIT INT TERM

awk '
  /^### M018\/P01:/ { capture = 1; print; next }
  capture && /^### / { exit }
  capture { print }
' "$RUNTIME_FILE" > "$ENTRY_FILE"

if [ ! -s "$ENTRY_FILE" ]; then
  printf 'FAIL: M018/P01 entry not found in %s\n' "$RUNTIME_FILE" >&2
  exit 1
fi
printf 'PASS: M018/P01 entry present in RUNTIME-ASSUMPTIONS.md\n'

MISS_COUNT=0
for needle in '**Claude Code assumption**' '**Codex/Cursor fallback**' '**Milestone / phase**' '**M009 obligation**'; do
  if grep -qF "$needle" "$ENTRY_FILE"; then
    printf 'PASS: %s subsection present\n' "$needle"
  else
    printf 'FAIL: %s subsection missing\n' "$needle" >&2
    MISS_COUNT=$((MISS_COUNT + 1))
  fi
done

if [ "$MISS_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
