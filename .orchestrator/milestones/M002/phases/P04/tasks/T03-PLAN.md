---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M002"
name: "Validate and fix payload ordering and manifest accuracy"
depends_on: [T02]
---

## Prerequisites

- T01 and T02 are complete. Knowledge index integration is verified and working.
- Verification scripts exist at `scripts/verify/m002-p04-manifest-header.sh` and `scripts/verify/m002-p04-static-first-ordering.sh`.

## Description

Validate that `scripts/dispatch/build-context.sh` produces payloads with:
1. **Correct manifest header**: The `## Manifest` section contains a table with columns Section, Lines, Est. Tokens, Priority. Line ranges accurately reflect where each section starts and ends. Token estimates are computed via `estimate_tokens()` (chars/4 rounded to nearest 100).
2. **Static-first ordering**: Static content (knowledge, decisions, constraints) appears before dynamic content (task plan, upstream summaries, state context) in the payload body, optimizing prompt caching hit rates.

The ordering requirement (FR-112) is specifically:
- **Static first**: Knowledge, Decisions, Constraints — content that rarely changes between dispatches
- **Dynamic last**: Scope (phase plan excerpt), Task Plan, Upstream Context, State Context — content that changes per task or per phase

The current build-context.sh task-dispatch branch uses a display-order map (`_bc_display_order()` function at line ~682) that determines section ordering. The current order is:
1. Knowledge (display order 1)
2. Decisions (display order 2)
3. Scope (display order 3)
4. Upstream Context (display order 4)
5. Task Plan (display order 5)
6. State Context (display order 6)
7. Constraints (display order 7)

This puts Constraints AFTER dynamic content, which violates FR-112. Constraints is static (template-based, same for every dispatch) and should appear before dynamic sections.

## Steps

### Step 1: Run the ordering and manifest verification scripts

Run these verification scripts from T01:
```
bash scripts/verify/m002-p04-manifest-header.sh
bash scripts/verify/m002-p04-static-first-ordering.sh
```

If both pass, the ordering and manifest are already correct. Skip to Step 4.

### Step 2: Fix payload section ordering

If the ordering test fails, fix the `_bc_display_order()` function in `scripts/dispatch/build-context.sh` to move Constraints before dynamic sections.

Current ordering function (around line 682):
```bash
_bc_display_order() {
  case "$1" in
    knowledge)   echo 1 ;;
    decisions)   echo 2 ;;
    scope)       echo 3 ;;
    upstream)    echo 4 ;;
    task_plan)   echo 5 ;;
    state)       echo 6 ;;
    constraints) echo 7 ;;
    *)           echo 99 ;;
  esac
}
```

Change to FR-112 compliant ordering — static content first, dynamic content last:
```bash
_bc_display_order() {
  case "$1" in
    knowledge)   echo 1 ;;  # static — rarely changes
    decisions)   echo 2 ;;  # static — rarely changes
    constraints) echo 3 ;;  # static — template-based, same every dispatch
    scope)       echo 4 ;;  # semi-static — changes per phase, not per task
    upstream)    echo 5 ;;  # dynamic — changes when phases complete
    task_plan)   echo 6 ;;  # dynamic — changes every dispatch
    state)       echo 7 ;;  # dynamic — changes every dispatch
    *)           echo 99 ;;
  esac
}
```

This change only affects the task-dispatch branch. The planning branch uses a hardcoded section array in `_bc_assemble_planning_payload()` which already follows a reasonable order (Knowledge, Decisions, Context Draft, Feature Spec, Upstream Context, Phase Roadmap, State Context, Instructions).

### Step 3: Verify manifest accuracy

If the manifest test fails, check the manifest calculation logic.

The manifest is built by `_bc_assemble_manifest_and_emit()` (line ~502). It computes:
- `fm_lines`: line count of frontmatter block
- `content_start`: where section content begins after frontmatter + manifest
- `section_line_counts` and `section_token_counts`: per-section metrics
- Line ranges: `current_line` to `current_line + sec_lines - 1` with 2-line gaps between sections

Potential issues:
1. **Off-by-one in content_start**: The formula is `offset = fm_lines + 1`, `manifest_lines = 5 + section_count + 2`, `content_start = offset + manifest_lines`. Verify this matches the actual payload layout.
2. **Token estimation**: Uses `estimate_tokens()` from `scripts/lib/payload-transforms.sh` which does `chars/4` rounded to nearest 100. This should be consistent between manifest and actual content.
3. **Knowledge section name suffix**: When the index pipeline is used, the Knowledge section gets a `(N entries)` suffix (line ~560-563). This suffix must appear in the manifest.

If any issues are found, fix the manifest calculation in `_bc_assemble_manifest_and_emit()`.

### Step 4: Re-run verification scripts

Run both verification scripts again:
```
bash scripts/verify/m002-p04-manifest-header.sh
bash scripts/verify/m002-p04-static-first-ordering.sh
```

Both must print "PASS" and exit 0.

## Must-Haves

This task addresses 2 of 8 phase truths:
- build-context.sh produces a manifest header with Section, Lines, Est. Tokens, Priority columns
- build-context.sh orders payload sections with static content first and dynamic content last

## Verification

```
bash scripts/verify/m002-p04-manifest-header.sh
bash scripts/verify/m002-p04-static-first-ordering.sh
```

Both must print "PASS: ..." and exit 0.

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p04-manifest-header.sh` (from T01)
  - Key API: Self-contained test script. Creates fixture, runs build-context.sh, checks for `## Manifest` table with correct columns. Exit 0 = PASS.
- `scripts/verify/m002-p04-static-first-ordering.sh` (from T01)
  - Key API: Self-contained test script. Checks that Knowledge/Decisions appear before Task Plan/Upstream in the payload. Exit 0 = PASS.
- Knowledge index integration is verified working (from T02).

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — the primary script under modification. Key areas:
  - `_bc_display_order()` (line ~682): determines section ordering for task-dispatch branch. Maps section base name to sort key.
  - `_bc_display_name()` (line ~694): maps section base name to display name for manifest.
  - `_bc_display_priority()` (line ~706): maps section base name to manifest priority (filtered/required).
  - `_bc_assemble_manifest_and_emit()` (line ~502): builds manifest table from section metadata. Computes line ranges and token estimates. Shared between planning and task-dispatch branches.
- `scripts/lib/payload-transforms.sh` — provides `estimate_tokens(text)` which returns `chars/4` rounded to nearest 100 (minimum 100 for non-empty input). Also provides `raw_token_count(text)` which returns `chars/4` unrounded.
- `scripts/lib/manifest-builder.sh` — provides `build_manifest_header()`, `format_manifest_row()`, `format_manifest_total()`, `assemble_manifest_table()`. These are library functions available for use but currently `build-context.sh` uses its own `_bc_assemble_manifest_and_emit()` instead.
- `templates/context-recipe.yaml` — defines section order values (knowledge=10, decisions=20, constraints=30, scope=40, upstream=50, state=60, task_plan=60). The recipe order values are overridden by `_bc_display_order()` in the parity shim.

## Constraints

- Only modify `_bc_display_order()` if the static-first ordering test fails. The existing ordering may already be sufficient.
- Do not change the manifest table format — it must remain `| Section | Lines | Est. Tokens | Priority |`.
- Do not modify the planning branch ordering — it has its own fixed section array that is acceptable.
- Bash 3.2 compatible.

## Expected Output

Both verification scripts pass:
```
PASS: build-context.sh produces manifest header with correct columns
PASS: build-context.sh orders static content before dynamic content
```

The `_bc_display_order()` function may be modified to move Constraints before dynamic sections if needed.
