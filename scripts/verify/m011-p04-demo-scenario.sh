#!/usr/bin/env bash
# scripts/verify/m011-p04-demo-scenario.sh
# End-to-end demo-scenario verification for M011/P04.
#
# Reproduces the roadmap demo sentence:
#   A developer dispatches a task whose plan contains
#   scope_tags: [spec/requirement/SPEC-FR-003], and the context payload
#   includes only the SPEC-FR-003 chunk plus its related acceptance criteria
#   and constraints -- not the full spec.
#
# Builds a rich fixture (12+ spec entries including 5 requirements, 3
# acceptances, 2 constraints, 1 non-goal w/ relates_to edge to SPEC-FR-003,
# 1 superseded chain, 1 story) and asserts the in-scope / out-of-scope
# partition by invoking build-context.sh on a scoped task plan.
#
# Full P04 verify suite (all must PASS):
#   bash scripts/verify/m011-p04-bash32-compat.sh
#   bash scripts/verify/m011-p04-spec-scope-tag-resolve.sh
#   bash scripts/verify/m011-p04-spec-scope-tag-graph-neighbors.sh
#   bash scripts/verify/m011-p04-requirement-pulls-neighbors.sh
#   bash scripts/verify/m011-p04-spec-scope-excludes-non-goals.sh
#   bash scripts/verify/m011-p04-spec-scope-skips-superseded.sh
#   bash scripts/verify/m011-p04-dispatch-includes-spec-context.sh
#   bash scripts/verify/m011-p04-dispatch-omits-spec-context-when-unused.sh
#   bash scripts/verify/m011-p04-dispatch-excludes-out-of-scope.sh
#   bash scripts/verify/m011-p04-demo-scenario.sh
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

# --- Fixture milestone layout ---
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

Trivial body. The frontmatter `scope_tags` is what drives handle_spec_context.
TP

# Helper: write a spec chunk file with full frontmatter + body.
# Args: file id category relates_to supersedes superseded_by hash
write_entry() {
  local file="$1" id="$2" category="$3" relates="$4" supersedes="$5" superseded_by="$6" hash="$7"
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
supersedes: "${supersedes}"
superseded_by: "${superseded_by}"
relates_to: ${relates}
content_hash: "sha256:${hash}"
---

# ${id}: fixture entry

Body content for ${id}.
ENTRY
}

# --- Write rich fixture: 12 spec entries ---
# Requirements (5 total: FR-001, FR-002, FR-003, FR-004, FR-005-v1, FR-005-v2)
write_entry "$FIX/knowledge/spec/requirement/SPEC-FR-001.md"    SPEC-FR-001    spec/requirement "[]" "" "" r001
write_entry "$FIX/knowledge/spec/requirement/SPEC-FR-002.md"    SPEC-FR-002    spec/requirement "[]" "" "" r002
write_entry "$FIX/knowledge/spec/requirement/SPEC-FR-003.md"    SPEC-FR-003    spec/requirement "[SPEC-AC-007, SPEC-AC-008, SPEC-CON-001]" "" "" r003
write_entry "$FIX/knowledge/spec/requirement/SPEC-FR-004.md"    SPEC-FR-004    spec/requirement "[]" "" "" r004
# Superseded chain: v1 -> v2
write_entry "$FIX/knowledge/spec/requirement/SPEC-FR-005-v1.md" SPEC-FR-005-v1 spec/requirement "[]" "" "SPEC-FR-005-v2" r005v1
write_entry "$FIX/knowledge/spec/requirement/SPEC-FR-005-v2.md" SPEC-FR-005-v2 spec/requirement "[]" "SPEC-FR-005-v1" "" r005v2

# Acceptances (3 total: AC-006, AC-007, AC-008)
write_entry "$FIX/knowledge/spec/acceptance/SPEC-AC-006.md"    SPEC-AC-006    spec/acceptance  "[]"            "" "" a006
write_entry "$FIX/knowledge/spec/acceptance/SPEC-AC-007.md"    SPEC-AC-007    spec/acceptance  "[SPEC-FR-003]" "" "" a007
write_entry "$FIX/knowledge/spec/acceptance/SPEC-AC-008.md"    SPEC-AC-008    spec/acceptance  "[SPEC-FR-003]" "" "" a008

# Constraints (2 total: CON-001, CON-002)
write_entry "$FIX/knowledge/spec/constraint/SPEC-CON-001.md"   SPEC-CON-001   spec/constraint  "[SPEC-FR-003]" "" "" c001
write_entry "$FIX/knowledge/spec/constraint/SPEC-CON-002.md"   SPEC-CON-002   spec/constraint  "[]"            "" "" c002

# Non-goal w/ relates_to edge to SPEC-FR-003 (exercises AD-7 exclusion)
write_entry "$FIX/knowledge/spec/non-goal/SPEC-NG-001.md"      SPEC-NG-001    spec/non-goal    "[SPEC-FR-003]" "" "" n001

# Story (unrelated)
write_entry "$FIX/knowledge/spec/story/SPEC-US-010.md"         SPEC-US-010    spec/story       "[]"            "" "" s010

# --- Build knowledge.db ---
PROJECT_ROOT="$FIX" bash "$REBUILD" > "$FIX/rebuild.log" 2>&1 || {
  echo "FAIL: rebuild-index.sh failed"
  cat "$FIX/rebuild.log"
  exit 1
}

# --- Run build-context.sh on the scoped task plan ---
stdout_file="$FIX/payload.txt"
stderr_file="$FIX/payload.err"
PROJECT_ROOT="$FIX" bash "$BUILD_CONTEXT" "$FIX/.orchestrator" M999 P01 T01 \
  > "$stdout_file" 2> "$stderr_file" || {
  echo "FAIL: build-context.sh exited non-zero"
  echo "stderr:"; cat "$stderr_file"
  exit 1
}

# --- Assertions ---
fail_count=0

# Present-checks: these strings MUST appear in the payload.
present_ids="## Spec Context
SPEC-FR-003
SPEC-AC-007
SPEC-AC-008
SPEC-CON-001"

while IFS= read -r needle; do
  [ -n "$needle" ] || continue
  if ! grep -qF "$needle" "$stdout_file"; then
    echo "FAIL: payload missing expected string: $needle"
    fail_count=$((fail_count + 1))
  fi
done <<PRESENT
$present_ids
PRESENT

# Absent-checks: these IDs MUST NOT appear anywhere in the payload.
# SPEC-FR-005 covers both SPEC-FR-005-v1 and SPEC-FR-005-v2 (prefix match).
absent_ids="SPEC-FR-001
SPEC-FR-002
SPEC-FR-004
SPEC-FR-005
SPEC-AC-006
SPEC-CON-002
SPEC-NG-001
SPEC-US-010"

while IFS= read -r needle; do
  [ -n "$needle" ] || continue
  if grep -qF "$needle" "$stdout_file"; then
    echo "FAIL: payload unexpectedly contains out-of-scope ID: $needle"
    fail_count=$((fail_count + 1))
  fi
done <<ABSENT
$absent_ids
ABSENT

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: demo scenario -- payload contains SPEC-FR-003 + related (AC-007, AC-008, CON-001) and excludes 8 out-of-scope IDs"
  exit 0
else
  echo "FAIL: $fail_count assertion(s) failed in demo scenario"
  echo "--- payload.txt (first 80 lines) ---"
  head -80 "$stdout_file"
  exit 1
fi
