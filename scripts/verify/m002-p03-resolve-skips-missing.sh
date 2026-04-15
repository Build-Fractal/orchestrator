#!/usr/bin/env bash
# Verifies resolve-entries.sh skips missing entries gracefully (exit 0, warning on stderr).
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

# --- Setup: only MEM001 exists, MEM999 does not ---
create_entry "MEM001" "convention" "[]" "Entry that exists"

# --- Run script under test, capture stdout and stderr separately ---
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
stderr_file="$(mktemp)"
exit_code=0
output="$(bash "$REPO_ROOT/scripts/knowledge/resolve-entries.sh" MEM001 MEM999 2>"$stderr_file")" || exit_code=$?
stderr_output="$(cat "$stderr_file")"
rm -f "$stderr_file"

# --- Assertions ---
if [ "$exit_code" -ne 0 ]; then
  echo "FAIL: resolve-entries.sh should exit 0 even with missing entries, got exit $exit_code"
  exit 1
fi

if ! echo "$output" | grep -q "Body text for MEM001"; then
  echo "FAIL: stdout should contain MEM001 content"
  exit 1
fi

if ! echo "$stderr_output" | grep -q "MEM999"; then
  echo "FAIL: stderr should contain warning about missing MEM999"
  exit 1
fi

echo "PASS: resolve-entries.sh exits 0, outputs MEM001, warns about missing MEM999 on stderr"
