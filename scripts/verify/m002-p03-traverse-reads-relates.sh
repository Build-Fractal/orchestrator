#!/usr/bin/env bash
# Verifies traverse-graph.sh reads relates_to and returns related entry IDs.
set -eu
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
export PROJECT_ROOT="$TMPDIR"
mkdir -p "$TMPDIR/knowledge/convention" "$TMPDIR/knowledge/gotcha" "$TMPDIR/knowledge/archive"
touch "$TMPDIR/extension.yml"
cat > "$TMPDIR/KNOWLEDGE-INDEX.md" <<'HEADER'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
HEADER

# Create entry helper
create_entry() {
  local id="$1" category="$2" relates_to="$3" desc="$4"
  mkdir -p "$TMPDIR/knowledge/$category"
  cat > "$TMPDIR/knowledge/$category/$id.md" <<EOF
---
id: $id
scope_tags: "[project]"
category: $category
confidence: 0.90
created_at: 2026-04-01
last_verified: 2026-04-01
hit_count: 0
source_unit: "M002/P03"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: $relates_to
---

# $id: $desc

Body text for $id.
EOF
  echo "$id | [project] | $category | 0.90 | 2026-04-01 | verified:2026-04-01 | hits:0 | $desc" >> "$TMPDIR/KNOWLEDGE-INDEX.md"
}

# --- Setup ---
create_entry "MEM001" "convention" "[MEM002, MEM003]" "Entry with two relations"
create_entry "MEM002" "convention" "[]" "Related entry two"
create_entry "MEM003" "gotcha" "[]" "Related entry three"

# --- Run script under test ---
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
output="$(bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM001 2>/dev/null)" || true

# --- Assertions ---
if ! echo "$output" | grep -q "MEM002"; then
  echo "FAIL: traverse-graph.sh --id MEM001 did not return MEM002"
  exit 1
fi
if ! echo "$output" | grep -q "MEM003"; then
  echo "FAIL: traverse-graph.sh --id MEM001 did not return MEM003"
  exit 1
fi

echo "PASS: traverse-graph.sh reads relates_to and returns MEM002 and MEM003"
