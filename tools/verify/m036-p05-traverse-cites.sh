#!/usr/bin/env bash
# tools/verify/m036-p05-traverse-cites.sh — assert that traverse-graph.sh walks
# `cites` edges and emits the edge-type label on each result line.
#
# Stages a fixture knowledge tree under a mktemp PROJECT_ROOT containing one
# spec chunk (SPEC-FR-7) declaring `cites: [REF-cms-rule-483-20]` and the
# corresponding reference chunk. Rebuilds the graph DB. Invokes traverse-graph.sh
# with --edge-types cites --max-depth 1. Asserts the literal substring
# `REF-cms-rule-483-20|cites` appears in stdout.
#
# T02 of M036/P05: shape verifier for the --edge-types extension. Single-script-
# file invocation per AD-19.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Stage knowledge tree
mkdir -p "$tmpdir/knowledge/spec/requirement"
mkdir -p "$tmpdir/knowledge/reference/cms-rule"

# Spec chunk: cites the reference chunk
cat > "$tmpdir/knowledge/spec/requirement/SPEC-FR-7.md" <<'EOF_SPEC'
---
id: SPEC-FR-7
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
cites: [REF-cms-rule-483-20]
derived_from: []
applies_to_field: []
content_hash: ""
---

# SPEC-FR-7: fixture spec chunk citing a regulatory reference
EOF_SPEC

# Reference chunk: target of the cites edge, no outgoing edges
cat > "$tmpdir/knowledge/reference/cms-rule/REF-cms-rule-483-20.md" <<'EOF_REF'
---
id: REF-cms-rule-483-20
scope_tags: "[project]"
category: cms-rule
confidence: 0.95
created_at: 2026-05-01
last_verified: 2026-05-01
hit_count: 0
source_unit: "M036/P05"
source_type: regulatory
supersedes: ""
superseded_by: ""
relates_to: []
cites: []
derived_from: []
applies_to_field: []
content_hash: ""
---

# REF-cms-rule-483-20: fixture regulatory reference chunk
EOF_REF

# Build the staged graph DB
PROJECT_ROOT="$tmpdir" bash "$ROOT/scripts/knowledge/rebuild-index.sh" >/dev/null

# Sanity check: the edge row exists
db="$tmpdir/knowledge.db"
edge_count="$(sqlite3 "$db" "SELECT COUNT(*) FROM edges WHERE source_id='SPEC-FR-7' AND target_id='REF-cms-rule-483-20' AND edge_type='cites';")"
if [ "$edge_count" != "1" ]; then
  echo "FAIL: m036-p05-traverse-cites (precondition: cites edge not in DB; count=$edge_count)" >&2
  exit 1
fi

# Invoke the traverser with --edge-types cites
out="$(PROJECT_ROOT="$tmpdir" bash "$ROOT/scripts/knowledge/traverse-graph.sh" --id SPEC-FR-7 --edge-types cites --max-depth 1)"

# Assert the labeled substring appears
case "$out" in
  *"REF-cms-rule-483-20|cites"*)
    echo "PASS: m036-p05-traverse-cites (cites edge surfaced with label)"
    exit 0
    ;;
esac

echo "FAIL: m036-p05-traverse-cites (expected substring 'REF-cms-rule-483-20|cites' not found)" >&2
echo "actual output:" >&2
printf '%s\n' "$out" >&2
exit 1
