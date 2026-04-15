---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M006"
name: "Update references/file-formats.md — add missing format schemas"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- No prior tasks required — T02 is independent of T01.

## Description

Update the existing `references/file-formats.md` to add five missing format
schemas. The file already documents: directory structure, roadmap, phase plan,
task plan, phase verification report, summaries, evaluation, context draft,
continue file, lock file, execution log (dispatch + telemetry + verification
entries), decisions register, knowledge file, configuration, routing
configuration, and doctor-history.jsonl.

The five formats to add are:

1. **Context Recipe (`context-recipe.yaml`)** — section declarations with
   source/priority/order/filter/cache_hint, compression configuration with
   graduated steps, manifest configuration. Source: `templates/context-recipe.yaml`
   and `scripts/lib/recipe-parser.sh`.

2. **Hooks Configuration (`hooks.yaml`)** — hook lifecycle points
   (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE), hook entries
   with name/script/enabled/block_on_fail/description, global defaults.
   Source: `templates/hooks.yaml` and `scripts/lib/hooks.sh`.

3. **Engine Checkpoint (`engine-checkpoint.json`)** — run_id, milestone,
   phase, last_task, outcome, timestamp. Written atomically by
   `scripts/engine/checkpoint.sh`, consumed by crash recovery.
   Source: `scripts/engine/checkpoint.sh`.

4. **Routing Configuration** and **Doctor History** — these sections already
   exist in `references/file-formats.md`. Verify they are complete and
   accurate. If any fields are missing or descriptions are inaccurate,
   update them.

Each section must follow the existing document conventions:
- `## Format Name` heading
- **Location**, **Format**, **Mutability** metadata
- Schema or field table
- Example (where helpful)
- Parsing rules (if applicable)
- State machine role (if applicable)

## Steps

### Step 1 — Read source files for the three new formats

Read the following to understand each format's schema:

**Context Recipe:**
- `templates/context-recipe.yaml` — the default recipe with all section types
- `scripts/lib/recipe-parser.sh` — parsing functions: `read_recipe_field`,
  `read_recipe_section_ids`, `read_recipe_compression_steps`
- `scripts/dispatch/build-context.sh` — how sections are resolved and assembled

**Hooks:**
- `templates/hooks.yaml` — the default hooks configuration
- `scripts/lib/hooks.sh` — hook execution: `run_hooks`, frozen snapshot,
  timeout handling, verdict interpretation

**Checkpoint:**
- `scripts/engine/checkpoint.sh` — `checkpoint_write`, `checkpoint_read`,
  `checkpoint_detect`, `checkpoint_clear` functions

### Step 2 — Read the existing file-formats.md

Read `references/file-formats.md` in full to understand:
- The existing section ordering and formatting conventions
- Which formats are already documented (do not duplicate)
- Where the new sections should be inserted (maintain logical grouping)

The existing routing.yaml section (at the end of the file) and
doctor-history.jsonl section should be verified for accuracy against
the actual templates/scripts.

### Step 3 — Add Context Recipe section

Insert a new `## Context Recipe` section. Include:

- **Location**: `templates/context-recipe.yaml` (default), overridable at
  milestone/phase/task level
- **Format**: YAML (max 2 levels nesting)
- **Mutability**: Edited by developer. Optional overrides in milestone/phase/task dirs.

- **Section Fields**: id, source, priority (required/compressible/optional),
  order, filter (none/scope/staleness/confidence), cache_hint (static/semi-static/dynamic)
- **Source Types**: computed, file path, phase_summaries, phase_plan, task_plan, template
- **Compression Block**: enabled flag, graduated steps (drop_optional, summarize,
  drop_lowest_confidence), protected_sections
- **Manifest Block**: enabled, include_token_count, include_section_list,
  include_compression_applied
- **Resolution Order**: task > phase > milestone > default (FR-211)

### Step 4 — Add Hooks Configuration section

Insert a new `## Hooks Configuration` section. Include:

- **Location**: `templates/hooks.yaml` (default), overridable in
  milestone or phase directories
- **Format**: YAML (max 2 levels nesting)
- **Mutability**: Edited by developer or extension.

- **Global Defaults**: timeout, block_on_fail
- **Lifecycle Points**: PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE
- **Hook Entry Fields**: name, script, enabled, block_on_fail, description
- **Execution Behavior**: frozen snapshot passed as $1, hook isolation
  (Principle XII), verdict protocol
- **Resolution Order**: phase > milestone > default

### Step 5 — Add Engine Checkpoint section

Insert a new `## Engine Checkpoint` section. Include:

- **Location**: `.specify/orchestrator/milestones/{M###}/engine-checkpoint.json`
- **Format**: JSON
- **Mutability**: Written atomically by engine after each task. Cleared on
  successful phase completion. Ephemeral.

- **Fields**: run_id, milestone, phase, last_task, outcome, timestamp
- **Atomic Write**: temp file + mv pattern (checkpoint.sh lines 88-109)
- **Consumption**: `checkpoint_detect` checks existence, `checkpoint_read`
  extracts fields, `checkpoint_clear` removes on phase success
- **Crash Recovery Role**: engine reads checkpoint on startup, skips completed
  tasks, resumes from last_task boundary

### Step 6 — Verify existing Routing and Doctor History sections

Cross-check the existing `## Routing Configuration` section against
`templates/routing.yaml` and `scripts/dispatch/select-model.sh`. Verify:
- All fields documented
- Parsing rules accurate
- Resolution order described

Cross-check the existing `## Doctor History` section against
`scripts/diagnostics/run-doctor.sh`. Verify:
- All fields documented
- Append rules accurate

Fix any inaccuracies found.

### Step 7 — Verify-as-you-write (DC-4)

For each format schema documented:
- Cross-check every field name against the source template/script
- Verify field types and descriptions match actual usage
- If describing parsing behavior, read the parser to confirm
- If output diverges, fix the doc or fix the code (DC-5)

## Must-Haves

- [ ] `references/file-formats.md` contains a `## Context Recipe` section
- [ ] Context recipe section documents sections, compression, manifest blocks
- [ ] `references/file-formats.md` contains a `## Hooks Configuration` section
- [ ] Hooks section documents lifecycle points and hook entry fields
- [ ] `references/file-formats.md` contains an `## Engine Checkpoint` section
- [ ] Checkpoint section documents all 6 fields and atomic write behavior
- [ ] Existing routing.yaml section verified against `templates/routing.yaml`
- [ ] Existing doctor-history.jsonl section verified against `scripts/diagnostics/run-doctor.sh`
- [ ] File is at least 850 lines total after additions

## Verification

After updating the file, run:

```
bash scripts/verify/m006-p01-formats-recipe.sh
bash scripts/verify/m006-p01-formats-hooks.sh
bash scripts/verify/m006-p01-formats-routing.sh
bash scripts/verify/m006-p01-formats-checkpoint.sh
bash scripts/verify/m006-p01-formats-doctor.sh
```

All must exit 0. If any verification script does not yet exist (because T03
has not run), verify manually by grepping the file for required patterns.

## Inputs

### From Previous Tasks

None — T02 is independent of T01.

### From Disk (Pre-existing)

- `references/file-formats.md` — existing file to update (currently ~800 lines)
- `templates/context-recipe.yaml` — context recipe template (source of truth)
- `templates/hooks.yaml` — hooks configuration template (source of truth)
- `templates/routing.yaml` — routing configuration template (verify existing section)
- `scripts/engine/checkpoint.sh` — checkpoint functions (source of truth for checkpoint format)
- `scripts/lib/recipe-parser.sh` — recipe parsing functions (verify parsing rules)
- `scripts/lib/hooks.sh` — hook execution functions (verify hook behavior)
- `scripts/dispatch/build-context.sh` — context assembly (verify section resolution)
- `scripts/dispatch/select-model.sh` — model selection (verify routing usage)
- `scripts/diagnostics/run-doctor.sh` — doctor diagnostics (verify doctor-history format)

## Constraints

- **DC-1**: Follow existing `references/file-formats.md` section conventions:
  `## Format Name`, Location/Format/Mutability metadata, schema/fields,
  example, parsing rules.
- **DC-3**: Any cross-links use relative paths.
- **DC-4**: Verify-as-you-write — every field name and type confirmed by reading
  the actual source template or script.
- **DC-5**: Any bug fix commits reference `references/file-formats.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.
- Do NOT restructure or rewrite existing sections that are already correct.
  Only add new sections and fix inaccuracies.

## Expected Output

After completing this task:

1. `references/file-formats.md` has three new sections: Context Recipe,
   Hooks Configuration, Engine Checkpoint.
2. Each new section follows the existing document conventions.
3. Existing Routing and Doctor History sections have been verified (and
   fixed if inaccurate).
4. The file is at least 850 lines.
5. If any code bugs were found and fixed, each fix is committed with a
   message referencing `(found via references/file-formats.md)`.
