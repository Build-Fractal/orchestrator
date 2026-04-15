---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M004"
name: "Refactor build-context.sh as Recipe Interpreter"
depends_on: [T01]
---

## Description

Rewrite `scripts/dispatch/build-context.sh` so section selection, source lookup, and ordering are driven by `templates/context-recipe.yaml` via `scripts/lib/recipe-parser.sh`. The script's top-level body becomes a recipe interpreter: for each section the recipe declares, dispatch to the corresponding handler in `scripts/dispatch/lib/section-handlers.sh` (created by T01), write the section body to a temp file, then assemble the manifest and final payload exactly as before.

The acceptance bar is byte-for-byte parity with the pre-refactor output for the task-dispatch mode when the default recipe (`templates/context-recipe.yaml`) is used. T05 will verify this against a golden fixture.

Critically: the `PHASE_PLAN` / planning-payload branch of `build-context.sh` is OUT OF SCOPE for this refactor. Do not change its output shape. Isolate it behind an early `if [ "$TASK_ID" = "PHASE_PLAN" ]; then assemble_planning_payload ... fi` branch that calls a helper containing the existing planning-payload code verbatim.

This implements FR-210 (recipe-driven assembly), FR-211 (recipe resolution specificity), Principle X (Templating Over Inference), and Principle XIII (Agent Instruction Schema).

## Cross-Cutting Constraints (verbatim from P05-PLAN.md)

1. **Bash 3.2** — no `declare -A`, no `readarray`, no `mapfile`, no `<(…)` as a redirect target in `while read` loops.
2. **Double-sourcing guard** — N/A (build-context.sh is a script, not a library), but the libraries it sources must have their guards honored.
3. **Sibling library sourcing** — `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` and source `${SCRIPT_DIR}/../lib/<name>.sh` or `${SCRIPT_DIR}/lib/<name>.sh`.
4. **No inline `date`** — after sourcing `run-context.sh`, call `orch_now` instead of `date -u ...`. Audit with `grep -nE '\$\(date\b|^[[:space:]]*date[[:space:]]+-u' scripts/dispatch/build-context.sh` — must return nothing.
5. **`emit_result` on exit** — source `scripts/lib/errors.sh` and emit exactly one RESULT line before any normal or error exit. Use a trap or wrapper.
6. **Standalone mode still works** — if `ORCH_RUN_ID` is unset, call `init_run_context "$MILESTONE_ID" "$PHASE_ID"`. If already set, inherit.
7. **`scripts/engine/run.sh` is NOT rewritten.** build-context.sh must still accept `<orch_root> <milestone> <phase> <task>` as positional args with the existing shape. `--config-defaults <f>` and the new `--recipe <f>` are optional.
8. **P06-deferred items — do NOT touch.** Do not edit check-must-haves.sh, events.sh, or record-result.sh.
9. **Every verification command must be runnable from repo root.**
10. **No `jq`.**

Additional constraint specific to T02: **single-word values in events**. `scripts/lib/events.sh` `_orch_events_quote` does not quote single-word values (P06 will fix). When this task's must-have greps depend on grepping `key="value"` form, pair the `emit_event` line with a follow-on `printf` literal-audit marker — the pattern P03/T03–T05 established. See Step 8 for an example.

## Steps

### Step 1: Baseline — capture the current output as the golden reference

BEFORE making any edits, capture the pre-refactor output from a known milestone. This output is the golden fixture T05 will diff against. Save it to disk now:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
mkdir -p .specify/orchestrator/milestones/M004/phases/P05/fixtures

bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 \
  > .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md \
  2>/dev/null || {
    echo "FAIL: could not capture golden payload" >&2
    exit 1
  }

wc -l .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md
# Must be > 50 lines.
```

Verify the golden contains the expected sections:

```bash
grep -q '^## Knowledge' .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md
grep -q '^## Decisions' .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md
grep -q '^## Scope' .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md
grep -q '^## Upstream Context' .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md
grep -q '^## Task Plan' .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md
grep -q '^## State Context' .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md
grep -q '^## Constraints' .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md
```

All 7 greps must succeed. If any fails, STOP — something is wrong with the pre-refactor script and parity is impossible.

### Step 2: Understand what parity means (read carefully)

The refactored script must produce output that, after a narrow set of normalizations, is byte-identical to the golden fixture:

- **Sections** (content blocks): must match character-for-character.
- **Manifest table rows**: the `| <name> | <line-range> | ~<tokens> | <priority> |` rows are allowed to have different `<line-range>` values (since line counts shift as sections grow) BUT the `<name>` ordering and `<priority>` column must match exactly. The `<tokens>` column can differ by ±100 due to rounding.
- **Frontmatter / title / `## Manifest` header**: must match exactly.

T05 will enforce this via `fixtures/run-parity.sh` which strips the line-range and token columns before diffing.

### Step 3: Plan the new file structure

The refactored `scripts/dispatch/build-context.sh` has this top-level outline:

```
1-30:    header comment, set -euo pipefail
31-40:   SCRIPT_DIR / PROJECT_ROOT anchors
41-60:   source errors.sh, events.sh, run-context.sh, recipe-parser.sh, lib/section-handlers.sh
61-90:   argument parsing (positional + --config-defaults + --recipe)
91-130:  resolve milestone dir, phase dir, roadmap path; validate task plan / phase plan exist
131-170: read config values (verbosity, duration/dispatch budgets, budget enforcement)
171-180: run context init (if ORCH_RUN_ID unset) and emit_event DISPATCH_START stage=build_context
181-220: IS_PLANNING branch → dispatch to assemble_planning_payload() helper (verbatim port of old logic)
221-280: resolve recipe path via resolve_recipe(); parse sections via parse_recipe_sections
281-360: iterate sections, write each to s<idx>.txt via handler dispatch
361-430: assemble manifest table + frontmatter + title + sections (existing logic, ported)
431-470: emit payload, hit-count loop, context-budget stderr line, emit_result ok, exit
```

### Step 4: Write the top block — header, anchors, sources

```bash
#!/usr/bin/env bash
# scripts/dispatch/build-context.sh — Recipe-driven dispatch payload assembly
# Reads context-recipe.yaml to determine which sections to include and in
# what order, then dispatches each section to a handler in section-handlers.sh.
#
# Usage: build-context.sh <orch_root> <milestone> <phase> <task> [--config-defaults <f>] [--recipe <f>]
#   orch_root: .specify/orchestrator (or a fixture milestone dir)
#   milestone: M### (e.g., M001)
#   phase: P## (e.g., P02)
#   task: T## or PHASE_PLAN for planning payload
#   --config-defaults: optional config file for context_verbosity, budgets, etc.
#   --recipe: optional recipe override (default: templates/context-recipe.yaml)
#
# Output: dispatch payload on stdout. Stderr: "Context payload: X bytes ..."
# Exit 0 on success, 1 on config/state/io error, 2 on missing required sections.
#
# Bash 3.2 compatible. Standalone-capable (works without ORCH_RUN_ID).
# Constitution: Principle X (Templating Over Inference), XIII (Agent Instruction Schema).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Source shared libraries ---
. "$PROJECT_ROOT/scripts/lib/errors.sh"
. "$PROJECT_ROOT/scripts/lib/events.sh"
. "$PROJECT_ROOT/scripts/lib/run-context.sh"
. "$PROJECT_ROOT/scripts/lib/recipe-parser.sh"
. "$SCRIPT_DIR/lib/section-handlers.sh"
```

### Step 5: Install a result-emitting EXIT trap

```bash
# --- Result emission on exit ---
_BC_RESULT_EMITTED=0
_bc_final_result() {
  local rc=$?
  if [ "$_BC_RESULT_EMITTED" -eq 0 ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "context assembled for ${MILESTONE_ID:-?}/${PHASE_ID:-?}/${TASK_ID:-?}"
    else
      emit_result error CONFIG "build-context exited rc=$rc"
    fi
    _BC_RESULT_EMITTED=1
  fi
}
trap _bc_final_result EXIT
```

The trap fires on any exit path, including `set -e` failures and explicit `exit 1`, guaranteeing a RESULT line even if a handler blows up mid-run.

### Step 6: Argument parsing

Keep the existing positional-arg parser; add `--recipe <path>`:

```bash
ORCH_ROOT=""
MILESTONE_ID=""
PHASE_ID=""
TASK_ID=""
CONFIG_DEFAULTS=""
RECIPE_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --config-defaults) CONFIG_DEFAULTS="$2"; shift 2 ;;
    --recipe)          RECIPE_OVERRIDE="$2"; shift 2 ;;
    -*)
      printf 'build-context.sh: unknown option %s\n' "$1" >&2
      exit 1 ;;
    *)
      if [ -z "$ORCH_ROOT" ]; then ORCH_ROOT="$1"
      elif [ -z "$MILESTONE_ID" ]; then MILESTONE_ID="$1"
      elif [ -z "$PHASE_ID" ]; then PHASE_ID="$1"
      elif [ -z "$TASK_ID" ]; then TASK_ID="$1"
      fi
      shift ;;
  esac
done

if [ -z "${ORCH_ROOT:-}" ] || [ -z "${MILESTONE_ID:-}" ] || [ -z "${PHASE_ID:-}" ] || [ -z "${TASK_ID:-}" ]; then
  printf 'build-context.sh: missing required arguments\n' >&2
  printf 'Usage: build-context.sh <orch_root> <milestone> <phase> <task> [--config-defaults <f>] [--recipe <f>]\n' >&2
  exit 1
fi
```

### Step 7: Resolve milestone dir, phase dir, validate plans

Port the existing block from the pre-refactor script (lines ~78–117). Same logic, no changes:

```bash
MILESTONE_DIR=""
if [ -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ]; then
  MILESTONE_DIR="$ORCH_ROOT/milestones/$MILESTONE_ID"
elif [ -d "$ORCH_ROOT/phases" ]; then
  MILESTONE_DIR="$ORCH_ROOT"
else
  printf 'build-context.sh: milestone directory not found\n' >&2
  exit 1
fi

PHASE_DIR="$MILESTONE_DIR/phases/$PHASE_ID"
ROADMAP="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"
IS_PLANNING=false
[ "$TASK_ID" = "PHASE_PLAN" ] && IS_PLANNING=true

if [ ! -f "$ROADMAP" ]; then
  printf 'build-context.sh: roadmap not found: %s\n' "$ROADMAP" >&2
  exit 1
fi

if [ "$IS_PLANNING" = "false" ]; then
  TASK_PLAN="$PHASE_DIR/tasks/${TASK_ID}-PLAN.md"
  PHASE_PLAN="$PHASE_DIR/${PHASE_ID}-PLAN.md"
  if [ ! -f "$TASK_PLAN" ]; then
    printf 'build-context.sh: task plan not found: %s\n' "$TASK_PLAN" >&2
    exit 1
  fi
  if [ ! -f "$PHASE_PLAN" ]; then
    printf 'build-context.sh: phase plan not found: %s\n' "$PHASE_PLAN" >&2
    exit 1
  fi
fi
```

### Step 8: Config reading + run context init + DISPATCH_START event

```bash
READ_CONFIG="$PROJECT_ROOT/scripts/state/read-config.sh"
config_read() {
  local key="$1" default="$2" value=""
  if [ -n "$CONFIG_DEFAULTS" ] && [ -f "$CONFIG_DEFAULTS" ]; then
    value="$(bash "$READ_CONFIG" "$key" --defaults "$CONFIG_DEFAULTS" 2>/dev/null || true)"
  fi
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$value"
  fi
}
CONTEXT_VERBOSITY="$(config_read context_verbosity standard)"
DURATION_BUDGET="$(config_read duration_budget 2h)"
DISPATCH_BUDGET="$(config_read dispatch_budget 3)"
BUDGET_ENFORCEMENT="$(config_read budget_enforcement warn)"

# Export env vars the `handle_template` section handler reads
export SH_VERIFICATION_CRITERIA="${VERIFICATION_CRITERIA:-See phase plan must-haves}"
export SH_DURATION_BUDGET="$DURATION_BUDGET"
export SH_DISPATCH_BUDGET="$DISPATCH_BUDGET"
export SH_BUDGET_ENFORCEMENT="$BUDGET_ENFORCEMENT"

# Initialize run context if the engine hasn't already
if [ -z "${ORCH_RUN_ID:-}" ]; then
  init_run_context "$MILESTONE_ID" "$PHASE_ID"
fi

emit_event DISPATCH_START stage=build_context milestone="$MILESTONE_ID" phase="$PHASE_ID" task="$TASK_ID"
# Literal audit marker (see P05-PLAN.md constraint #10 and P03/T03-T05 lesson)
# _orch_events_quote does NOT quote single-word values, so downstream must-have
# greps that look for stage="build_context" fail. Emit a second literal marker
# line so audits that scan for the fixed substring still find it.
printf 'EVENT-AUDIT:DISPATCH_START stage="build_context"\n'
```

### Step 9: Planning-payload branch (verbatim port)

Wrap the existing `IS_PLANNING=true` block in a function and call it. No logic changes — just reposition:

```bash
if [ "$IS_PLANNING" = "true" ]; then
  _bc_assemble_planning_payload
  # _bc_assemble_planning_payload writes its own payload to stdout and
  # returns. The trap handles emit_result on exit.
  exit 0
fi
```

Define `_bc_assemble_planning_payload` as a function containing the current lines 352–507 of the pre-refactor file (the IS_PLANNING branch). This preserves the planning-payload output exactly. Do not modify its logic.

### Step 10: Resolve recipe and parse sections

```bash
# Recipe resolution: honor --recipe override, else resolve_recipe().
if [ -n "$RECIPE_OVERRIDE" ] && [ -f "$RECIPE_OVERRIDE" ]; then
  RECIPE_FILE="$RECIPE_OVERRIDE"
else
  RECIPE_FILE="$(resolve_recipe "$ORCH_ROOT" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" context-recipe.yaml 2>/dev/null || true)"
  if [ -z "$RECIPE_FILE" ] || [ ! -f "$RECIPE_FILE" ]; then
    RECIPE_FILE="$PROJECT_ROOT/templates/context-recipe.yaml"
  fi
fi
if [ ! -f "$RECIPE_FILE" ]; then
  printf 'build-context.sh: no recipe found at %s\n' "$RECIPE_FILE" >&2
  exit 1
fi
emit_event DISPATCH_START stage=recipe_resolved recipe="$RECIPE_FILE"
printf 'EVENT-AUDIT:DISPATCH_START stage="recipe_resolved"\n'
```

### Step 11: Iterate sections via recipe and dispatch to handlers

```bash
TMPDIR_BUILD="$(mktemp -d)"
INCLUDED_IDS_FILE="$(mktemp)"
trap 'rm -rf "$TMPDIR_BUILD"; rm -f "$INCLUDED_IDS_FILE"; _bc_final_result' EXIT

# parse_recipe_sections emits lines: <name>|<source>|<priority>|<order>|<filter>|<cache_hint>
# Order is already sorted ascending by `order` field.
RECIPE_LINES_FILE="$(mktemp)"
parse_recipe_sections "$RECIPE_FILE" > "$RECIPE_LINES_FILE"

SECTION_COUNT=0
SECTION_NAMES_PIPE=""
SECTION_PRIORITIES_PIPE=""

idx=1
while IFS='|' read -r s_name s_source s_priority s_order s_filter s_cache; do
  [ -z "$s_name" ] && continue
  SECTION_COUNT=$((SECTION_COUNT + 1))
  # Dispatch to handler
  # handle_knowledge receives the included_ids_file as its 5th arg when source=KNOWLEDGE.md
  dispatch_section_handler "$s_source" "$s_name" \
    "$ORCH_ROOT" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$INCLUDED_IDS_FILE" \
    > "$TMPDIR_BUILD/s${idx}.txt" 2>/dev/null || {
      # A handler failure is non-fatal for compressible/optional sections; for
      # required it is fatal. We don't have the priority-to-required mapping
      # here, so fail hard — the parity harness will catch regressions.
      emit_event SAFETY_WARNING reason=handler_failed section="$s_name" source="$s_source"
      printf 'EVENT-AUDIT:SAFETY_WARNING reason="handler_failed"\n'
    }

  # Pretty name for manifest (keep the "(N entries)" suffix for knowledge)
  disp_name="$s_name"
  case "$s_name" in
    knowledge|Knowledge)
      disp_name="Knowledge"
      if [ -s "$INCLUDED_IDS_FILE" ]; then
        entry_ct="$(grep -c 'MEM' "$INCLUDED_IDS_FILE" 2>/dev/null || echo 0)"
        disp_name="Knowledge ($entry_ct entries)"
      fi
      ;;
    decisions|Decisions)   disp_name="Decisions" ;;
    scope|Scope)           disp_name="Scope" ;;
    upstream|Upstream)     disp_name="Upstream Context" ;;
    task_plan|Task_Plan)   disp_name="Task Plan" ;;
    state|State)           disp_name="State Context" ;;
    constraints|Constraints) disp_name="Constraints" ;;
  esac

  # Priority mapping: recipe uses required/compressible/optional; manifest
  # uses required/filtered/optional to match the pre-refactor output shape.
  disp_pri="$s_priority"
  case "$s_priority" in
    compressible) disp_pri="filtered" ;;
  esac

  if [ -z "$SECTION_NAMES_PIPE" ]; then
    SECTION_NAMES_PIPE="$disp_name"
    SECTION_PRIORITIES_PIPE="$disp_pri"
  else
    SECTION_NAMES_PIPE="${SECTION_NAMES_PIPE}|${disp_name}"
    SECTION_PRIORITIES_PIPE="${SECTION_PRIORITIES_PIPE}|${disp_pri}"
  fi

  idx=$((idx + 1))
done < "$RECIPE_LINES_FILE"
rm -f "$RECIPE_LINES_FILE"
```

### Step 12: Port the manifest table assembly + final payload emission

Port the existing lines 610–735 of the pre-refactor script (manifest building, frontmatter, title, section concatenation, increment-hits loop, context-budget stderr line) verbatim. The `SECTION_NAMES`/`SECTION_PRIORITIES` variables are now populated by the recipe loop above — the rest of that logic does not change.

Change only the frontmatter block to keep the dispatch-prompt type:

```bash
FRONTMATTER='---
schema_version: "1.0"
type: dispatch-prompt
---'
```

### Step 13: Test parity against the golden fixture

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Refactored output
bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>/dev/null \
  > /tmp/bc-refactored.md

# Strip volatile columns for comparison (line numbers + token counts + entry counts)
normalize() {
  sed -E \
    -e 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g' \
    -e 's/~[0-9]+/~TOKENS/g' \
    -e 's/\(([0-9]+) entries\)/(N entries)/g'
}

normalize < .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md \
  > /tmp/bc-golden-norm.md
normalize < /tmp/bc-refactored.md > /tmp/bc-refactored-norm.md

diff -u /tmp/bc-golden-norm.md /tmp/bc-refactored-norm.md
# Exit 0 = match. Any output is a parity violation.
```

If diff shows non-empty output, inspect the divergence, fix the handler or the loop, re-run. Iterate until diff is clean.

### Step 14: Verify standalone mode still works

```bash
( unset ORCH_RUN_ID ORCH_STARTED_AT; \
  bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>/dev/null \
  | head -5 )
# Must print payload frontmatter.
```

### Step 15: Verify RESULT line is emitted

```bash
bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>&1 >/dev/null \
  | grep -c '^RESULT:' | grep -q '^1$' && echo "PASS: one RESULT" || echo "FAIL: RESULT count wrong"
```

Note: emit_result writes to stdout, not stderr. If the script emits RESULT after the payload on stdout, the grep needs to look at stdout. Adjust:

```bash
bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>/dev/null \
  | grep -c '^RESULT:' | grep -q '^1$' && echo "PASS: one RESULT" || echo "FAIL"
```

This will fail the parity diff if the RESULT line ends up in the payload output. To handle this, the trap should write to stderr instead:

```bash
_bc_final_result() {
  local rc=$?
  if [ "$_BC_RESULT_EMITTED" -eq 0 ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "context assembled" >&2
    else
      emit_result error CONFIG "build-context exited rc=$rc" >&2
    fi
    _BC_RESULT_EMITTED=1
  fi
}
```

The verify command becomes:

```bash
bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>&1 >/dev/null \
  | grep -c '^RESULT:' | grep -q '^1$' && echo "PASS: one RESULT" || echo "FAIL"
```

Pick the stderr variant; it keeps the payload pure and is consistent with the engine's existing pipe-to-file convention.

## Must-Haves

### Truths

- `scripts/dispatch/build-context.sh` sources `recipe-parser.sh` and calls `parse_recipe_sections`
  - Check: `grep -q 'recipe-parser.sh' scripts/dispatch/build-context.sh && grep -q 'parse_recipe_sections' scripts/dispatch/build-context.sh`
- `scripts/dispatch/build-context.sh` sources `section-handlers.sh`
  - Check: `grep -q 'lib/section-handlers.sh' scripts/dispatch/build-context.sh`
- `scripts/dispatch/build-context.sh` sources all 3 P02 libraries
  - Check: `grep -q 'scripts/lib/errors.sh' scripts/dispatch/build-context.sh && grep -q 'scripts/lib/events.sh' scripts/dispatch/build-context.sh && grep -q 'scripts/lib/run-context.sh' scripts/dispatch/build-context.sh`
- `scripts/dispatch/build-context.sh` calls `emit_result`
  - Check: `grep -q 'emit_result' scripts/dispatch/build-context.sh`
- No inline `date` calls
  - Check: `! grep -nE '\$\(date\b|^[[:space:]]*date[[:space:]]+-u' scripts/dispatch/build-context.sh`
- No hardcoded SEC_KNOWLEDGE etc. string constants left over (recipe-driven)
  - Check: `test "$(grep -c '^  SEC_KNOWLEDGE=' scripts/dispatch/build-context.sh)" -eq 0`
- Parity holds against golden fixture
  - Check: `bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>/dev/null | sed -E 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g; s/~[0-9]+/~TOKENS/g; s/\(([0-9]+) entries\)/(N entries)/g' > /tmp/t02-ref.md && sed -E 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g; s/~[0-9]+/~TOKENS/g; s/\(([0-9]+) entries\)/(N entries)/g' < .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md > /tmp/t02-gold.md && diff -q /tmp/t02-gold.md /tmp/t02-ref.md`
- Exactly one RESULT line emitted
  - Check: `bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>&1 >/dev/null | grep -c '^RESULT:' | grep -q '^1$'`
- Standalone mode (no ORCH_RUN_ID) still produces valid output
  - Check: `( unset ORCH_RUN_ID ORCH_STARTED_AT; bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>/dev/null | head -1 | grep -q '^---$' )`

### Artifacts

- `scripts/dispatch/build-context.sh` (min 200 lines, contains "parse_recipe_sections")
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md` (min 20 lines, contains "Dispatch Context")

### Key Links

- `scripts/dispatch/build-context.sh` → `scripts/lib/recipe-parser.sh`
- `scripts/dispatch/build-context.sh` → `scripts/dispatch/lib/section-handlers.sh`
- `scripts/dispatch/build-context.sh` → `templates/context-recipe.yaml`

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T02 Verification ==="

# File still exists, still executable
test -f scripts/dispatch/build-context.sh && echo "PASS: file exists" || echo "FAIL"
test -x scripts/dispatch/build-context.sh && echo "PASS: executable" || echo "FAIL"

# Min lines
lines=$(wc -l < scripts/dispatch/build-context.sh | tr -d ' ')
test "$lines" -ge 200 && echo "PASS: $lines lines (min 200)" || echo "FAIL: $lines lines"

# Sources the right libraries
for lib in errors.sh events.sh run-context.sh recipe-parser.sh; do
  grep -q "scripts/lib/$lib" scripts/dispatch/build-context.sh \
    && echo "PASS: sources $lib" || echo "FAIL: missing $lib source"
done
grep -q 'lib/section-handlers.sh' scripts/dispatch/build-context.sh \
  && echo "PASS: sources section-handlers" || echo "FAIL"

# Uses recipe parser functions
grep -q 'parse_recipe_sections' scripts/dispatch/build-context.sh \
  && echo "PASS: parse_recipe_sections" || echo "FAIL"

# Bash 3.2 compat
! grep -qE 'declare -A|readarray|mapfile' scripts/dispatch/build-context.sh \
  && echo "PASS: Bash 3.2" || echo "FAIL"

# No inline date
! grep -nE '\$\(date\b|^[[:space:]]*date[[:space:]]+-u' scripts/dispatch/build-context.sh \
  && echo "PASS: no inline date" || echo "FAIL"

# emit_result called
grep -q 'emit_result' scripts/dispatch/build-context.sh \
  && echo "PASS: emit_result" || echo "FAIL"

# Parity check
bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>/dev/null \
  | sed -E 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g; s/~[0-9]+/~TOKENS/g; s/\(([0-9]+) entries\)/(N entries)/g' \
  > /tmp/t02-refactored-norm.md
sed -E 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g; s/~[0-9]+/~TOKENS/g; s/\(([0-9]+) entries\)/(N entries)/g' \
  < .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md \
  > /tmp/t02-golden-norm.md
diff -q /tmp/t02-golden-norm.md /tmp/t02-refactored-norm.md \
  && echo "PASS: parity holds" || echo "FAIL: parity broken"

# RESULT emission
bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>&1 >/dev/null \
  | grep -c '^RESULT:' | grep -q '^1$' \
  && echo "PASS: one RESULT line" || echo "FAIL"

# Standalone mode
( unset ORCH_RUN_ID ORCH_STARTED_AT; \
  bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>/dev/null \
  | head -1 | grep -q '^---$' ) \
  && echo "PASS: standalone mode" || echo "FAIL"
```

## Inputs

### From Previous Tasks

- `scripts/dispatch/lib/section-handlers.sh` (from T01)
  - Key API:
    - `dispatch_section_handler <source> <section_name> <orch_root> <milestone> <phase> <task> [<included_ids_file>]`
    - Individual handlers: `handle_computed`, `handle_phase_summaries`, `handle_phase_plan`, `handle_task_plan`, `handle_template`, `handle_knowledge`, `handle_decisions`, `handle_file`
  - Key types: section body (plain text, printed to stdout); included_ids_file is a path to a writable file where knowledge handler writes MEM IDs one per line.
  - Behavioral contract: Each handler prints a complete section to stdout including its `## Section Name` header. The dispatcher routes by `source` field value. The `handle_template` handler reads `SH_VERIFICATION_CRITERIA`, `SH_DURATION_BUDGET`, `SH_DISPATCH_BUDGET`, `SH_BUDGET_ENFORCEMENT` from the environment.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — the pre-refactor script. Lines 352–507 contain the IS_PLANNING branch that must be preserved verbatim in the `_bc_assemble_planning_payload` helper. Lines 610–735 contain the manifest-table / frontmatter / final-payload assembly that is ported verbatim into the refactored script after the recipe loop.
- `scripts/lib/errors.sh` — provides `emit_result <ok|error> [kind] [detail]`. Closed kinds: CONFIG STATE DISPATCH VERIFY BUDGET IO.
- `scripts/lib/events.sh` — provides `emit_event <TYPE> [key=value ...]`. Registered types include `DISPATCH_START`, `SESSION_START`, `SAFETY_WARNING`. Single-word values are emitted unquoted (P06 will fix); pair with literal-audit-marker printf when a grep depends on the quoted form.
- `scripts/lib/run-context.sh` — provides `init_run_context [milestone] [phase]`, `orch_now`, `orch_is_forced`, `orch_is_dry_run`. Sets `ORCH_RUN_ID`, `ORCH_STARTED_AT`.
- `scripts/lib/recipe-parser.sh` — provides `parse_recipe_sections <file>`, `resolve_recipe <orch_root> <milestone> <phase> <task> <filename>`, `read_recipe_field`. `parse_recipe_sections` output format: `<name>|<source>|<priority>|<order>|<filter>|<cache_hint>`, already sorted by order ascending.
- `templates/context-recipe.yaml` — the default recipe. Declares 7 sections (knowledge, decisions, upstream, scope, task_plan, state, constraints) with source, priority, order, filter, cache_hint fields. Section priorities: `required` (task_plan, scope, state), `compressible` (knowledge, decisions, upstream), `optional` (constraints).
- `scripts/state/read-roadmap.sh` — provides `<roadmap> phase <P##>` and `<roadmap> tier` readers.
- `scripts/state/read-config.sh` — provides `<key> --defaults <file>` lookup.
- `scripts/engine/run.sh` — NOT modified. Must continue to invoke `build-context.sh .specify/orchestrator "$ENGINE_MILESTONE" "$ENGINE_PHASE" "$task_id"` at line ~236 unchanged.

## Expected Output

- `scripts/dispatch/build-context.sh` rewritten as a recipe interpreter (~220–280 lines estimated).
- `scripts/dispatch/build-context.sh` sources errors.sh, events.sh, run-context.sh, recipe-parser.sh, and lib/section-handlers.sh.
- `scripts/dispatch/build-context.sh` emits exactly one RESULT line per run (to stderr via trap).
- Parity holds: running the refactored script against M004/P04/T04 produces (after normalizing line-range and token columns) the same output as the golden fixture.
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md` exists, captured in Step 1.
- `scripts/engine/run.sh` is unchanged (diff is empty for that file).
- The `PHASE_PLAN` / planning-payload output is unchanged (diff against a pre-refactor capture for `TASK_ID=PHASE_PLAN` is clean).
