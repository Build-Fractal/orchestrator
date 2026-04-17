#!/usr/bin/env bash
# scripts/verify/m011-p06-ingest-doc-reingest-contract.sh
# Assert commands/ingest.md documents the P03 re-ingest contract:
# SKIPPED:, SUPERSEDED:, REMOVED: output prefixes + --force gate.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/ingest.md"

fail=0

if [ ! -f "$DOC" ]; then
  printf 'FAIL[exists]: %s not found\n' "$DOC"
  exit 1
fi

REQUIRED="
SKIPPED:
SUPERSEDED:
REMOVED:
--force
"

for tok in $REQUIRED; do
  if ! grep -Fq -- "$tok" "$DOC"; then
    printf 'FAIL[reingest]: commands/ingest.md missing re-ingest token: %s\n' "$tok"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: commands/ingest.md documents the P03 re-ingest contract"
