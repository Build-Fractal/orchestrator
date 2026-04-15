#!/usr/bin/env bash
# Verifies traverse-graph.sh respects default max-entries cap of 5.
set -eu
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
export PROJECT_ROOT="$TMPDIR"
mkdir -p "$TMPDIR/knowledge/convention" "$TMPDIR/knowledge/gotcha" "$TMPDIR/knowledge/archive"
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

# --- Setup: MEM001 relates to 6 entries (exceeds default cap of 5) ---
create_entry "MEM001" "convention" "[MEM002, MEM003, MEM004, MEM005, MEM006, MEM007]" "Hub with six relations"
create_entry "MEM002" "convention" "[]" "Related two"
create_entry "MEM003" "convention" "[]" "Related three"
create_entry "MEM004" "convention" "[]" "Related four"
create_entry "MEM005" "gotcha" "[]" "Related five"
create_entry "MEM006" "gotcha" "[]" "Related six"
create_entry "MEM007" "gotcha" "[]" "Related seven"

# --- Run script under test ---
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
output="$(bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM001 2>/dev/null)" || true

# --- Assertions ---
line_count=0
if [ -n "$output" ]; then
  line_count="$(echo "$output" | wc -l | tr -d ' ')"
fi

if [ "$line_count" -gt 5 ]; then
  echo "FAIL: traverse-graph.sh returned $line_count entries, expected at most 5 (default cap)"
  exit 1
fi

echo "PASS: traverse-graph.sh returns at most 5 entries (default max-entries cap)"
