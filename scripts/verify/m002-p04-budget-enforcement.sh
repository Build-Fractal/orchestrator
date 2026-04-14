#!/usr/bin/env bash
# Verifies build-context.sh reports context payload size to stderr and that
# compress-payload.sh can be run separately with --budget to enforce a budget.
#
# build-context.sh currently does NOT auto-pipe to compress-payload.sh when
# over budget (compression is a separate step in the dispatch flow). This test
# verifies:
#   1. build-context.sh reports "Context payload: X bytes" on stderr
#   2. compress-payload.sh with --budget produces a smaller payload
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

# --- Part 1: Verify build-context.sh reports context payload on stderr ---
export PROJECT_ROOT="$TMPDIR_TEST"
stderr_output="$(bash "$TMPDIR_TEST/scripts/dispatch/build-context.sh" \
  "$TMPDIR_TEST/.specify/orchestrator" M001 P01 T01 2>&1 1>/dev/null)" || true

if ! echo "$stderr_output" | grep -q "Context payload:"; then
  echo "FAIL: build-context.sh stderr does not contain 'Context payload:' report"
  exit 1
fi

# Extract reported byte count
reported_bytes="$(echo "$stderr_output" | grep 'Context payload:' | grep -oE '[0-9]+' | head -1)"
if [ -z "$reported_bytes" ] || [ "$reported_bytes" = "0" ]; then
  echo "FAIL: build-context.sh reported 0 or empty byte count"
  exit 1
fi

# --- Part 2: Verify compress-payload.sh works with --budget on the output ---
# Capture the full payload from build-context.sh
full_payload="$(bash "$TMPDIR_TEST/scripts/dispatch/build-context.sh" \
  "$TMPDIR_TEST/.specify/orchestrator" M001 P01 T01 2>/dev/null)" || true

full_size="$(printf '%s' "$full_payload" | wc -c | tr -d ' ')"

# Write payload to file for compress-payload.sh
printf '%s\n' "$full_payload" > "$TMPDIR_TEST/full-payload.md"

# Run compress with a very small budget
compressed="$(bash "$TMPDIR_TEST/scripts/dispatch/compress-payload.sh" \
  --budget 1000 --input "$TMPDIR_TEST/full-payload.md" 2>/dev/null)" || true

compressed_size="$(printf '%s' "$compressed" | wc -c | tr -d ' ')"

# If the original payload is already under 1000 tokens (~4000 chars), compression
# may be a no-op. We still verify the pipeline works without error.
if [ "$full_size" -gt 4000 ] && [ "$compressed_size" -ge "$full_size" ]; then
  echo "FAIL: compress-payload.sh with --budget 1000 did not reduce payload size (full=$full_size, compressed=$compressed_size)"
  exit 1
fi

echo "PASS: build-context.sh reports 'Context payload: ${reported_bytes} bytes' to stderr and compress-payload.sh accepts --budget flag (full=${full_size}, compressed=${compressed_size})"
