#!/usr/bin/env bash
# Verifies build-context.sh increments hit_count (via increment-hits.sh) on
# every knowledge entry included in a dispatch payload.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

setup_fixture() {
  local root="$TMPDIR_TEST"

  # Orchestrator structure
  mkdir -p "$root/.orchestrator/milestones/M001/phases/P01/tasks"
  mkdir -p "$root/knowledge/convention"
  mkdir -p "$root/knowledge/gotcha"
  mkdir -p "$root/knowledge/archive"
  mkdir -p "$root/scripts/dispatch/lib"
  mkdir -p "$root/scripts/knowledge/lib"
  mkdir -p "$root/scripts/lib"
  mkdir -p "$root/scripts/state"
  mkdir -p "$root/scripts/telemetry"
  mkdir -p "$root/templates"

  # Copy real scripts into temp directory
  cp -R "$PROJECT_ROOT/scripts/dispatch/"* "$root/scripts/dispatch/"
  cp -R "$PROJECT_ROOT/scripts/knowledge/"* "$root/scripts/knowledge/"
  cp -R "$PROJECT_ROOT/scripts/lib/"* "$root/scripts/lib/"
  cp -R "$PROJECT_ROOT/scripts/state/"* "$root/scripts/state/"
  cp -R "$PROJECT_ROOT/scripts/telemetry/"* "$root/scripts/telemetry/"
  cp "$PROJECT_ROOT/templates/context-recipe.yaml" "$root/templates/" 2>/dev/null || true
  mkdir -p "$root/.orchestrator"

  # Roadmap
  cat > "$root/.orchestrator/milestones/M001/M001-ROADMAP.md" <<'ROADMAP'
---
schema_version: "1.0"
type: roadmap
milestone: "M001"
feature_ref: "001-test"
tier: "C"
---

## Phases

- [x] **P01**: Test Phase — "Test."
  - Risk: low
  - Depends: none
ROADMAP

  # Phase plan
  cat > "$root/.orchestrator/milestones/M001/phases/P01/P01-PLAN.md" <<'PLAN'
---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M001"
goal: "Test phase"
demo_sentence: "Test demo"
risk: "low"
depends_on: []
---

## Must-Haves

### Truths

- Test truth
  - Check: `echo PASS`
PLAN

  # Task plan
  cat > "$root/.orchestrator/milestones/M001/phases/P01/tasks/T01-PLAN.md" <<'TASK'
---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M001"
name: "Test task"
depends_on: []
---

## Description

Test task description.

## Steps

1. Do the thing.

## Must-Haves

- Test must-have.
TASK

  # Knowledge detail files with hit_count: 0
  cat > "$root/knowledge/convention/MEM001.md" <<'ENTRY'
---
id: MEM001
scope_tags: "[project]"
category: convention
confidence: 0.90
created_at: 2026-04-01
last_verified: 2026-04-01
hit_count: 0
source_unit: "M001/P01"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: []
---

# MEM001: Test convention entry

Body text for MEM001.
ENTRY

  # KNOWLEDGE-INDEX.md
  cat > "$root/KNOWLEDGE-INDEX.md" <<'INDEX'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
MEM001 | [project] | convention | 0.90 | 2026-04-01 | verified:2026-04-01 | hits:0 | Test convention entry
INDEX
}

# --- Setup ---
setup_fixture

# --- Verify initial state ---
initial_hits="$(grep 'hit_count:' "$TMPDIR_TEST/knowledge/convention/MEM001.md" | sed 's/.*hit_count: *//')"
if [ "$initial_hits" != "0" ]; then
  echo "FAIL: initial hit_count is $initial_hits, expected 0"
  exit 1
fi

# --- Run build-context.sh for task dispatch ---
export PROJECT_ROOT="$TMPDIR_TEST"
output="$(bash "$TMPDIR_TEST/scripts/dispatch/build-context.sh" \
  "$TMPDIR_TEST/.orchestrator" M001 P01 T01 2>/dev/null)" || true

# --- Assertions ---

# Check that MEM001 was included in the payload
if ! echo "$output" | grep -q "Body text for MEM001"; then
  echo "FAIL: MEM001 was not included in the dispatch payload"
  exit 1
fi

# Check that hit_count was incremented in the detail file
updated_hits="$(grep 'hit_count:' "$TMPDIR_TEST/knowledge/convention/MEM001.md" | sed 's/.*hit_count: *//')"
if [ "$updated_hits" = "0" ]; then
  echo "FAIL: hit_count was not incremented (still 0) after dispatch"
  exit 1
fi

if [ "$updated_hits" = "1" ]; then
  echo "PASS: build-context.sh incremented hit_count from 0 to 1 on included knowledge entry MEM001"
  exit 0
fi

# Accept any increment (could be more than 1 if traversal included it multiple times)
echo "PASS: build-context.sh incremented hit_count from 0 to $updated_hits on included knowledge entry MEM001"
