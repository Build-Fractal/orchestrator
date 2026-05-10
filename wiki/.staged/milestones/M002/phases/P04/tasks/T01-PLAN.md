---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M002"
name: "Create verification scripts for all P04 must-haves"
depends_on: []
---

## Prerequisites

- P01, P02, and P03 are complete. The knowledge storage foundation (detail files, index, CRUD scripts, lifecycle scripts, graph traversal, entry resolution) is fully delivered.
- `scripts/dispatch/build-context.sh` exists and is functional (from M001 + [M005](../../../../../milestones/M005/index.md) refactoring). It has two branches: a planning-payload branch (`_bc_assemble_planning_payload`) and a recipe-driven task-dispatch branch.
- `scripts/dispatch/compress-payload.sh` exists and is functional. It applies recipe-driven compression steps.

## Description

Create 8 verification scripts under `scripts/verify/m002-p04-*.sh`. Each script is a self-contained behavioral test that:
1. Creates a temporary directory with fixture data (knowledge detail files, KNOWLEDGE-INDEX.md, phase plans, task plans, roadmap, config).
2. Sets `PROJECT_ROOT` to the temp directory for isolation.
3. Runs `build-context.sh` or `compress-payload.sh` with the fixture data.
4. Asserts expected output/behavior.
5. Prints `PASS: <description>` on success or `FAIL: <description>` on failure.
6. Cleans up the temp directory via `trap`.

All scripts must be Bash 3.2 compatible (no associative arrays, no `mapfile`, no `readarray`).

## Steps

### Step 1: Create the shared fixture creation pattern

Each script needs a standardized fixture setup. Define this pattern inline in each script (do not create a shared library file). The pattern creates:

- A mock orchestrator directory at `$TMPDIR/.specify/orchestrator/milestones/M001/`
- A `KNOWLEDGE-INDEX.md` file with test entries
- Knowledge detail files under `knowledge/{category}/`
- A minimal `M001-ROADMAP.md` with phase P01 definition
- A minimal phase plan at `phases/P01/P01-PLAN.md`
- A minimal task plan at `phases/P01/tasks/T01-PLAN.md`

Standard fixture setup function (inline in each script):

```bash
#!/usr/bin/env bash
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
  cp "$PROJECT_ROOT/templates/context-recipe.yaml" "$root/templates/" 2>/dev/null || true
  
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

  cat > "$root/knowledge/convention/MEM003.md" <<'ENTRY'
---
id: MEM003
scope_tags: "[project]"
category: convention
confidence: 0.60
created_at: 2026-03-01
last_verified: 2026-03-01
hit_count: 0
source_unit: "M001/P01"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: []
---

# MEM003: Low confidence entry

Body text for MEM003 with lower confidence.
ENTRY

  # KNOWLEDGE-INDEX.md
  cat > "$root/KNOWLEDGE-INDEX.md" <<'INDEX'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
MEM001 | [project] | convention | 0.90 | 2026-04-01 | verified:2026-04-01 | hits:0 | Test convention entry
MEM002 | [project] | gotcha | 0.85 | 2026-04-01 | verified:2026-04-01 | hits:0 | Test gotcha entry
MEM003 | [project] | convention | 0.60 | 2026-03-01 | verified:2026-03-01 | hits:0 | Low confidence entry
INDEX
}
```

### Step 2: Create the 8 verification scripts

Create each script at the specified path. Each must follow the pattern above. Specific behaviors to test:

**2a. `scripts/verify/m002-p04-uses-index-pipeline.sh`**

Tests that the task-dispatch branch of build-context.sh uses KNOWLEDGE-INDEX.md when it exists.
- Setup: Create fixture with KNOWLEDGE-INDEX.md and detail files. Create a roadmap with P01 depending on nothing.
- Run: `bash "$root/scripts/dispatch/build-context.sh" "$root/.specify/orchestrator" M001 P01 T01`
- Assert: Output contains "Knowledge" in the manifest table AND the output contains text from the detail file bodies (e.g., "Body text for MEM001"). Also verify that the output uses the index pipeline by checking it does NOT contain the raw index lines (pipe-delimited format), but DOES contain the resolved detail file content.
- Exit 0 with "PASS" or exit 1 with "FAIL".

**2b. `scripts/verify/m002-p04-planning-uses-index.sh`**

Tests that the planning branch of build-context.sh uses KNOWLEDGE-INDEX.md.
- Setup: Same fixture but call with PHASE_PLAN as task.
- Run: `bash "$root/scripts/dispatch/build-context.sh" "$root/.specify/orchestrator" M001 P01 PHASE_PLAN`
- Assert: Output contains a Knowledge section. When there are matching entries in the index, the output should contain detail file content.
- Note: The planning branch may emit "No knowledge entries in scope" if scope-filter returns nothing. The test should either use `[project]` scoped entries (which always match) or verify that the scope filter is invoked on the index file.

**2c. `scripts/verify/m002-p04-manifest-header.sh`**

Tests that build-context.sh produces a manifest header with the correct columns.
- Setup: Standard fixture.
- Run: `bash "$root/scripts/dispatch/build-context.sh" "$root/.specify/orchestrator" M001 P01 T01`
- Assert: Output contains `## Manifest`, `| Section | Lines | Est. Tokens | Priority |`, and `|---------|-------|-------------|----------|`. Also verify at least one data row exists with the pipe-delimited format.

**2d. `scripts/verify/m002-p04-static-first-ordering.sh`**

Tests that static content appears before dynamic content in the payload.
- Setup: Standard fixture.
- Run: `bash "$root/scripts/dispatch/build-context.sh" "$root/.specify/orchestrator" M001 P01 T01`
- Assert: Find line numbers of "## Knowledge" and "## Task Plan" headings. Knowledge (static) must appear before Task Plan (dynamic). Also check that "## Decisions" appears before "## Upstream Context".

**2e. `scripts/verify/m002-p04-increments-hits.sh`**

Tests that build-context.sh increments hit counts on included knowledge entries.
- Setup: Standard fixture with MEM001 at hits:0 in the index. Override PROJECT_ROOT so increment-hits.sh writes to the temp dir.
- Run: `bash "$root/scripts/dispatch/build-context.sh" "$root/.specify/orchestrator" M001 P01 T01`
- Assert: After the run, check that the detail file for MEM001 has `hit_count: 1` (incremented from 0). Or check that KNOWLEDGE-INDEX.md now has `hits:1` for MEM001.

**2f. `scripts/verify/m002-p04-compression-cascade.sh`**

Tests that compress-payload.sh applies the 3-step compression cascade.
- Setup: Create a large payload (over 30000 tokens, ~120,000 characters) with a manifest header, an optional Constraints section, upstream summaries, knowledge entries, and a Task Plan section.
- Run: `bash "$root/scripts/dispatch/compress-payload.sh" --budget 5000 --input "$payload_file"`
- Assert: Output is shorter than input. Task Plan section is preserved (never truncated). Optional sections may be dropped. Knowledge entries may be dropped. Verify exit code is 0.

**2g. `scripts/verify/m002-p04-manifest-rebuild.sh`**

Tests that compress-payload.sh rebuilds the manifest after compression.
- Setup: Same as 2f — create a payload exceeding budget.
- Run: `bash "$root/scripts/dispatch/compress-payload.sh" --budget 5000 --input "$payload_file"`
- Assert: Output still contains `## Manifest` with a valid table. Line ranges in the manifest should differ from the original (since sections were removed/truncated). Token estimates should be smaller.

**2h. `scripts/verify/m002-p04-budget-enforcement.sh`**

Tests that build-context.sh respects the context budget.
- Setup: Standard fixture with a config-defaults file containing `context_budget: 1000` (very small to force compression). Need to verify that build-context.sh reads this config and passes it to compress-payload.sh.
- This test verifies the interface exists. If build-context.sh does not yet pipe to compress-payload.sh when over budget, this test documents the gap.
- Run: Attempt build-context and check that the budget is read from config. Since build-context.sh currently does NOT auto-pipe to compress-payload.sh (compression is a separate step in the dispatch flow), this test should verify that build-context.sh reports the token count to stderr and that compress-payload.sh can be run separately with --budget.
- Assert: stderr output from build-context.sh contains "Context payload:" with a byte count. compress-payload.sh with `--budget 1000` on the output produces a smaller payload.

### Step 3: Verify all scripts pass syntax check

Run `bash -n` on each script to ensure no syntax errors.

## Must-Haves

This task creates the verification infrastructure for ALL 8 phase truths.

## Verification

Run syntax validation on all 8 scripts:
```
bash -n scripts/verify/m002-p04-uses-index-pipeline.sh
bash -n scripts/verify/m002-p04-planning-uses-index.sh
bash -n scripts/verify/m002-p04-manifest-header.sh
bash -n scripts/verify/m002-p04-static-first-ordering.sh
bash -n scripts/verify/m002-p04-increments-hits.sh
bash -n scripts/verify/m002-p04-compression-cascade.sh
bash -n scripts/verify/m002-p04-manifest-rebuild.sh
bash -n scripts/verify/m002-p04-budget-enforcement.sh
```

All must exit 0.

## Inputs

### From Previous Tasks

None — this is the first task in P04.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — the script under test for 5 of 8 verification scripts. Usage: `build-context.sh <orch_root> <milestone> <phase> <task>` where task can be `T##` for task dispatch or `PHASE_PLAN` for planning payload. Output: assembled dispatch prompt on stdout. Stderr: "Context payload: X bytes" line. Sources: `scripts/lib/errors.sh`, `scripts/lib/events.sh`, `scripts/lib/run-context.sh`, `scripts/lib/recipe-parser.sh`, `scripts/dispatch/lib/section-handlers.sh`, `scripts/lib/payload-transforms.sh`, `scripts/lib/manifest-builder.sh`.
- `scripts/dispatch/compress-payload.sh` — the script under test for compression verification. Usage: `compress-payload.sh [--budget TOKENS] [--input FILE|-]`. Reads payload from file or stdin, applies compression cascade, outputs compressed payload on stdout. Default budget: 30000.
- `scripts/dispatch/scope-filter.sh` — filters KNOWLEDGE-INDEX.md by scope tag, category, confidence. Usage: `scope-filter.sh <file-path> <scope-context> [--type knowledge] [--depends P01,P03]`.
- `scripts/knowledge/traverse-graph.sh` — BFS graph traversal. Usage: `traverse-graph.sh --id MEM042 [--max-depth 1] [--max-entries 5]`. Output: one related entry ID per line.
- `scripts/knowledge/resolve-entries.sh` — resolves entry IDs to detail file content. Usage: `resolve-entries.sh MEM001 MEM002` or `echo "MEM001" | resolve-entries.sh`. Output: full detail file content per entry, blank-line separated.
- `scripts/knowledge/increment-hits.sh` — increments hit_count. Usage: `increment-hits.sh --id MEM###`. Delegates to `update-entry.sh --increment-hits`.
- `scripts/knowledge/lib/index-utils.sh` — provides `get_project_root()` (respects `PROJECT_ROOT` env var), `get_index_path()`, `format_index_entry()`.
- `scripts/knowledge/create-entry.sh` — creates detail files. Usage: `create-entry.sh --id MEM### --category cat --description "desc" --body "text" [--scope-tags "[project]"] [--confidence 0.90]`.
- `templates/context-recipe.yaml` — default recipe defining 7 sections (state, knowledge, decisions, upstream, scope, task_plan, constraints) with compression steps (drop_optional, summarize upstream 200 words, drop_lowest_confidence knowledge 0.5).

## Constraints

- Bash 3.2 compatible (no associative arrays, no `mapfile`, no `readarray`).
- Each verification script must be fully self-contained — inline fixture helpers, no shared test library.
- All temp directories must be cleaned up on exit (use `trap` for cleanup).
- Scripts must use `PROJECT_ROOT` env var to isolate from the real project.
- PASS/FAIL output format: `echo "PASS: description"` or `echo "FAIL: description"`.
- Exit 0 on PASS, exit 1 on FAIL.
- All Check: commands must use single-script-file shape (AD-19).

## Expected Output

8 new files created:
```
scripts/verify/m002-p04-uses-index-pipeline.sh
scripts/verify/m002-p04-planning-uses-index.sh
scripts/verify/m002-p04-manifest-header.sh
scripts/verify/m002-p04-static-first-ordering.sh
scripts/verify/m002-p04-increments-hits.sh
scripts/verify/m002-p04-compression-cascade.sh
scripts/verify/m002-p04-manifest-rebuild.sh
scripts/verify/m002-p04-budget-enforcement.sh
```

All pass `bash -n` syntax check. Some may FAIL when run if build-context.sh or compress-payload.sh need fixes (which T02-T04 will address).
