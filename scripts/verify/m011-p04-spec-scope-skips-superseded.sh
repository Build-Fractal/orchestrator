#!/usr/bin/env bash
# scripts/verify/m011-p04-spec-scope-skips-superseded.sh
# Fixture: SPEC-FR-003 with superseded_by: SPEC-FR-003-v2. Asserts
# --spec-scope-tags "spec/requirement/SPEC-FR-003" emits no SPEC-FR-003
# on stdout and writes a WARN: line to stderr referencing SPEC-FR-003.
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

# SPEC-FR-003 superseded by SPEC-FR-003-v2
cat > "$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-003.md" <<'ENTRY'
---
id: SPEC-FR-003
scope_tags: "[milestone:M999]"
category: spec/requirement
confidence: 0.80
created_at: 2026-04-16
last_verified: 2026-04-16
hit_count: 0
source_unit: "M999/P01"
source_type: spec-ingest
supersedes: ""
superseded_by: "SPEC-FR-003-v2"
relates_to: []
content_hash: "sha256:r003old"
---

# SPEC-FR-003: superseded requirement

Body.
ENTRY

# Live successor
cat > "$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-003-v2.md" <<'ENTRY'
---
id: SPEC-FR-003-v2
scope_tags: "[milestone:M999]"
category: spec/requirement
confidence: 0.80
created_at: 2026-04-16
last_verified: 2026-04-16
hit_count: 0
source_unit: "M999/P01"
source_type: spec-ingest
supersedes: "SPEC-FR-003"
superseded_by: ""
relates_to: []
content_hash: "sha256:r003new"
---

# SPEC-FR-003-v2: successor

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
  --spec-scope-tags "spec/requirement/SPEC-FR-003" \
  > "$stdout_file" 2> "$stderr_file" || {
  echo "FAIL: scope-filter.sh exited non-zero"
  echo "stdout:"; cat "$stdout_file"
  echo "stderr:"; cat "$stderr_file"
  exit 1
}

# stdout must NOT contain SPEC-FR-003
if grep -xqE 'SPEC-FR-003' "$stdout_file"; then
  echo "FAIL: superseded SPEC-FR-003 appeared in stdout"
  echo "stdout:"; cat "$stdout_file"
  echo "stderr:"; cat "$stderr_file"
  exit 1
fi

# stderr must contain a WARN: line referencing SPEC-FR-003
if ! grep -qE 'WARN:.*SPEC-FR-003' "$stderr_file"; then
  echo "FAIL: expected WARN: line referencing SPEC-FR-003 on stderr"
  echo "stdout:"; cat "$stdout_file"
  echo "stderr:"; cat "$stderr_file"
  exit 1
fi

echo "PASS: superseded SPEC-FR-003 was skipped with WARN: on stderr"
exit 0
