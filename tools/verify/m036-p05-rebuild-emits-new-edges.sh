#!/usr/bin/env bash
# tools/verify/m036-p05-rebuild-emits-new-edges.sh — assert that rebuild-index.sh
# populates edges from cites / derived_from / applies_to_field frontmatter.
#
# Stages a fixture chunk file under a mktemp knowledge/spec/requirement/ tree
# with frontmatter declaring all three new edge types. Invokes rebuild-index.sh
# against the staged tree via PROJECT_ROOT override. Asserts the resulting
# knowledge.db contains the expected edge rows.
#
# T01 of M036/P05: shape verifier for rebuild-index frontmatter -> edge inserts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Stage knowledge tree
mkdir -p "$tmpdir/knowledge/spec/requirement"
mkdir -p "$tmpdir/.orchestrator"

# Author fixture chunk with all three new edge types
cat > "$tmpdir/knowledge/spec/requirement/SPEC-A.md" <<'EOF_FIXTURE'
---
id: SPEC-A
scope_tags: "[project]"
category: spec/requirement
confidence: 0.9
created_at: 2026-05-01
last_verified: 2026-05-01
hit_count: 0
source_unit: "M036/P05"
source_type: spec
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
cites: [REF-X]
derived_from: [REF-Y]
applies_to_field: [staff_count]
---

# SPEC-A: fixture spec for new edge types
EOF_FIXTURE

# Run rebuild against the staged root
PROJECT_ROOT="$tmpdir" bash "$ROOT/scripts/knowledge/rebuild-index.sh" >/dev/null

db="$tmpdir/knowledge.db"
if [ ! -f "$db" ]; then
  echo "FAIL: m036-p05-rebuild-emits-new-edges (knowledge.db not produced at $db)" >&2
  exit 1
fi

# Assert each new edge row exists
cites_count="$(sqlite3 "$db" "SELECT COUNT(*) FROM edges WHERE source_id='SPEC-A' AND target_id='REF-X' AND edge_type='cites';")"
derived_count="$(sqlite3 "$db" "SELECT COUNT(*) FROM edges WHERE source_id='SPEC-A' AND target_id='REF-Y' AND edge_type='derived_from';")"
field_count="$(sqlite3 "$db" "SELECT COUNT(*) FROM edges WHERE source_id='SPEC-A' AND target_id='staff_count' AND edge_type='applies_to_field';")"

if [ "$cites_count" = "1" ] && [ "$derived_count" = "1" ] && [ "$field_count" = "1" ]; then
  echo "PASS: m036-p05-rebuild-emits-new-edges (cites=1 derived_from=1 applies_to_field=1)"
  exit 0
fi

echo "FAIL: m036-p05-rebuild-emits-new-edges (cites=$cites_count derived_from=$derived_count applies_to_field=$field_count)" >&2
exit 1
