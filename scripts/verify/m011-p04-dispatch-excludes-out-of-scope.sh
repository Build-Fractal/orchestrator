#!/usr/bin/env bash
# scripts/verify/m011-p04-dispatch-excludes-out-of-scope.sh
# Fixture with three requirements (SPEC-FR-001, SPEC-FR-002, SPEC-FR-003) and
# a task scoped only to SPEC-FR-003. Asserts that build-context.sh emits
# SPEC-FR-003's body in the Spec Context section but does NOT emit the bodies
# of the unrelated SPEC-FR-001 or SPEC-FR-002.
#
# Output: PASS: or FAIL: prefixed lines. Exit 0 on pass, 1 on fail.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_CONTEXT="$PROJECT_ROOT_REPO/scripts/dispatch/build-context.sh"
REBUILD="$PROJECT_ROOT_REPO/scripts/knowledge/rebuild-index.sh"

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

mkdir -p "$FIX/.orchestrator/milestones/M999/phases/P01/tasks"
for sub in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$FIX/knowledge/spec/$sub"
done

cat > "$FIX/.orchestrator/milestones/M999/M999-ROADMAP.md" <<'ROAD'
---
milestone: M999
tier: C
---

# M999 Roadmap

- [ ] **P01**: Fixture phase
  - Risk: low
  - Depends: none
ROAD

cat > "$FIX/.orchestrator/milestones/M999/phases/P01/P01-PLAN.md" <<'PP'
# P01 Phase Plan

## Goal
Fixture goal.

## Demo
Fixture demo.

## Must-Haves

- none
PP

cat > "$FIX/.orchestrator/milestones/M999/phases/P01/tasks/T01-PLAN.md" <<'TP'
---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M999"
scope_tags: [spec/requirement/SPEC-FR-003]
---

# T01 Fixture Task Plan

Trivial body.
TP

write_entry() {
  local file="$1" id="$2" category="$3" relates="$4" hash="$5"
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

Body for ${id} -- ${id}-BODY-MARKER.
ENTRY
}

# Three unrelated requirements — only SPEC-FR-003 is in scope
write_entry "$FIX/knowledge/spec/requirement/SPEC-FR-001.md" SPEC-FR-001 spec/requirement "[]" r001
write_entry "$FIX/knowledge/spec/requirement/SPEC-FR-002.md" SPEC-FR-002 spec/requirement "[]" r002
write_entry "$FIX/knowledge/spec/requirement/SPEC-FR-003.md" SPEC-FR-003 spec/requirement "[]" r003

PROJECT_ROOT="$FIX" bash "$REBUILD" > "$FIX/rebuild.log" 2>&1 || {
  echo "FAIL: rebuild-index.sh failed"
  cat "$FIX/rebuild.log"
  exit 1
}

stdout_file="$FIX/payload.txt"
stderr_file="$FIX/payload.err"
PROJECT_ROOT="$FIX" bash "$BUILD_CONTEXT" "$FIX/.orchestrator" M999 P01 T01 \
  > "$stdout_file" 2> "$stderr_file" || {
  echo "FAIL: build-context.sh exited non-zero"
  echo "stderr:"; cat "$stderr_file"
  exit 1
}

# Assert: Spec Context header present
if ! grep -q '^## Spec Context$' "$stdout_file"; then
  echo "FAIL: payload missing ## Spec Context header"
  exit 1
fi

# Assert: SPEC-FR-003 body marker present
if ! grep -q 'SPEC-FR-003-BODY-MARKER' "$stdout_file"; then
  echo "FAIL: payload did not contain SPEC-FR-003 body marker"
  exit 1
fi

# Assert: SPEC-FR-001 body marker absent
if grep -q 'SPEC-FR-001-BODY-MARKER' "$stdout_file"; then
  echo "FAIL: payload unexpectedly contained SPEC-FR-001 body marker"
  exit 1
fi

# Assert: SPEC-FR-002 body marker absent
if grep -q 'SPEC-FR-002-BODY-MARKER' "$stdout_file"; then
  echo "FAIL: payload unexpectedly contained SPEC-FR-002 body marker"
  exit 1
fi

echo "PASS: dispatch payload includes SPEC-FR-003 body only; SPEC-FR-001/002 bodies excluded"
exit 0
