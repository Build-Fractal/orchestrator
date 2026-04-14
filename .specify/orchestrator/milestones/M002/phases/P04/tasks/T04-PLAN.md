---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M002"
name: "Validate and fix compress-payload.sh and budget enforcement"
depends_on: [T03]
---

## Prerequisites

- T01, T02, T03 are complete. Knowledge index integration is working, payload ordering is correct, and manifest header is accurate.
- Verification scripts exist at `scripts/verify/m002-p04-compression-cascade.sh`, `scripts/verify/m002-p04-manifest-rebuild.sh`, and `scripts/verify/m002-p04-budget-enforcement.sh`.

## Description

Validate that `scripts/dispatch/compress-payload.sh` correctly handles payloads produced by the M002 knowledge architecture. The compression script must:

1. **Apply the 3-step cascade** (FR-113):
   - Step 1: Drop sections marked "optional" in the manifest (e.g., Constraints)
   - Step 2: Summarize upstream summaries to max_words (default 200)
   - Step 3: Drop lowest-confidence knowledge entries
   - NEVER truncate the task plan section

2. **Rebuild the manifest** after compression: updated line ranges, token estimates, and section list (dropped sections removed from manifest).

3. **Budget enforcement interface**: build-context.sh reports token count to stderr. compress-payload.sh accepts `--budget TOKENS`. The dispatch flow pipes build-context.sh output through compress-payload.sh when over budget.

The existing compress-payload.sh already implements all three steps via recipe-driven dispatch (`_cp_run_recipe_steps`). This task validates it works with payloads containing knowledge entries from the new architecture (detail files with YAML frontmatter, graph-traversed entries).

## Steps

### Step 1: Run the compression and budget verification scripts

Run these verification scripts from T01:
```
bash scripts/verify/m002-p04-compression-cascade.sh
bash scripts/verify/m002-p04-manifest-rebuild.sh
bash scripts/verify/m002-p04-budget-enforcement.sh
```

If all three pass, compression is already correct. Skip to Step 5.

### Step 2: Diagnose compression cascade failures

If `m002-p04-compression-cascade.sh` fails, check these areas:

**Knowledge entry format in payload**: The compress-payload.sh `_cp_step_drop_lowest_confidence()` function (line ~355) parses knowledge entries by splitting on `---` frontmatter boundaries. It extracts the `confidence:` field from frontmatter. M002 knowledge entries have YAML frontmatter in this format:

```yaml
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
```

The parser must correctly extract `confidence: 0.90` from this format. The existing parser (line ~407) uses `grep '^confidence:'` which should work.

**Section name matching**: The compress-payload.sh uses `## Knowledge` heading to identify the knowledge section. After M002, the heading may include a count suffix like `## Knowledge (3 entries)`. The `_cp_step_drop_lowest_confidence()` function uses `grep -qi "$target"` (line ~366) where target defaults to "knowledge", which will match `## Knowledge (3 entries)` since `-i` makes it case-insensitive and the substring "knowledge" appears.

**Task plan protection**: Verify that the Task Plan section is not dropped or truncated. The recipe's `protected_sections` config lists `task_plan,scope,state`. The compression steps only target `optional` priority sections, `upstream` sections for summarization, and `knowledge` sections for confidence-based dropping. Task Plan has priority `required` and is not targeted by any step.

### Step 3: Diagnose manifest rebuild failures

If `m002-p04-manifest-rebuild.sh` fails, check the manifest rebuild logic in compress-payload.sh (lines 576-673).

The rebuild:
1. Extracts frontmatter block from original payload
2. Extracts title line
3. Iterates through remaining section files in `$TMPDIR_COMP`
4. Computes new line counts and token estimates for each surviving section
5. Builds a new manifest table
6. Assembles the final compressed payload

Potential issues:
- **Dropped sections still appear in manifest**: After `_cp_step_drop_optional()` removes a section file, the rebuild loop only iterates over files that still exist (`[ -f "$sfile" ]` check at line 591).
- **Line ranges wrong after compression**: The rebuild computes `content_start` from the overhead (frontmatter + manifest table rows). If sections were dropped, the manifest table has fewer rows, changing the overhead calculation. Check that `manifest_overhead` is recomputed from `rem_count` (line 629).
- **Token estimates stale**: After `_cp_step_summarize()` truncates content, the file is overwritten in place. The rebuild reads the new file content for token estimation.

### Step 4: Diagnose budget enforcement failures

If `m002-p04-budget-enforcement.sh` fails, understand the budget enforcement architecture:

**Current architecture**: build-context.sh and compress-payload.sh are separate scripts. build-context.sh assembles the full payload and reports bytes/tokens to stderr. compress-payload.sh is called separately with `--budget` to compress. The dispatch flow (in the `auto` command or `dispatch` command) is responsible for piping one to the other.

The verification should confirm:
1. build-context.sh reports `"Context payload: X bytes"` to stderr (line 625)
2. compress-payload.sh accepts `--budget` flag and compresses when over budget
3. The two can be piped: `bash build-context.sh ... | bash compress-payload.sh --budget 5000`

If the budget verification test expects build-context.sh to internally call compress-payload.sh, that is NOT the current architecture. The test should verify the pipeline interface instead.

If build-context.sh needs to report an estimated token count (not just byte count) to stderr for budget decisions, add that to the stderr output line. The token count is `total_tokens` computed in `_bc_assemble_manifest_and_emit()`.

**Adding token count to stderr**: Modify the stderr report in `_bc_assemble_manifest_and_emit()` (line 625) to include estimated tokens:

```bash
echo "Context payload: $payload_bytes bytes (~${total_tokens} tokens, ${budget_pct}% of total artifacts)" >&2
```

### Step 5: Re-run verification scripts

Run all three verification scripts:
```
bash scripts/verify/m002-p04-compression-cascade.sh
bash scripts/verify/m002-p04-manifest-rebuild.sh
bash scripts/verify/m002-p04-budget-enforcement.sh
```

All three must print "PASS" and exit 0.

## Must-Haves

This task addresses 3 of 8 phase truths:
- compress-payload.sh applies the 3-step compression cascade and never truncates the task plan
- compress-payload.sh rebuilds the manifest header after compression
- build-context.sh accepts budget and passes it to compress-payload.sh (via pipeline interface)

## Verification

```
bash scripts/verify/m002-p04-compression-cascade.sh
bash scripts/verify/m002-p04-manifest-rebuild.sh
bash scripts/verify/m002-p04-budget-enforcement.sh
```

All three must print "PASS: ..." and exit 0.

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p04-compression-cascade.sh` (from T01)
  - Key API: Self-contained test. Creates a large payload (~120K chars / ~30K tokens), runs compress-payload.sh with --budget 5000, verifies output is smaller and Task Plan is preserved.
- `scripts/verify/m002-p04-manifest-rebuild.sh` (from T01)
  - Key API: Self-contained test. Creates an oversized payload, compresses, checks that output still has a valid `## Manifest` table with updated line ranges.
- `scripts/verify/m002-p04-budget-enforcement.sh` (from T01)
  - Key API: Self-contained test. Runs build-context.sh and verifies stderr token/byte reporting. Runs compress-payload.sh with --budget and verifies compression occurs.
- Knowledge index integration and payload ordering are confirmed working (from T02 and T03).

### From Disk (Pre-existing)

- `scripts/dispatch/compress-payload.sh` — the primary script under validation. Key areas:
  - `_cp_step_drop_optional()` (line ~247): drops sections whose name matches entries in `$optional_sections`. Reads manifest table to identify optional sections.
  - `_cp_step_summarize()` (line ~278): truncates `### subsections` of a target section to `max_words` words. Default target: "upstream", default max_words: 200.
  - `_cp_step_drop_lowest_confidence()` (line ~355): parses knowledge entries by `---` frontmatter boundaries, extracts `confidence:` field, sorts ascending, removes lowest until under budget.
  - `_cp_run_recipe_steps()` (line ~508): reads compression steps from recipe. Falls back to `_cp_run_fallback_steps()` (line ~557) when recipe missing.
  - Manifest rebuild (lines 576-673): rebuilds payload with updated manifest table from remaining section files.
  - Sources: `scripts/lib/errors.sh`, `scripts/lib/events.sh`, `scripts/lib/run-context.sh`, `scripts/lib/recipe-parser.sh`, `scripts/lib/payload-transforms.sh`, `scripts/lib/manifest-builder.sh`.
- `scripts/dispatch/build-context.sh` — the context builder. Key area for budget:
  - `_bc_assemble_manifest_and_emit()` (line ~502): builds manifest and reports `Context payload: X bytes` to stderr (line 625). Has access to `total_tokens` variable.
  - Config reads: `CONTEXT_VERBOSITY`, `DURATION_BUDGET`, `DISPATCH_BUDGET`, `BUDGET_ENFORCEMENT` (lines 149-152) but does NOT currently read a `context_budget` key.
- `templates/context-recipe.yaml` — compression config with 3 steps: `drop_optional`, `summarize` (upstream, 200 words), `drop_lowest_confidence` (knowledge, 0.5). Protected sections: `task_plan,scope,state`.
- `scripts/lib/payload-transforms.sh` — provides `estimate_tokens(text)` and `raw_token_count(text)` used by both scripts.

## Constraints

- Do not change the fundamental compression algorithm. Only fix integration issues with the M002 knowledge format.
- Do not change compress-payload.sh's CLI interface (--budget, --input, --recipe).
- Build-context.sh and compress-payload.sh remain separate scripts. Budget enforcement happens at the pipeline level (the dispatch command pipes one to the other), not internally.
- Bash 3.2 compatible.
- All compression operations must be idempotent — compressing an already-compressed payload should be a no-op if already under budget.

## Expected Output

All 3 verification scripts pass:
```
PASS: compress-payload.sh applies compression cascade without truncating task plan
PASS: compress-payload.sh rebuilds manifest after compression
PASS: build-context.sh reports budget and compress-payload.sh respects it
```
