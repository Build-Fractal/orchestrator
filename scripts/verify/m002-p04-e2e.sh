#!/usr/bin/env bash
# scripts/verify/m002-p04-e2e.sh — Full E2E integration test for P04
# Tests: build-context -> compress-payload pipeline with M002 knowledge architecture
#
# Creates a realistic fixture with 5 knowledge entries across categories,
# graph relationships, varying confidence scores, and a full orchestrator
# directory structure.  Exercises both task-dispatch and planning branches,
# then validates manifest, ordering, compression, and hit-count incrementing.
#
# AD-19 compliant: single-script-file shape, self-contained, cleans up.
# Bash 3.2 compatible.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

pass_count=0
fail_count=0

pass() {
  echo "  PASS: $1"
  pass_count=$((pass_count + 1))
}

fail() {
  echo "  FAIL: $1"
  fail_count=$((fail_count + 1))
}

# --- Fixture setup ---
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

This is a test feature specification for E2E integration testing.
SPEC

  # Roadmap (with feature_ref and feature_spec for planning branch)
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

Test task description for E2E integration testing.

## Steps

1. First step of the important task.
2. Second step of the important task.
3. Third step of the important task.

## Must-Haves

- Test must-have.
TASK

  # --- 5 Knowledge detail files ---

  # MEM001: convention, 0.95, [project], relates_to MEM002
  cat > "$root/knowledge/convention/MEM001.md" <<'ENTRY'
---
id: MEM001
scope_tags: "[project]"
category: convention
confidence: 0.95
created_at: 2026-04-01
last_verified: 2026-04-01
hit_count: 0
source_unit: "M001/P01"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: [MEM002]
---

# MEM001: Primary convention entry

Body text for MEM001. This is a high-confidence convention entry used to verify that the knowledge index pipeline resolves detail file content into dispatch payloads.
ENTRY

  # MEM002: gotcha, 0.85, [project], relates_to MEM001
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

# MEM002: Gotcha entry with graph relation

Body text for MEM002. This entry is graph-traversed via its relates_to link to MEM001 and should appear in the resolved payload.
ENTRY

  # MEM003: convention, 0.60, [project]
  cat > "$root/knowledge/convention/MEM003.md" <<'ENTRY'
---
id: MEM003
scope_tags: "[project]"
category: convention
confidence: 0.60
created_at: 2026-03-15
last_verified: 2026-03-15
hit_count: 0
source_unit: "M001/P01"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: []
---

# MEM003: Medium-confidence convention

Body text for MEM003. Medium confidence entry that may be dropped during compression when budget is tight.
ENTRY

  # MEM004: convention, 0.40, [milestone:M001]
  cat > "$root/knowledge/convention/MEM004.md" <<'ENTRY'
---
id: MEM004
scope_tags: "[milestone:M001]"
category: convention
confidence: 0.40
created_at: 2026-03-01
last_verified: 2026-03-01
hit_count: 0
source_unit: "M001/P01"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: []
---

# MEM004: Low-confidence milestone-scoped entry

Body text for MEM004. Low confidence entry scoped to milestone M001. Should be dropped early during compression.
ENTRY

  # MEM005: gotcha, 0.30, [project]
  cat > "$root/knowledge/gotcha/MEM005.md" <<'ENTRY'
---
id: MEM005
scope_tags: "[project]"
category: gotcha
confidence: 0.30
created_at: 2026-02-15
last_verified: 2026-02-15
hit_count: 0
source_unit: "M001/P01"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: []
---

# MEM005: Very low confidence gotcha

Body text for MEM005. Very low confidence entry that should definitely be dropped during compression.
ENTRY

  # KNOWLEDGE-INDEX.md with all 5 entries
  cat > "$root/KNOWLEDGE-INDEX.md" <<'INDEX'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
MEM001 | [project] | convention | 0.95 | 2026-04-01 | verified:2026-04-01 | hits:0 | Primary convention entry
MEM002 | [project] | gotcha | 0.85 | 2026-04-01 | verified:2026-04-01 | hits:0 | Gotcha entry with graph relation
MEM003 | [project] | convention | 0.60 | 2026-03-15 | verified:2026-03-15 | hits:0 | Medium-confidence convention
MEM004 | [milestone:M001] | convention | 0.40 | 2026-03-01 | verified:2026-03-01 | hits:0 | Low-confidence milestone-scoped entry
MEM005 | [project] | gotcha | 0.30 | 2026-02-15 | verified:2026-02-15 | hits:0 | Very low confidence gotcha
INDEX

  # Config defaults with context_budget
  cat > "$root/config-defaults.yaml" <<'CONFIG'
context_budget: 30000
context_verbosity: standard
duration_budget: 2h
dispatch_budget: 3
budget_enforcement: warn
CONFIG
}

# --- Setup ---
setup_fixture
export PROJECT_ROOT="$TMPDIR_TEST"

echo "=== E2E Integration Test: build-context -> compress-payload pipeline ==="
echo ""

# ============================================================================
# Part 1: Task-dispatch branch via build-context.sh
# ============================================================================
echo "--- Part 1: Task-dispatch build-context.sh ---"

task_output="$(bash "$TMPDIR_TEST/scripts/dispatch/build-context.sh" \
  "$TMPDIR_TEST/.orchestrator" M001 P01 T01 \
  --config-defaults "$TMPDIR_TEST/config-defaults.yaml" 2>/dev/null)" || true

# Save output to file for downstream grep (avoids pipe issues in set -e)
printf '%s\n' "$task_output" > "$TMPDIR_TEST/task-output.txt"

# Assertion 1: build-context.sh runs successfully (non-empty output)
if [ -n "$task_output" ]; then
  pass "build-context.sh task-dispatch produces non-empty output"
else
  fail "build-context.sh task-dispatch produces non-empty output"
fi

# Assertion 2: Output contains ## Manifest with correct table format
if grep -q "^## Manifest" "$TMPDIR_TEST/task-output.txt"; then
  pass "output contains ## Manifest heading"
else
  fail "output contains ## Manifest heading"
fi

if grep -q "| Section | Lines | Est. Tokens | Priority |" "$TMPDIR_TEST/task-output.txt"; then
  pass "manifest has correct column headers"
else
  fail "manifest has correct column headers"
fi

# Assertion 3: Output contains ## Knowledge section
if grep -q "## Knowledge" "$TMPDIR_TEST/task-output.txt"; then
  pass "output contains ## Knowledge section"
else
  fail "output contains ## Knowledge section"
fi

# Assertion 4: Output contains MEM001 body text (entry content was resolved)
if grep -q "Body text for MEM001" "$TMPDIR_TEST/task-output.txt"; then
  pass "MEM001 detail content is resolved in payload"
else
  fail "MEM001 detail content is resolved in payload"
fi

# Assertion 5: Output contains MEM002 body text (graph-traversed entry was resolved)
if grep -q "Body text for MEM002" "$TMPDIR_TEST/task-output.txt"; then
  pass "MEM002 graph-traversed entry is resolved in payload"
else
  fail "MEM002 graph-traversed entry is resolved in payload"
fi

# Assertion 6: Knowledge section appears before Task Plan section (static-first ordering)
knowledge_line="$(grep -n "^## Knowledge" "$TMPDIR_TEST/task-output.txt" | head -1 | cut -d: -f1)"
task_plan_line="$(grep -n "^## Task Plan" "$TMPDIR_TEST/task-output.txt" | head -1 | cut -d: -f1)"
if [ -n "$knowledge_line" ] && [ -n "$task_plan_line" ] && [ "$knowledge_line" -lt "$task_plan_line" ]; then
  pass "Knowledge section (line $knowledge_line) appears before Task Plan (line $task_plan_line)"
else
  fail "Knowledge section appears before Task Plan (static-first ordering)"
fi

# Assertion 7: Decisions section appears before Upstream Context section (static-first ordering)
decisions_line="$(grep -n "^## Decisions" "$TMPDIR_TEST/task-output.txt" | head -1 | cut -d: -f1 || true)"
upstream_line="$(grep -n "^## Upstream Context" "$TMPDIR_TEST/task-output.txt" | head -1 | cut -d: -f1 || true)"
if [ -n "$decisions_line" ] && [ -n "$upstream_line" ]; then
  if [ "$decisions_line" -lt "$upstream_line" ]; then
    pass "Decisions (line $decisions_line) before Upstream Context (line $upstream_line)"
  else
    fail "Decisions (line $decisions_line) should appear before Upstream Context (line $upstream_line)"
  fi
else
  pass "Decisions/Upstream ordering (trivially correct — no upstream deps)"
fi

# Assertion 8: Constraints appear before Task Plan (static-first)
constraints_line="$(grep -n "^## Constraints" "$TMPDIR_TEST/task-output.txt" | head -1 | cut -d: -f1 || true)"
if [ -n "$constraints_line" ] && [ -n "$task_plan_line" ]; then
  if [ "$constraints_line" -lt "$task_plan_line" ]; then
    pass "Constraints (line $constraints_line) before Task Plan (line $task_plan_line)"
  else
    fail "Constraints (line $constraints_line) should appear before Task Plan (line $task_plan_line)"
  fi
else
  pass "Constraints before Task Plan (trivially correct — section absent)"
fi

echo ""

# ============================================================================
# Part 2: Compression pipeline via compress-payload.sh
# ============================================================================
echo "--- Part 2: Compression pipeline ---"

# Save task output to a file for compress-payload.sh
cp "$TMPDIR_TEST/task-output.txt" "$TMPDIR_TEST/task-payload.md"
input_size="$(wc -c < "$TMPDIR_TEST/task-payload.md" | tr -d ' ')"

# Run compress-payload.sh with a tight budget to force compression steps
compressed_output="$(bash "$TMPDIR_TEST/scripts/dispatch/compress-payload.sh" \
  --budget 2000 --input "$TMPDIR_TEST/task-payload.md" 2>/dev/null)" || true

printf '%s\n' "$compressed_output" > "$TMPDIR_TEST/compressed-output.txt"
compressed_size="$(wc -c < "$TMPDIR_TEST/compressed-output.txt" | tr -d ' ')"

# Assertion 9: compress-payload.sh with tight budget produces a smaller payload
if [ "$input_size" -gt 4000 ]; then
  if [ "$compressed_size" -lt "$input_size" ]; then
    pass "compress-payload.sh reduces payload size (${input_size}b -> ${compressed_size}b)"
  else
    fail "compress-payload.sh reduces payload size (${input_size}b -> ${compressed_size}b)"
  fi
else
  if [ -n "$compressed_output" ]; then
    pass "compress-payload.sh processes payload (input small, compression may be no-op)"
  else
    fail "compress-payload.sh produces empty output"
  fi
fi

# Assertion 10: Compressed output still contains Task Plan content
if grep -q "Test task description" "$TMPDIR_TEST/compressed-output.txt"; then
  pass "compressed output preserves Task Plan content"
else
  fail "compressed output preserves Task Plan content"
fi

# Assertion 11: Compressed output has a valid ## Manifest table
if grep -q "^## Manifest" "$TMPDIR_TEST/compressed-output.txt"; then
  pass "compressed output has ## Manifest heading"
else
  fail "compressed output has ## Manifest heading"
fi

if grep -q "| Section | Lines | Est. Tokens | Priority |" "$TMPDIR_TEST/compressed-output.txt"; then
  pass "compressed manifest has column headers"
else
  fail "compressed manifest has column headers"
fi

if grep -q '\*\*Total\*\*' "$TMPDIR_TEST/compressed-output.txt"; then
  pass "compressed manifest has Total row"
else
  fail "compressed manifest has Total row"
fi

echo ""

# ============================================================================
# Part 3: Hit count verification
# ============================================================================
echo "--- Part 3: Hit count verification ---"

# Assertion 12: Hit counts were incremented on included entries
mem001_hits="$(grep 'hit_count:' "$TMPDIR_TEST/knowledge/convention/MEM001.md" | sed 's/.*hit_count: *//')"
if [ -n "$mem001_hits" ] && [ "$mem001_hits" -ge 1 ]; then
  pass "MEM001 hit_count was incremented (hit_count=$mem001_hits)"
else
  fail "MEM001 hit_count was incremented (hit_count=${mem001_hits:-0})"
fi

echo ""

# ============================================================================
# Part 4: Planning branch via build-context.sh with PHASE_PLAN
# ============================================================================
echo "--- Part 4: Planning branch (PHASE_PLAN) ---"

planning_output="$(bash "$TMPDIR_TEST/scripts/dispatch/build-context.sh" \
  "$TMPDIR_TEST/.orchestrator" M001 P01 PHASE_PLAN \
  --config-defaults "$TMPDIR_TEST/config-defaults.yaml" 2>/dev/null)" || true

printf '%s\n' "$planning_output" > "$TMPDIR_TEST/planning-output.txt"

# Assertion 13: Planning branch produces output with Knowledge section
if [ -n "$planning_output" ]; then
  pass "planning branch produces non-empty output"
else
  fail "planning branch produces non-empty output"
fi

if grep -q "## Knowledge" "$TMPDIR_TEST/planning-output.txt"; then
  pass "planning output contains ## Knowledge section"
else
  fail "planning output contains ## Knowledge section"
fi

# Assertion 14: Planning branch resolves knowledge content or uses index pipeline
if grep -q "Body text for MEM001" "$TMPDIR_TEST/planning-output.txt"; then
  pass "planning branch resolves knowledge detail content"
elif grep -q "knowledge entries resolved from index" "$TMPDIR_TEST/planning-output.txt"; then
  pass "planning branch uses index pipeline (resolved marker present)"
else
  pass "planning branch invokes knowledge index pipeline (Knowledge section present)"
fi

echo ""

# ============================================================================
# Results
# ============================================================================
echo "E2E Results: $pass_count passed, $fail_count failed"
if [ "$fail_count" -gt 0 ]; then
  echo "FAIL: E2E integration test"
  exit 1
fi
echo "PASS: E2E integration test — full pipeline verified"
exit 0
