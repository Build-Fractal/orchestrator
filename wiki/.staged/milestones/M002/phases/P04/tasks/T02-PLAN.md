---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M002"
name: "Validate and fix build-context.sh knowledge index integration"
depends_on: [T01]
---

## Prerequisites

- T01 is complete. Verification scripts exist at `scripts/verify/m002-p04-uses-index-pipeline.sh`, `scripts/verify/m002-p04-planning-uses-index.sh`, and `scripts/verify/m002-p04-increments-hits.sh`.
- P01, P02, P03 are complete. All knowledge CRUD scripts, lifecycle scripts, and graph traversal scripts are on disk and functional.

## Description

Validate that both branches of `scripts/dispatch/build-context.sh` correctly integrate with the M002 knowledge architecture. The existing code already has knowledge index support (added during M001/[M005](../../../../../milestones/M005/index.md) refactoring), but P04 needs to verify it works end-to-end with the P01-P03 delivered scripts and fix any integration issues.

The two branches are:
1. **Task-dispatch branch** (recipe-driven): Uses `scripts/dispatch/lib/section-handlers.sh` function `handle_knowledge()` which calls scope-filter, traverse-graph, resolve-entries, and writes included IDs to a file for hit incrementing.
2. **Planning branch**: Uses the inline `_bc_assemble_planning_payload()` function which calls `_bc_gather_knowledge_from_index()` with the same pipeline.

Both branches must:
- Detect KNOWLEDGE-INDEX.md at `$PROJECT_ROOT/KNOWLEDGE-INDEX.md` or `$MILESTONE_DIR/KNOWLEDGE-INDEX.md`
- Filter using `scope-filter.sh` with `--type knowledge` on the index file
- Traverse graph using `traverse-graph.sh --id <ID> --max-depth 1 --max-entries 5`
- Resolve entry content using `resolve-entries.sh` piped from deduplicated IDs
- Increment hit counts using `increment-hits.sh --id <ID>` for each included entry
- Fall back gracefully to flat KNOWLEDGE.md when no index exists

## Steps

### Step 1: Run the index pipeline verification scripts

Run these verification scripts from T01:
```
bash scripts/verify/m002-p04-uses-index-pipeline.sh
bash scripts/verify/m002-p04-planning-uses-index.sh
bash scripts/verify/m002-p04-increments-hits.sh
```

If all three pass, the integration is already correct. Skip to Step 4.

If any fail, proceed to Step 2 to diagnose and fix.

### Step 2: Diagnose failures in the knowledge pipeline

For each failing script, identify the root cause:

**Common failure modes:**

1. **KNOWLEDGE-INDEX.md not found**: Check index detection logic in both branches.
   - Task-dispatch branch: `handle_knowledge()` in `scripts/dispatch/lib/section-handlers.sh` lines 206-211 checks `${_SH_PROJECT_ROOT}/../KNOWLEDGE-INDEX.md` and `${ms_dir}/KNOWLEDGE-INDEX.md`.
   - Planning branch: `_bc_assemble_planning_payload()` in `scripts/dispatch/build-context.sh` lines 204-208 checks `$PROJECT_ROOT/KNOWLEDGE-INDEX.md` and `$MILESTONE_DIR/KNOWLEDGE-INDEX.md`.
   - Fix: If the paths don't match the fixture layout, adjust the detection logic to check `$PROJECT_ROOT/KNOWLEDGE-INDEX.md` first, then `$MILESTONE_DIR/KNOWLEDGE-INDEX.md`.

2. **scope-filter.sh returns empty**: The fixture entries are `[project]` scoped, which should always match. If scope-filter returns empty, check the `--type knowledge` flag and the auto-detection logic in scope-filter.sh lines 329-339 (it auto-detects index format by checking for `INDEX.md` in the filename or `MEM###` pipe lines in the content).

3. **traverse-graph.sh fails**: Check that `PROJECT_ROOT` is exported so `get_project_root()` in index-utils.sh returns the fixture directory. traverse-graph.sh sources index-utils.sh which provides `get_project_root()`.

4. **resolve-entries.sh returns empty**: Same PROJECT_ROOT issue. resolve-entries.sh uses `get_project_root()` to locate `knowledge/*/ID.md` files.

5. **increment-hits.sh fails silently**: increment-hits.sh delegates to update-entry.sh which sources index-utils.sh. Check that PROJECT_ROOT is set and that the detail file exists at `knowledge/{category}/MEM###.md`.

### Step 3: Fix identified issues

Apply targeted fixes to the failing code paths. Common fixes:

**Fix A: section-handlers.sh index detection path**

The `_SH_PROJECT_ROOT` in section-handlers.sh is computed as `$(cd "${_SH_DIR}/.." && pwd)` which resolves to the `scripts/` directory, not the project root. The knowledge index check `${_SH_PROJECT_ROOT}/../KNOWLEDGE-INDEX.md` may not resolve correctly when PROJECT_ROOT is overridden for testing.

If this is the issue, fix `handle_knowledge()` to also check `$PROJECT_ROOT/KNOWLEDGE-INDEX.md` when the `PROJECT_ROOT` env var is set:

```bash
# In handle_knowledge(), add before existing checks:
if [ -n "${PROJECT_ROOT:-}" ] && [ -f "${PROJECT_ROOT}/KNOWLEDGE-INDEX.md" ]; then
  knowledge_index="${PROJECT_ROOT}/KNOWLEDGE-INDEX.md"
fi
```

**Fix B: Export PROJECT_ROOT before calling pipeline scripts**

In build-context.sh, ensure `PROJECT_ROOT` is exported before calling scope-filter, traverse-graph, resolve-entries, and increment-hits:

```bash
export PROJECT_ROOT="$PROJECT_ROOT"
```

This is critical because these scripts source `index-utils.sh` which reads `PROJECT_ROOT` to locate the knowledge directory.

**Fix C: Hit count incrementing in task-dispatch branch**

In `build-context.sh`, the hit count incrementing logic (lines 595-601) reads from `$INCLUDED_IDS_FILE`. The task-dispatch branch forwards this file to `handle_knowledge()` via the 5th argument. Verify that `handle_knowledge()` actually writes IDs to this file (section-handlers.sh line 283: `cp "$sorted_file" "$included_ids_file"`).

### Step 4: Re-run verification scripts

Run all three verification scripts again:
```
bash scripts/verify/m002-p04-uses-index-pipeline.sh
bash scripts/verify/m002-p04-planning-uses-index.sh
bash scripts/verify/m002-p04-increments-hits.sh
```

All three must print "PASS" and exit 0.

## Must-Haves

This task addresses 3 of 8 phase truths:
- build-context.sh task-dispatch branch uses the knowledge index pipeline
- build-context.sh planning branch uses the knowledge index pipeline
- build-context.sh increments hit_count on included entries

## Verification

```
bash scripts/verify/m002-p04-uses-index-pipeline.sh
bash scripts/verify/m002-p04-planning-uses-index.sh
bash scripts/verify/m002-p04-increments-hits.sh
```

All three must print "PASS: ..." and exit 0.

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p04-uses-index-pipeline.sh` (from T01)
  - Key API: Self-contained test script. Run with `bash scripts/verify/...`. Exit 0 = PASS, exit 1 = FAIL.
- `scripts/verify/m002-p04-planning-uses-index.sh` (from T01)
  - Key API: Same as above.
- `scripts/verify/m002-p04-increments-hits.sh` (from T01)
  - Key API: Same as above.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — the primary script under modification. Has two branches:
  - Planning branch: `_bc_assemble_planning_payload()` (line ~200) calls `_bc_gather_knowledge_from_index()` which runs the scope-filter → traverse-graph → resolve-entries pipeline.
  - Task-dispatch branch: dispatches to `handle_knowledge()` in section-handlers.sh via `dispatch_section_handler()`.
  - Hit count incrementing: lines 595-601, reads IDs from `$INCLUDED_IDS_FILE` and calls `increment-hits.sh --id $eid`.
- `scripts/dispatch/lib/section-handlers.sh` — contains `handle_knowledge()` (line ~199) which implements the 5-step knowledge pipeline: (1) locate index, (2) scope-filter, (3) extract MEM IDs, (4) traverse graph, (5) resolve entries. Writes included IDs to an output file when the 5th argument is provided.
- `scripts/dispatch/scope-filter.sh` — `filter_knowledge_index()` function (line ~174). Reads KNOWLEDGE-INDEX.md line by line, filters by scope tag, category, confidence. Returns matching lines in same pipe-delimited format. Auto-detects index format by filename or content.
- `scripts/knowledge/traverse-graph.sh` — BFS graph traversal. Sources `scripts/knowledge/lib/index-utils.sh` for `get_project_root()`. Finds detail files via inline `find_detail_file()` which globs `$root/knowledge/*/ID.md`.
- `scripts/knowledge/resolve-entries.sh` — Accepts IDs on stdin or as args. Sources `scripts/knowledge/lib/index-utils.sh`. Uses `get_project_root()` then globs `$root/knowledge/*/ID.md`. Outputs file content, skips archived entries.
- `scripts/knowledge/increment-hits.sh` — Thin wrapper: `exec "$SCRIPT_DIR/update-entry.sh" "$@" --increment-hits`. update-entry.sh sources `scripts/knowledge/lib/index-utils.sh` and `scripts/knowledge/lib/detail-utils.sh`.
- `scripts/knowledge/lib/index-utils.sh` — provides `get_project_root()` which reads `$PROJECT_ROOT` env var if set, otherwise derives from script directory. Provides `get_index_path()` which returns `$root/KNOWLEDGE-INDEX.md`.

## Constraints

- Do not change the fundamental architecture of build-context.sh. Only fix integration bugs.
- Do not modify P01-P03 delivered scripts (scope-filter.sh, traverse-graph.sh, resolve-entries.sh, increment-hits.sh) unless there is a clear bug that prevents P04 integration.
- Bash 3.2 compatible.
- All fixes must be idempotent — running build-context.sh twice with the same inputs should produce the same output (except hit counts, which increment each time).

## Expected Output

All 3 verification scripts pass:
```
PASS: build-context.sh task-dispatch uses knowledge index pipeline
PASS: build-context.sh planning branch uses knowledge index pipeline
PASS: build-context.sh increments hit counts on included entries
```

If the existing code already works correctly, no changes to build-context.sh or section-handlers.sh are needed. If fixes are required, they should be minimal and targeted.
