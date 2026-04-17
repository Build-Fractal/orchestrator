#!/usr/bin/env bash
set -euo pipefail
# Verify scope-filter.sh excludes spec/non-goal entries by default
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCOPE_FILTER="$PROJECT_ROOT/scripts/dispatch/scope-filter.sh"

# Use a temp directory
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Create a mock KNOWLEDGE-INDEX.md with a mix of categories
cat > "$TMP_ROOT/KNOWLEDGE-INDEX.md" <<'EOF'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
SPEC-FR-001 | [project] | spec/requirement | 0.90 | 2026-04-16 | verified:2026-04-16 | hits:0 | Test requirement
SPEC-NG-001 | [project] | spec/non-goal | 0.90 | 2026-04-16 | verified:2026-04-16 | hits:0 | Not building a wiki
SPEC-US-001 | [project] | spec/story | 0.90 | 2026-04-16 | verified:2026-04-16 | hits:0 | Ingest a spec
MEM001 | [project] | patterns | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:10 | Shell Script Conventions
EOF

# Run scope-filter in index mode (no --include-non-goals flag)
output=$(bash "$SCOPE_FILTER" "$TMP_ROOT/KNOWLEDGE-INDEX.md" "M011/P01" --type knowledge 2>&1)

# Verify non-goal entry is excluded
if echo "$output" | grep -q 'SPEC-NG-001'; then
  echo "FAIL: spec/non-goal entry SPEC-NG-001 was included (should be excluded by default)"
  echo "Output:"
  echo "$output"
  exit 1
fi

# Verify other spec entries are included
if ! echo "$output" | grep -q 'SPEC-FR-001'; then
  echo "FAIL: spec/requirement entry SPEC-FR-001 was excluded (should be included)"
  echo "Output:"
  echo "$output"
  exit 1
fi

if ! echo "$output" | grep -q 'SPEC-US-001'; then
  echo "FAIL: spec/story entry SPEC-US-001 was excluded (should be included)"
  echo "Output:"
  echo "$output"
  exit 1
fi

echo "PASS: scope-filter.sh excludes spec/non-goal entries by default"
exit 0
