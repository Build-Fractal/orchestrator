#!/usr/bin/env bash
# scripts/verify/m011-p06-ingest-doc-conventions.sh
# Assert commands/ingest.md follows the shared command-file conventions
# (MEM012): frontmatter description, title, Prerequisites, Reference Files.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/ingest.md"

fail=0

if [ ! -f "$DOC" ]; then
  printf 'FAIL[exists]: %s not found\n' "$DOC"
  exit 1
fi

# Frontmatter must exist as the first non-empty line block.
if ! head -1 "$DOC" | grep -Fxq -- "---"; then
  printf 'FAIL[frontmatter]: commands/ingest.md missing leading --- fence\n'
  fail=1
fi

check_heading() {
  h="$1"
  if ! grep -Fxq -- "$h" "$DOC"; then
    printf 'FAIL[heading]: commands/ingest.md missing heading: %s\n' "$h"
    fail=1
  fi
}

check_heading "# speckit.orchestrator.ingest"
check_heading "## Prerequisites"
check_heading "## Reference Files"

# description: field in frontmatter.
if ! grep -q '^description:' "$DOC"; then
  printf 'FAIL[description]: commands/ingest.md frontmatter missing description: field\n'
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: commands/ingest.md follows MEM012 conventions"
