#!/usr/bin/env bash
# scripts/verify/m011-p05-roadmap-doc-references-chunks.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/roadmap.md"

required_patterns="spec/story|spec-story-graph.sh|scope-filter.sh|traverse-graph.sh|Chunks-first path|Raw-spec fallback"

IFS='|'
fail=0
for pat in $required_patterns; do
  if ! grep -Fq "$pat" "$DOC"; then
    printf 'FAIL: roadmap.md missing pattern: %s\n' "$pat"
    fail=1
  fi
done
unset IFS

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: roadmap.md references spec-chunk enumeration path"
