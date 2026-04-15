#!/usr/bin/env bash
# Verifies traverse-graph.sh returns empty stdout and exit 0 when entry has no relates_to.
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

# --- Setup: entry with empty relates_to ---
create_entry "MEM001" "convention" "[]" "Lone entry no relations"

# --- Run script under test ---
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exit_code=0
output="$(bash "$REPO_ROOT/scripts/knowledge/traverse-graph.sh" --id MEM001 2>/dev/null)" || exit_code=$?

# --- Assertions ---
if [ "$exit_code" -ne 0 ]; then
  echo "FAIL: traverse-graph.sh should exit 0 for entry with no relations, got exit $exit_code"
  exit 1
fi

# Trim whitespace from output
trimmed="$(echo "$output" | sed '/^[[:space:]]*$/d')"
if [ -n "$trimmed" ]; then
  echo "FAIL: stdout should be empty for entry with no relations, got: $trimmed"
  exit 1
fi

echo "PASS: traverse-graph.sh returns empty stdout and exit 0 for entry with no relates_to"
