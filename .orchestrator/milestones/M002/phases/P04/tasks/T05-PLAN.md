---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M002"
name: "End-to-end integration test"
depends_on: [T04]
---

## Prerequisites

- T01 through T04 are complete. All verification scripts exist and pass individually.
- build-context.sh correctly integrates with the M002 knowledge architecture.
- compress-payload.sh correctly handles compression with M002 knowledge entries.
- Payload ordering is FR-112 compliant (static first, dynamic last).
- Manifest headers are accurate.

## Description

Run a comprehensive end-to-end integration test that exercises the full dispatch pipeline with the M002 knowledge architecture:

1. Create a realistic fixture with multiple knowledge entries across categories, graph relationships, varying confidence scores, and a full orchestrator directory structure.
2. Run `build-context.sh` to produce a task-dispatch payload.
3. Verify the payload has correct manifest, correct ordering, and includes resolved knowledge entries.
4. Run `compress-payload.sh` on the payload with a tight budget to force all 3 compression steps.
5. Verify the compressed payload retains the task plan, has an updated manifest, and dropped low-confidence entries.
6. Verify hit counts were incremented on included entries.
7. Run `build-context.sh` again with `PHASE_PLAN` to test the planning branch.
8. Run all 8 verification scripts and confirm they pass.

## Steps

### Step 1: Run all 8 verification scripts

Run every verification script created in T01:

```
bash scripts/verify/m002-p04-uses-index-pipeline.sh
bash scripts/verify/m002-p04-planning-uses-index.sh
bash scripts/verify/m002-p04-manifest-header.sh
bash scripts/verify/m002-p04-static-first-ordering.sh
bash scripts/verify/m002-p04-increments-hits.sh
bash scripts/verify/m002-p04-compression-cascade.sh
bash scripts/verify/m002-p04-manifest-rebuild.sh
bash scripts/verify/m002-p04-budget-enforcement.sh
```

All 8 must print "PASS" and exit 0. If any fail, investigate and fix.

### Step 2: Fix any remaining failures

If any verification script fails at this stage, it indicates an issue that T02-T04 did not catch. Diagnose by reading the FAIL output, then apply the minimal fix.

Common late-stage failures:
- **Race conditions in hit incrementing**: increment-hits.sh modifies the detail file and index. If two entries are incremented in rapid succession, atomic writes should prevent corruption but verify the index is consistent after the run.
- **Manifest line range drift**: If a fix in T02-T04 changed the payload size, manifest line ranges may shift. Re-verify after each fix.
- **Compression edge cases**: Very small payloads may not trigger compression. Very large payloads may not compress enough. Ensure the test fixture sizes are appropriate.

### Step 3: Create and run a comprehensive E2E test

Create a standalone E2E test script at `scripts/verify/m002-p04-e2e.sh` that exercises the full pipeline:

```bash
#!/usr/bin/env bash
# scripts/verify/m002-p04-e2e.sh — Full E2E integration test for P04
# Tests: build-context -> compress-payload pipeline with M002 knowledge architecture
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ... (fixture setup - see Step 3a below)

pass_count=0
fail_count=0

check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $desc"
    pass_count=$((pass_count + 1))
  else
    echo "  FAIL: $desc"
    fail_count=$((fail_count + 1))
  fi
}

# ... (assertions - see Step 3b below)

echo ""
echo "E2E Results: $pass_count passed, $fail_count failed"
if [ "$fail_count" -gt 0 ]; then
  echo "FAIL: E2E integration test"
  exit 1
fi
echo "PASS: E2E integration test — full pipeline verified"
exit 0
```

**Step 3a: Fixture setup**

The E2E fixture should have:
- 5 knowledge entries: MEM001 (convention, 0.95, [project]), MEM002 (gotcha, 0.85, [project], relates_to: [MEM001]), MEM003 (convention, 0.60, [project]), MEM004 (convention, 0.40, [milestone:M001]), MEM005 (gotcha, 0.30, [project])
- A KNOWLEDGE-INDEX.md with all 5 entries
- A minimal roadmap with P01 (no dependencies)
- A phase plan and task plan for P01/T01
- A config-defaults.yaml with `context_budget: 30000`
- Copy all real scripts from PROJECT_ROOT into the temp directory

**Step 3b: Assertions**

The E2E test should verify:
1. `build-context.sh` runs successfully (exit 0)
2. Output contains `## Manifest` with correct table format
3. Output contains `## Knowledge` section with resolved entry content
4. Output contains "Body text for MEM001" (entry content was resolved)
5. Output contains "Body text for MEM002" (graph-traversed entry was resolved)
6. Knowledge section appears before Task Plan section (static-first ordering)
7. Decisions section appears before Upstream Context section (static-first ordering)
8. `compress-payload.sh --budget 2000` on the output produces a smaller payload
9. Compressed output still contains Task Plan content
10. Compressed output has a valid `## Manifest` table
11. Hit counts were incremented (check MEM001 detail file has hit_count >= 1)
12. Planning branch (`PHASE_PLAN` as task) also produces output with Knowledge section

### Step 4: Run the E2E test

```
bash scripts/verify/m002-p04-e2e.sh
```

Must print "PASS: E2E integration test" and exit 0.

### Step 5: Final verification summary

Print a summary of all verification results:
```
All P04 must-haves verified:
  [PASS] uses-index-pipeline
  [PASS] planning-uses-index
  [PASS] manifest-header
  [PASS] static-first-ordering
  [PASS] increments-hits
  [PASS] compression-cascade
  [PASS] manifest-rebuild
  [PASS] budget-enforcement
  [PASS] e2e integration
```

## Must-Haves

This task validates ALL 8 phase truths together and adds the E2E integration test.

## Verification

Run all 8 verification scripts plus the E2E test:

```
bash scripts/verify/m002-p04-uses-index-pipeline.sh
bash scripts/verify/m002-p04-planning-uses-index.sh
bash scripts/verify/m002-p04-manifest-header.sh
bash scripts/verify/m002-p04-static-first-ordering.sh
bash scripts/verify/m002-p04-increments-hits.sh
bash scripts/verify/m002-p04-compression-cascade.sh
bash scripts/verify/m002-p04-manifest-rebuild.sh
bash scripts/verify/m002-p04-budget-enforcement.sh
bash scripts/verify/m002-p04-e2e.sh
```

All 9 must print "PASS" and exit 0.

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p04-uses-index-pipeline.sh` (from T01)
  - Key API: Self-contained test. Exit 0 = PASS.
- `scripts/verify/m002-p04-planning-uses-index.sh` (from T01)
  - Key API: Self-contained test. Exit 0 = PASS.
- `scripts/verify/m002-p04-manifest-header.sh` (from T01)
  - Key API: Self-contained test. Exit 0 = PASS.
- `scripts/verify/m002-p04-static-first-ordering.sh` (from T01)
  - Key API: Self-contained test. Exit 0 = PASS.
- `scripts/verify/m002-p04-increments-hits.sh` (from T01)
  - Key API: Self-contained test. Exit 0 = PASS.
- `scripts/verify/m002-p04-compression-cascade.sh` (from T01)
  - Key API: Self-contained test. Exit 0 = PASS.
- `scripts/verify/m002-p04-manifest-rebuild.sh` (from T01)
  - Key API: Self-contained test. Exit 0 = PASS.
- `scripts/verify/m002-p04-budget-enforcement.sh` (from T01)
  - Key API: Self-contained test. Exit 0 = PASS.
- All fixes from T02 (knowledge integration), T03 (ordering/manifest), T04 (compression/budget) are applied.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — context builder. Usage: `build-context.sh <orch_root> <milestone> <phase> <task>`. Task can be `T##` or `PHASE_PLAN`. Output: payload on stdout, stats on stderr.
- `scripts/dispatch/compress-payload.sh` — compression. Usage: `compress-payload.sh --budget TOKENS --input FILE`. Output: compressed payload on stdout, stats on stderr.
- `scripts/knowledge/create-entry.sh` — creates detail files. Usage: `create-entry.sh --id MEM### --category cat --description "desc" --body "text" [--scope-tags "[project]"]`.
- `scripts/knowledge/increment-hits.sh` — increments hit_count. Usage: `increment-hits.sh --id MEM###`.
- `scripts/knowledge/lib/index-utils.sh` — provides `get_project_root()` (respects `PROJECT_ROOT` env var).
- `templates/context-recipe.yaml` — default recipe with 7 sections and 3 compression steps.

## Constraints

- Bash 3.2 compatible.
- The E2E test must be self-contained (creates its own fixture, cleans up).
- E2E test must use `PROJECT_ROOT` override for isolation.
- Do not modify any scripts in this task — only create the E2E test and run all verifications.
- If any verification fails, investigate and document the failure. If the fix is trivial (< 5 lines), apply it. If complex, create a note for follow-up.
- The E2E test script follows AD-19 single-script-file shape.

## Expected Output

1 new file created:
```
scripts/verify/m002-p04-e2e.sh
```

All 9 verification scripts pass:
```
PASS: build-context.sh task-dispatch uses knowledge index pipeline
PASS: build-context.sh planning branch uses knowledge index pipeline
PASS: build-context.sh produces manifest header with correct columns
PASS: build-context.sh orders static content before dynamic content
PASS: build-context.sh increments hit counts on included entries
PASS: compress-payload.sh applies compression cascade without truncating task plan
PASS: compress-payload.sh rebuilds manifest after compression
PASS: build-context.sh reports budget and compress-payload.sh respects it
PASS: E2E integration test — full pipeline verified
```
