#!/usr/bin/env bash
# scripts/verify/m011-p04-dispatch-omits-spec-context-when-unused.sh
# Asserts that when a task plan's scope_tags contain NO spec/* entries,
# build-context.sh omits the `## Spec Context` section entirely — no header,
# no manifest row.
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

# Task plan with NO spec/* entries in scope_tags
cat > "$FIX/.orchestrator/milestones/M999/phases/P01/tasks/T01-PLAN.md" <<'TP'
---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M999"
scope_tags: [project]
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

Body for ${id}.
ENTRY
}

# A spec entry exists on disk, but the task plan doesn't reference it via scope_tags.
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

# Assert: no ## Spec Context header anywhere in the payload
if grep -q '^## Spec Context$' "$stdout_file"; then
  echo "FAIL: payload contained '## Spec Context' even though no spec/* scope_tags were set"
  grep -n '^## ' "$stdout_file"
  exit 1
fi

# Assert: no manifest row for Spec Context
if grep -q '^| Spec Context ' "$stdout_file"; then
  echo "FAIL: manifest contained a 'Spec Context' row when no spec/* scope_tags were set"
  exit 1
fi

echo "PASS: dispatch payload omits ## Spec Context when no spec/* scope_tags are present"
exit 0
