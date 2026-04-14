#!/usr/bin/env bash
# Verifies resolve-entries.sh preserves entry IDs in output (in headings or frontmatter).
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
create_entry "MEM001" "convention" "[]" "First entry for ID check"
create_entry "MEM002" "gotcha" "[]" "Second entry for ID check"

# --- Run script under test ---
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
output="$(bash "$REPO_ROOT/scripts/knowledge/resolve-entries.sh" MEM001 MEM002 2>/dev/null)" || true

# --- Assertions ---
if ! echo "$output" | grep -q "MEM001"; then
  echo "FAIL: output does not contain MEM001 identifier"
  exit 1
fi
if ! echo "$output" | grep -q "MEM002"; then
  echo "FAIL: output does not contain MEM002 identifier"
  exit 1
fi

echo "PASS: resolve-entries.sh preserves MEM001 and MEM002 identifiers in output"
