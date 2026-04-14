#!/usr/bin/env bash
# Verifies build-context.sh orders payload sections with static content first
# (knowledge, decisions, constraints) and dynamic content last (task plan,
# upstream summaries, state) for prompt caching optimization.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

setup_fixture() {
  local root="$TMPDIR_TEST"

  # Orchestrator structure
  mkdir -p "$root/.specify/orchestrator/milestones/M001/phases/P01/tasks"
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
  touch "$root/extension.yml"

  # Roadmap
  cat > "$root/.specify/orchestrator/milestones/M001/M001-ROADMAP.md" <<'ROADMAP'
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
  cat > "$root/.specify/orchestrator/milestones/M001/phases/P01/P01-PLAN.md" <<'PLAN'
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
  cat > "$root/.specify/orchestrator/milestones/M001/phases/P01/tasks/T01-PLAN.md" <<'TASK'
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

# --- Run build-context.sh for task dispatch ---
export PROJECT_ROOT="$TMPDIR_TEST"
output="$(bash "$TMPDIR_TEST/scripts/dispatch/build-context.sh" \
  "$TMPDIR_TEST/.specify/orchestrator" M001 P01 T01 2>/dev/null)" || true

# --- Assertions ---
# Find line numbers of key section headings to verify ordering.
# Static sections (knowledge, decisions) should appear before dynamic sections
# (upstream context, task plan, state context).

knowledge_line="$(echo "$output" | grep -n "^## Knowledge" | head -1 | cut -d: -f1)"
decisions_line="$(echo "$output" | grep -n "^## Decisions" | head -1 | cut -d: -f1)"
scope_line="$(echo "$output" | grep -n "^## Scope" | head -1 | cut -d: -f1)"
upstream_line="$(echo "$output" | grep -n "^## Upstream Context" | head -1 | cut -d: -f1)"
task_plan_line="$(echo "$output" | grep -n "^## Task Plan" | head -1 | cut -d: -f1)"
state_line="$(echo "$output" | grep -n "^## State Context" | head -1 | cut -d: -f1)"
constraints_line="$(echo "$output" | grep -n "^## Constraints" | head -1 | cut -d: -f1)"

# Verify sections exist
if [ -z "$knowledge_line" ]; then
  echo "FAIL: ## Knowledge section not found in output"
  exit 1
fi
if [ -z "$decisions_line" ]; then
  echo "FAIL: ## Decisions section not found in output"
  exit 1
fi
if [ -z "$task_plan_line" ]; then
  echo "FAIL: ## Task Plan section not found in output"
  exit 1
fi

# Knowledge (static) must appear before Task Plan (dynamic)
if [ "$knowledge_line" -ge "$task_plan_line" ]; then
  echo "FAIL: Knowledge (line $knowledge_line) appears after Task Plan (line $task_plan_line)"
  exit 1
fi

# Decisions (static) must appear before Upstream Context (dynamic)
if [ -n "$upstream_line" ] && [ "$decisions_line" -ge "$upstream_line" ]; then
  echo "FAIL: Decisions (line $decisions_line) appears after Upstream Context (line $upstream_line)"
  exit 1
fi

# Knowledge must appear before State Context (dynamic)
if [ -n "$state_line" ] && [ "$knowledge_line" -ge "$state_line" ]; then
  echo "FAIL: Knowledge (line $knowledge_line) appears after State Context (line $state_line)"
  exit 1
fi

# Constraints (static) must appear before Task Plan (dynamic) — FR-112
if [ -n "$constraints_line" ] && [ -n "$task_plan_line" ] && [ "$constraints_line" -ge "$task_plan_line" ]; then
  echo "FAIL: Constraints (line $constraints_line) appears after Task Plan (line $task_plan_line)"
  exit 1
fi

# Constraints (static) must appear before Upstream Context (dynamic) — FR-112
if [ -n "$constraints_line" ] && [ -n "$upstream_line" ] && [ "$constraints_line" -ge "$upstream_line" ]; then
  echo "FAIL: Constraints (line $constraints_line) appears after Upstream Context (line $upstream_line)"
  exit 1
fi

# Constraints (static) must appear before State Context (dynamic) — FR-112
if [ -n "$constraints_line" ] && [ -n "$state_line" ] && [ "$constraints_line" -ge "$state_line" ]; then
  echo "FAIL: Constraints (line $constraints_line) appears after State Context (line $state_line)"
  exit 1
fi

echo "PASS: build-context.sh orders static content (Knowledge, Decisions, Constraints) before dynamic content (Task Plan, Upstream, State)"
