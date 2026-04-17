#!/usr/bin/env bash
set -euo pipefail
# Verify scope-filter.sh includes spec/non-goal entries when --include-non-goals flag is present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCOPE_FILTER="$PROJECT_ROOT/scripts/dispatch/scope-filter.sh"

# Use a temp directory
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Create a mock KNOWLEDGE-INDEX.md
cat > "$TMP_ROOT/KNOWLEDGE-INDEX.md" <<'EOF'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
SPEC-FR-001 | [project] | spec/requirement | 0.90 | 2026-04-16 | verified:2026-04-16 | hits:0 | Test requirement
SPEC-NG-001 | [project] | spec/non-goal | 0.90 | 2026-04-16 | verified:2026-04-16 | hits:0 | Not building a wiki
SPEC-US-001 | [project] | spec/story | 0.90 | 2026-04-16 | verified:2026-04-16 | hits:0 | Ingest a spec
EOF

# Run scope-filter with --include-non-goals flag
output=$(bash "$SCOPE_FILTER" "$TMP_ROOT/KNOWLEDGE-INDEX.md" "M011/P01" --type knowledge --include-non-goals 2>&1)

# Verify non-goal entry IS included this time
if ! echo "$output" | grep -q 'SPEC-NG-001'; then
  echo "FAIL: spec/non-goal entry SPEC-NG-001 was excluded even with --include-non-goals flag"
  echo "Output:"
  echo "$output"
  exit 1
fi

# Verify other entries are still included too
if ! echo "$output" | grep -q 'SPEC-FR-001'; then
  echo "FAIL: spec/requirement entry SPEC-FR-001 was excluded"
  exit 1
fi

echo "PASS: scope-filter.sh includes spec/non-goal entries when --include-non-goals flag is present"
exit 0
