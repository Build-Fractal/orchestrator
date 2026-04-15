#!/usr/bin/env bash
# Verifies build-context.sh task-dispatch branch uses the knowledge index
# pipeline (scope-filter on KNOWLEDGE-INDEX.md, traverse-graph.sh, resolve-entries.sh)
# when KNOWLEDGE-INDEX.md exists.
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

  # Knowledge detail files
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
relates_to: [MEM002]
---

# MEM001: Test convention entry

Body text for MEM001.
ENTRY

  cat > "$root/knowledge/gotcha/MEM002.md" <<'ENTRY'
---
id: MEM002
scope_tags: "[project]"
category: gotcha
confidence: 0.85
created_at: 2026-04-01
last_verified: 2026-04-01
hit_count: 0
source_unit: "M001/P01"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: [MEM001]
---

# MEM002: Test gotcha entry

Body text for MEM002.
ENTRY

  # KNOWLEDGE-INDEX.md
  cat > "$root/KNOWLEDGE-INDEX.md" <<'INDEX'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
MEM001 | [project] | convention | 0.90 | 2026-04-01 | verified:2026-04-01 | hits:0 | Test convention entry
MEM002 | [project] | gotcha | 0.85 | 2026-04-01 | verified:2026-04-01 | hits:0 | Test gotcha entry
INDEX
}

# --- Setup ---
setup_fixture

# --- Run build-context.sh for task dispatch ---
export PROJECT_ROOT="$TMPDIR_TEST"
output="$(bash "$TMPDIR_TEST/scripts/dispatch/build-context.sh" \
  "$TMPDIR_TEST/.orchestrator" M001 P01 T01 2>/dev/null)" || true

# --- Assertions ---

# 1. Output should contain resolved detail file content (not raw index lines)
if ! echo "$output" | grep -q "Body text for MEM001"; then
  echo "FAIL: task-dispatch output does not contain resolved detail file content for MEM001"
  exit 1
fi

# 2. Output should contain a Knowledge section header
if ! echo "$output" | grep -q "## Knowledge"; then
  echo "FAIL: task-dispatch output missing ## Knowledge section"
  exit 1
fi

# 3. Output should NOT contain raw pipe-delimited index lines (proving it resolved)
if echo "$output" | grep -q "| convention | 0.90 | 2026-04-01 | verified:"; then
  echo "FAIL: task-dispatch output contains raw index lines instead of resolved content"
  exit 1
fi

# 4. Output should contain the "resolved from index" comment marker
if ! echo "$output" | grep -q "knowledge entries resolved from index"; then
  echo "FAIL: task-dispatch output missing 'resolved from index' marker"
  exit 1
fi

echo "PASS: build-context.sh task-dispatch branch uses the knowledge index pipeline (scope-filter + traverse + resolve)"
