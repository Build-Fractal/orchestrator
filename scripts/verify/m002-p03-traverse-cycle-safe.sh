#!/usr/bin/env bash
# Verifies traverse-graph.sh handles cycles without infinite loops.
# MEM001 -> MEM002 -> MEM001 (cycle). Seed ID should be excluded from output.
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

# --- Setup: mutual cycle ---
create_entry "MEM001" "convention" "[MEM002]" "First in cycle"
create_entry "MEM002" "convention" "[MEM001]" "Second in cycle"

# --- Run script under test (with a timeout to catch infinite loops) ---
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
output=""
if command -v timeout >/dev/null 2>&1; then
  output="$(timeout 10 bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM001 2>/dev/null)" || true
else
  output="$(bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM001 2>/dev/null)" || true
fi

# --- Assertions ---
# MEM002 should appear exactly once
mem002_count=0
if [ -n "$output" ]; then
  mem002_count="$(echo "$output" | grep -c "MEM002" || true)"
fi
if [ "$mem002_count" -ne 1 ]; then
  echo "FAIL: MEM002 should appear exactly once, got $mem002_count times"
  exit 1
fi

# MEM001 (seed) should NOT appear in output
mem001_count=0
if [ -n "$output" ]; then
  mem001_count="$(echo "$output" | grep -c "MEM001" || true)"
fi
if [ "$mem001_count" -ne 0 ]; then
  echo "FAIL: seed MEM001 should not appear in output, but found $mem001_count times"
  exit 1
fi

echo "PASS: traverse-graph.sh handles cycles — MEM002 once, seed MEM001 excluded"
