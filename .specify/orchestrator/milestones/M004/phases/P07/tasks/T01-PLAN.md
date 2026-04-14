---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P07"
milestone: "M004"
name: "Create check-recipe.sh"
depends_on: []
---

## Prerequisites

Before starting, verify from the repo root:

```bash
# Recipe parser library exists
test -f scripts/lib/recipe-parser.sh && echo "ok: recipe-parser.sh"

# Default recipe template exists
test -f templates/context-recipe.yaml && echo "ok: context-recipe.yaml"

# P02 libraries exist (for optional engine integration)
test -f scripts/lib/errors.sh && echo "ok: errors.sh"
test -f scripts/lib/events.sh && echo "ok: events.sh"

# Diagnostics directory exists
test -d scripts/diagnostics && echo "ok: diagnostics dir"
```

All must print `ok:`. If any fail, STOP.

## Description

Create `scripts/diagnostics/check-recipe.sh`, a diagnostic script that validates the structure of `templates/context-recipe.yaml`. The script uses `scripts/lib/recipe-parser.sh` to parse the recipe file and validates three things:

1. **Required fields** -- Each section in the `sections:` block must have all 5 required fields: `source`, `priority`, `order`, `filter`, `cache_hint`.
2. **Valid source types** -- Each section's `source` value must be one of the known types: `computed`, `file`, `phase_summaries`, `phase_plan`, `task_plan`, `template`, `index` (plus the special file names like `KNOWLEDGE.md`, `DECISIONS.md` which are file-type sources).
3. **Valid priorities** -- Each section's `priority` value must be one of: `required`, `compressible`, `optional`.

The script emits `DOCTOR:RECIPE` structured output following the existing diagnostics convention (see check-hashes.sh, check-instructions.sh as reference). It optionally sources P02 libraries for engine integration when `ORCH_RUN_ID` is set.

## Cross-Cutting Constraints (verbatim from P07-PLAN.md)

1. **Bash 3.2** -- no `declare -A`, no `readarray`, no `mapfile`, no `<(...)` as redirect target.
2. **No jq** -- all parsing uses grep/sed/awk or recipe-parser.sh.
3. **DOCTOR: output convention** -- emit `DOCTOR:RECIPE status=<ok|warn> sections=N invalid=N` line. Status `ok` exits 0, status `warn` exits 1.
4. **Standalone safety** -- core recipe validation works without ORCH_RUN_ID. Engine integration (emit_event/emit_result) is wrapped in `if [ -n "${ORCH_RUN_ID:-}" ]; then ... fi`.
5. **P02 library sourcing pattern** -- `_SCRIPT_DIR / _LIB_DIR` with `../../lib` path.
6. **Do not modify check-constitution.sh, check-events.sh, or any P02/P05/P06 scripts.**

## Steps

### Step 1: Read reference scripts

Read the following to understand conventions:
- scripts/diagnostics/check-hashes.sh -- reference for DOCTOR: output convention
- scripts/diagnostics/check-instructions.sh -- reference for multi-file validation
- scripts/lib/recipe-parser.sh -- the parser to source for parse_recipe_sections

### Step 2: Create check-recipe.sh

Create `scripts/diagnostics/check-recipe.sh` with the following structure:

1. Shebang, comment header, `set -eu`
2. SCRIPT_DIR / PROJECT_ROOT derivation (same pattern as other check scripts)
3. Argument parsing: `--root <project-root>`, `--recipe <file>` (optional, defaults to `templates/context-recipe.yaml`)
4. Source recipe-parser.sh from the lib directory
5. Optionally source P02 libs for engine integration
6. Parse recipe using `parse_recipe_sections`
7. Validate each section:
   - Has non-empty `source` field
   - `source` is a known type or a file path ending in `.md`
   - `priority` is one of: required, compressible, optional
   - Has non-empty `order`, `filter`, `cache_hint` fields
8. Collect invalid sections and missing field details
9. Emit DOCTOR:RECIPE structured output
10. Emit events/results if ORCH_RUN_ID is set
11. Exit 0 for ok, 1 for warn

Known source types to validate against:

```
computed
file
phase_summaries
phase_plan
task_plan
template
index
```

Also accept any value ending in `.md` (like `KNOWLEDGE.md`, `DECISIONS.md`) as these are file-path sources.

Known priority values:

```
required
compressible
optional
```

The `parse_recipe_sections` function returns lines in format:
`<name>|<source>|<priority>|<order>|<filter>|<cache_hint>`

### Step 3: Make the script executable

```bash
chmod +x scripts/diagnostics/check-recipe.sh
```

### Step 4: Verify the script

Run from repo root:

```bash
# Default recipe should pass all checks
bash scripts/diagnostics/check-recipe.sh --root .
# Expected: DOCTOR:RECIPE status=ok sections=7 invalid=0
```

## Must-Haves

### Truths

- check-recipe.sh exists and is executable
  - Check: `bash scripts/verify/m004-p07-recipe-exists.sh`
- check-recipe.sh validates all 7 default recipe sections have required fields
  - Check: `bash scripts/verify/m004-p07-recipe-fields.sh`
- check-recipe.sh validates source types against known set
  - Check: `bash scripts/verify/m004-p07-recipe-sources.sh`
- check-recipe.sh validates priorities against known set
  - Check: `bash scripts/verify/m004-p07-recipe-priorities.sh`
- check-recipe.sh emits DOCTOR:RECIPE structured output
  - Check: `bash scripts/verify/m004-p07-recipe-output.sh`

### Artifacts

- scripts/diagnostics/check-recipe.sh (min 80 lines, contains "DOCTOR:RECIPE")

## Verification

Run from repo root:
1. `bash scripts/verify/m004-p07-recipe-exists.sh` -- PASS
2. `bash scripts/verify/m004-p07-recipe-output.sh` -- PASS
3. `bash scripts/diagnostics/check-recipe.sh --root .` -- exits 0 with DOCTOR:RECIPE status=ok

## Inputs

### From Previous Tasks

None -- T01 has no task dependencies within P07.

### From Disk

- scripts/lib/recipe-parser.sh -- P04 output. Provides `parse_recipe_sections <file>` which returns pipe-delimited lines. Double-sourcing guarded.
- templates/context-recipe.yaml -- P04 output. The default recipe with 7 sections (state, knowledge, decisions, upstream, scope, task_plan, constraints). Each section has source, priority, order, filter, cache_hint fields.
- scripts/lib/errors.sh -- P02 output. Provides `emit_result`. Double-sourcing guarded.
- scripts/lib/events.sh -- P02 output. Provides `emit_event`. Double-sourcing guarded.
- scripts/diagnostics/check-hashes.sh -- reference for output convention and script structure.

## Constraints

- The script must work when run standalone (no ORCH_RUN_ID).
- The script must accept `--root` and optionally `--recipe` arguments.
- Output format: `DOCTOR:RECIPE status=<ok|warn> sections=N invalid=N`
- Invalid sections should be listed as `  INVALID: <name> -- <reason>` lines.
- Exit 0 if all sections valid, exit 1 if any invalid.

## Expected Output

- New file scripts/diagnostics/check-recipe.sh that:
  - Sources recipe-parser.sh to parse the recipe
  - Validates required fields, source types, and priorities
  - Emits DOCTOR:RECIPE structured output
  - Optionally emits events/results under ORCH_RUN_ID
  - Follows existing check script conventions
