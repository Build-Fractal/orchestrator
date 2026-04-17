#!/usr/bin/env bash
# scripts/verify/m011-p04-requirement-pulls-neighbors.sh
# Richer fixture: 3 requirements, 2 acceptances, 1 constraint. Only SPEC-AC-007
# and SPEC-CON-003 are wired to SPEC-FR-003 via relates_to. Asserts that
# --spec-scope-tags "spec/requirement/SPEC-FR-003" emits SPEC-FR-003 plus
# those two neighbors, and does NOT pull in the other unrelated requirements
# or the unrelated acceptance.
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

write_entry() {
  local file="$1"
  local id="$2"
  local category="$3"
  local relates="$4"
  local hash="$5"
  cat > "$file" <<ENTRY
---
id: ${id}
scope_tags: "[milestone:M999]"
category: ${category}
confidence: 0.80
created_at: 2026-04-16
last_verified: 2026-04-16
hit_count: 0
source_unit: "M999/P01"
source_type: spec-ingest
supersedes: ""
superseded_by: ""
relates_to: ${relates}
content_hash: "sha256:${hash}"
---

# ${id}: fixture entry

Body.
ENTRY
}

# Three requirements
write_entry "$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-001.md" "SPEC-FR-001" "spec/requirement" "[]" "r001"
write_entry "$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-002.md" "SPEC-FR-002" "spec/requirement" "[]" "r002"
write_entry "$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-003.md" "SPEC-FR-003" "spec/requirement" "[SPEC-AC-007, SPEC-CON-003]" "r003"

# Two acceptances -- only SPEC-AC-007 relates to FR-003
write_entry "$TMP_ROOT/knowledge/spec/acceptance/SPEC-AC-007.md" "SPEC-AC-007" "spec/acceptance" "[SPEC-FR-003]" "a007"
write_entry "$TMP_ROOT/knowledge/spec/acceptance/SPEC-AC-099.md" "SPEC-AC-099" "spec/acceptance" "[]" "a099"

# One constraint, related to FR-003
write_entry "$TMP_ROOT/knowledge/spec/constraint/SPEC-CON-003.md" "SPEC-CON-003" "spec/constraint" "[SPEC-FR-003]" "c003"

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

# Expected: SPEC-FR-003, SPEC-AC-007, SPEC-CON-003 (any order, initial first)
expect_present() {
  local id="$1"
  if ! grep -xqE "$id" "$stdout_file"; then
    echo "FAIL: expected $id in stdout"
    echo "stdout:"; cat "$stdout_file"
    echo "stderr:"; cat "$stderr_file"
    exit 1
  fi
}
expect_absent() {
  local id="$1"
  if grep -xqE "$id" "$stdout_file"; then
    echo "FAIL: did NOT expect $id in stdout but it appeared"
    echo "stdout:"; cat "$stdout_file"
    echo "stderr:"; cat "$stderr_file"
    exit 1
  fi
}

expect_present "SPEC-FR-003"
expect_present "SPEC-AC-007"
expect_present "SPEC-CON-003"

# Unrelated IDs must NOT appear
expect_absent "SPEC-FR-001"
expect_absent "SPEC-FR-002"
expect_absent "SPEC-AC-099"

echo "PASS: spec/requirement/SPEC-FR-003 pulled in only its relates_to neighbors (AC-007, CON-003)"
exit 0
