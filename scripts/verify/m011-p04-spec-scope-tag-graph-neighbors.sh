#!/usr/bin/env bash
# scripts/verify/m011-p04-spec-scope-tag-graph-neighbors.sh
# Creates SPEC-FR-002 with relates_to: [SPEC-AC-002] plus SPEC-AC-002,
# rebuilds the index/DB, then invokes scope-filter.sh --spec-scope-tags
# and asserts that BOTH IDs appear in stdout (initial ID plus 1-hop
# relates_to neighbor).
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

mkdir -p "$TMP_ROOT/.orchestrator"
for sub in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$sub"
done

# Fixture: SPEC-FR-002 with relates_to edge -> SPEC-AC-002
cat > "$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-002.md" <<'ENTRY'
---
id: SPEC-FR-002
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
relates_to: [SPEC-AC-002]
content_hash: "sha256:bbb"
---

# SPEC-FR-002: linked requirement

Body.
ENTRY

cat > "$TMP_ROOT/knowledge/spec/acceptance/SPEC-AC-002.md" <<'ENTRY'
---
id: SPEC-AC-002
scope_tags: "[milestone:M999]"
category: spec/acceptance
confidence: 0.80
created_at: 2026-04-16
last_verified: 2026-04-16
hit_count: 0
source_unit: "M999/P01"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
relates_to: [SPEC-FR-002]
content_hash: "sha256:ccc"
---

# SPEC-AC-002: linked acceptance

Body.
ENTRY

PROJECT_ROOT="$TMP_ROOT" bash "$REBUILD" > "$TMP_ROOT/rebuild.log" 2>&1 || {
  echo "FAIL: rebuild-index.sh failed"
  cat "$TMP_ROOT/rebuild.log"
  exit 1
}

stdout_file="$TMP_ROOT/out.txt"
stderr_file="$TMP_ROOT/err.txt"
PROJECT_ROOT="$TMP_ROOT" bash "$SCOPE_FILTER" \
  --spec-scope-tags "spec/requirement/SPEC-FR-002" \
  > "$stdout_file" 2> "$stderr_file" || {
  echo "FAIL: scope-filter.sh exited non-zero"
  echo "stdout:"; cat "$stdout_file"
  echo "stderr:"; cat "$stderr_file"
  exit 1
}

if ! grep -xqE 'SPEC-FR-002' "$stdout_file"; then
  echo "FAIL: stdout did not contain SPEC-FR-002 (initial ID)"
  echo "stdout:"; cat "$stdout_file"
  echo "stderr:"; cat "$stderr_file"
  exit 1
fi

if ! grep -xqE 'SPEC-AC-002' "$stdout_file"; then
  echo "FAIL: stdout did not contain SPEC-AC-002 (1-hop relates_to neighbor)"
  echo "stdout:"; cat "$stdout_file"
  echo "stderr:"; cat "$stderr_file"
  exit 1
fi

echo "PASS: --spec-scope-tags emitted SPEC-FR-002 and its 1-hop neighbor SPEC-AC-002"
exit 0
