#!/usr/bin/env bash
# m020-p01-graduate-side-effect-scope.sh — assert graduate.sh single-entry
# path mutates ONLY the target entry file. Bash 3.2 safe. AD-19.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

for id in MEM901 MEM902; do
  cat > "$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
scope_tags: "[project]"
category: patterns
confidence: 0.5
created_at: 2026-04-25
last_verified: 2026-04-25
hit_count: 0
source_unit: "test"
source_type: test
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
status: candidate
---

# ${id}: Fixture
EOF
done

hash_before="$(md5 -q "$tmpdir/knowledge/patterns/MEM902.md" 2>/dev/null || md5sum "$tmpdir/knowledge/patterns/MEM902.md" | awk '{print $1}')"

export PROJECT_ROOT="$tmpdir"
bash "$SCRIPT" --rationale "scope test" MEM901 >/dev/null

hash_after="$(md5 -q "$tmpdir/knowledge/patterns/MEM902.md" 2>/dev/null || md5sum "$tmpdir/knowledge/patterns/MEM902.md" | awk '{print $1}')"

if [ "$hash_before" != "$hash_after" ]; then
  echo "FAIL: graduate.sh mutated MEM902 (untouched sibling)"
  exit 1
fi

echo "PASS: graduate.sh side-effect scope bounded to target entry"
exit 0
