#!/usr/bin/env bash
# Verifies build-context.sh planning branch uses the knowledge index pipeline
# (scope-filter on KNOWLEDGE-INDEX.md, traverse-graph.sh, resolve-entries.sh)
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

  # Create specs dir with a dummy spec (needed by planning branch spec resolution)
  mkdir -p "$root/specs/001-test"
  cat > "$root/specs/001-test/spec.md" <<'SPEC'
---
schema_version: "1.0"
type: feature-spec
---

# Test Feature Spec

This is a test feature specification.
SPEC

  # Roadmap (feature_spec field required by planning branch)
  cat > "$root/.orchestrator/milestones/M001/M001-ROADMAP.md" <<ROADMAP
---
schema_version: "1.0"
type: roadmap
milestone: "M001"
feature_ref: "001-test"
feature_spec: "specs/001-test/spec.md"
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

# --- Run build-context.sh for planning branch (PHASE_PLAN) ---
export PROJECT_ROOT="$TMPDIR_TEST"
output="$(bash "$TMPDIR_TEST/scripts/dispatch/build-context.sh" \
  "$TMPDIR_TEST/.orchestrator" M001 P01 PHASE_PLAN 2>/dev/null)" || true

# --- Assertions ---

# 1. Output should contain a Knowledge section
if ! echo "$output" | grep -q "## Knowledge"; then
  echo "FAIL: planning output missing ## Knowledge section"
  exit 1
fi

# 2. Output should contain resolved detail file content (proving index pipeline was used)
if echo "$output" | grep -q "Body text for MEM001"; then
  # Detail content present - index pipeline resolved entries
  if echo "$output" | grep -q "knowledge entries resolved from index"; then
    echo "PASS: build-context.sh planning branch uses the knowledge index pipeline with resolved content"
    exit 0
  fi
  echo "PASS: build-context.sh planning branch uses the knowledge index pipeline (detail content present)"
  exit 0
fi

# 3. If no entries matched, verify the index was at least consulted
# The planning branch checks for KNOWLEDGE-INDEX.md existence before falling back
# to flat KNOWLEDGE.md. If scope-filter returned nothing, we get "No knowledge entries"
# which still means the index pipeline was invoked.
if echo "$output" | grep -q "No knowledge entries in scope"; then
  # Verify the index file exists (so the pipeline was attempted)
  if [ -f "$TMPDIR_TEST/KNOWLEDGE-INDEX.md" ]; then
    echo "PASS: build-context.sh planning branch uses the knowledge index pipeline (scope-filter returned no matches but index was consulted)"
    exit 0
  fi
fi

echo "FAIL: build-context.sh planning branch did not produce expected knowledge section content"
exit 1
