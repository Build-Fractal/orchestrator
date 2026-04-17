#!/usr/bin/env bash
# scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh
# Assert commands/evaluate.md references orchestrator:ingest at least once.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/evaluate.md"

if [ ! -f "$DOC" ]; then
  printf 'FAIL[exists]: %s not found\n' "$DOC"
  exit 1
fi

if ! grep -Fq -- "orchestrator:ingest" "$DOC"; then
  printf 'FAIL[evaluate-mentions-ingest]: commands/evaluate.md does not reference orchestrator:ingest\n'
  exit 1
fi

echo "PASS: commands/evaluate.md references orchestrator:ingest"
