#!/usr/bin/env bash
# scripts/verify/m011-p06-ingest-doc-structure.sh
# Assert commands/ingest.md contains every required flag name,
# section heading, and user-facing entry-point identifier.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/ingest.md"

fail=0

if [ ! -f "$DOC" ]; then
  printf 'FAIL[exists]: %s not found\n' "$DOC"
  exit 1
fi

REQUIRED="
orchestrator:ingest
--spec-path
--slug
--milestone
scripts/knowledge/ingest-spec.sh
"

for p in $REQUIRED; do
  if ! grep -Fq -- "$p" "$DOC"; then
    printf 'FAIL[structure]: commands/ingest.md missing required token: %s\n' "$p"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: commands/ingest.md contains required structural tokens"
