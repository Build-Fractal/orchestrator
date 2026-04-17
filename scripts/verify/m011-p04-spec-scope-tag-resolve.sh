#!/usr/bin/env bash
# scripts/verify/m011-p04-spec-scope-tag-resolve.sh
# Creates a sandbox spec entry with no relates_to neighbors, invokes
# scope-filter.sh --spec-scope-tags, and asserts that stdout contains
# exactly the directly-referenced SPEC- ID on a line of its own.
#
# Output: PASS: or FAIL: prefixed lines. Exit 0 on pass, 1 on fail.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCOPE_FILTER="$PROJECT_ROOT_REPO/scripts/dispatch/scope-filter.sh"
REBUILD="$PROJECT_ROOT_REPO/scripts/knowledge/rebuild-index.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Sandbox needs .orchestrator marker so get_project_root in rebuild respects PROJECT_ROOT.
mkdir -p "$TMP_ROOT/.orchestrator"
for sub in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$sub"
done

# Fixture entry: SPEC-FR-001 with no relates_to neighbors.
cat > "$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-001.md" <<'ENTRY'
---
id: SPEC-FR-001
scope_tags: "[milestone:M999]"
category: spec/requirement
confidence: 0.80
created_at: 2026-04-16
last_verified: 2026-04-16
hit_count: 0
source_unit: "M999/P01"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: "sha256:aaa"
---

# SPEC-FR-001: solo requirement

Body.
ENTRY

# Rebuild index/DB
PROJECT_ROOT="$TMP_ROOT" bash "$REBUILD" > "$TMP_ROOT/rebuild.log" 2>&1 || {
  echo "FAIL: rebuild-index.sh failed"
  cat "$TMP_ROOT/rebuild.log"
  exit 1
}

# Invoke scope-filter
stdout_file="$TMP_ROOT/out.txt"
stderr_file="$TMP_ROOT/err.txt"
PROJECT_ROOT="$TMP_ROOT" bash "$SCOPE_FILTER" \
  --spec-scope-tags "spec/requirement/SPEC-FR-001" \
  > "$stdout_file" 2> "$stderr_file" || {
  echo "FAIL: scope-filter.sh exited non-zero"
  echo "stdout:"; cat "$stdout_file"
  echo "stderr:"; cat "$stderr_file"
  exit 1
}

# Assert: stdout contains exactly SPEC-FR-001 on a line of its own
got_line="$(grep -xE 'SPEC-FR-001' "$stdout_file" || true)"
if [ -z "$got_line" ]; then
  echo "FAIL: stdout did not contain SPEC-FR-001 on its own line"
  echo "stdout:"; cat "$stdout_file"
  echo "stderr:"; cat "$stderr_file"
  exit 1
fi

# Assert: no other SPEC- IDs leaked into output
extra="$(grep -E '^SPEC-' "$stdout_file" | grep -vxE 'SPEC-FR-001' || true)"
if [ -n "$extra" ]; then
  echo "FAIL: unexpected extra SPEC IDs in stdout:"
  echo "$extra"
  exit 1
fi

echo "PASS: --spec-scope-tags resolved spec/requirement/SPEC-FR-001 to SPEC-FR-001"
exit 0
