---
schema_version: "1.0"
type: dispatch-prompt
---

# Dispatch Context -- T02 (Phase P04, Milestone M004)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge | 19-21 | ~100 | filtered |
| Decisions | 23-25 | ~100 | filtered |
| Scope | 27-55 | ~400 | required |
| Upstream Context | 57-88 | ~600 | required |
| Task Plan | 90-332 | ~2500 | required |
| State Context | 334-340 | ~100 | required |
| Constraints | 342-347 | ~100 | required |
| **Total** | | **~3900** | |

## Knowledge

No knowledge entries in scope.

## Decisions

No decision entries in scope.

## Scope

### Goal


### Demo


### Must-Haves
## Must-Haves

### Truths

- context-recipe.yaml declares exactly 7 sections with name, source, priority, and order fields
  - Check: `test "$(grep -c '^  [a-z_]*:$' templates/context-recipe.yaml)" -ge 7`
- context-recipe.yaml has a compression block with at least 3 graduated steps
  - Check: `grep -q 'compression:' templates/context-recipe.yaml`
- hooks.yaml declares exactly 4 lifecycle points (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE)
  - Check: `for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do grep -q "$p" templates/hooks.yaml || exit 1; done && echo PASS`
- hooks.yaml entries have name, script, enabled, and block_on_fail fields
  - Check: `grep -q 'block_on_fail:' templates/hooks.yaml`
- routing.yaml has fallback arrays for each tier (heavy, standard, light)
  - Check: `test "$(grep -c 'fallback:' templates/routing.yaml)" -ge 3`
- recipe-parser.sh has double-sourcing guard
  - Check: `head -5 scripts/lib/recipe-parser.sh | grep -q '_RECIPE_PARSER_SOURCED'`
- recipe-parser.sh exports parse_recipe_sections, parse_recipe_compression, and read_recipe_field functions
  - Check: `grep -q 'parse_recipe_sections' scripts/lib/recipe-parser.sh && grep -q 'parse_recipe_compression' scripts/lib/recipe-parser.sh && grep -q 'read_recipe_field' scripts/lib/recipe-parser.sh`
- All YAML files parseable by grep/sed/awk (no jq required, max 2 levels nesting)
  - Check: `grep -c '^      ' templates/context-recipe.yaml | xargs test 0 -eq`

## Upstream Context


### P01 Summary
---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M004"
milestone: "M004"
provides:
  - "Constitution v2.0.0 with 13 principles (I-XIII), amended Principle II requiring structured events, Sync Impact Report, ANTIPATTERNS.md append-only register with 3 entries (AP-001 through AP-003) referencing M001-M003 incidents"
requires:
  - "from:T01 what:Constitution v2.0.0 with principles VIII-XIII for principle references"
affects:
  - "All M004 phases — new principles govern compliance checks, All future phases — antipatterns serve as permanent warnings for recurring structural failures"
key_files:
  - ".specify/memory/constitution.md, ANTIPATTERNS.md"
key_decisions:
  - "AD-10: MAJOR version bump 1.0.0→2.0.0, AD-11: Antipatterns are permanent with no staleness decay"
patterns_established:
  - "Principle amendment pattern with Sync Impact Report; Roman numeral principle numbering through XIII, Antipattern entry format: AP-NNN with Observed In, Principle Violated, Description, Evidence, Remedy sections; Append-only register pattern"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P01/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P01/tasks/T02-SUMMARY.md"
duration: "170m"
verification_result: "pass"
completed_at: "2026-04-10T20:11:23Z"
observability_surfaces:
  - "none (governance phase, no runtime metrics)"
---

Phase P01 updated the orchestrator constitution from v1.0.0 to v2.0.0 and established the antipattern register. Constitution v2.0.0 adds 6 new principles: VIII (No Dead Infrastructure), IX (Reproducibility Over Convenience), X (Templating Over Inference), XI (Single Source of Truth), XII (Hook Isolation), XIII (Agent Instruction Schema). Principle II amended to require structured event emission (emit_event/emit_result) from engine-managed scripts. ANTIPATTERNS.md created at orchestrator root with 3 entries from real M001-M003 audit incidents: AP-001 (Bash 3.2 process substitution), AP-002 (sed -i portability), AP-003 (missing double-sourcing guards). All entries reference specific milestones and constitution principles. Sync Impact Report documents version change, added/amended principles, and template impact. All 7 phase must-haves verified passing.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M004"
name: "Hook Configuration YAML"
depends_on: []
---

## Description

Create `templates/hooks.yaml` — the default hook configuration that declares lifecycle hook points, hook scripts, and their behavior (enabled, blocking). The file declares 4 lifecycle points (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE) with built-in guard hooks for each. The schema is constrained to 2 levels of nesting maximum for grep/sed/awk parsing.

This implements:
- US5 (Hook Lifecycle System): AS1, AS2, AS3, AS4, AS5, AS6
- FR-214
- Principles XII (Hook Isolation), X (Templating Over Inference)

## Steps

### Step 1: Understand hook requirements

From the spec (US5), hooks must support:
- 4 lifecycle points: PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE
- Each hook has: name, script path, enabled flag, block_on_fail flag
- Hooks receive frozen state snapshot (read-only temp file)
- Hooks block by default (block_on_fail: true)
- A hook with block_on_fail: false emits warning but does not stop pipeline
- Disabling a hook prevents it from running

The built-in guard hooks map to existing safety rail requirements (US6):
- PRE_DISPATCH: payload sanity check (non-empty, >100 chars)
- POST_DISPATCH: output sanity check (non-empty, >100 chars)
- POST_VERIFY: phase completeness check (SUMMARY.md has content)
- PRE_ADVANCE: budget check (cumulative cost within limits)

### Step 2: Create `templates/hooks.yaml`

Create the file `templates/hooks.yaml` with the exact content below. Schema uses 2 levels of nesting (top-level block > hook-level keys). Hook entries are identified by a unique key under each lifecycle point.

```yaml
# templates/hooks.yaml — Default hook lifecycle configuration
# Declares hook scripts at 4 lifecycle points in the dispatch pipeline.
#
# Schema: max 2 levels of nesting. Parseable by grep/sed/awk (no jq required).
# Override: place a hooks.yaml in a milestone or phase directory.
#
# Lifecycle points (execution order):
#   PRE_DISPATCH  — after context assembly, before agent dispatch
#   POST_DISPATCH — after agent returns output, before verification
#   POST_VERIFY   — after verification completes, before result recording
#   PRE_ADVANCE   — after result recording, before phase/task state advance
#
# Hook behavior:
#   enabled:       true | false — disabled hooks are skipped entirely
#   block_on_fail: true | false — true = non-zero exit stops pipeline
#                                  false = non-zero exit emits warning only
#   timeout:       seconds before hook is killed (default: 30)
#
# Hooks receive a frozen state snapshot as $1 (chmod 444 temp file).
# Hooks MUST NOT modify engine state (Principle XII: Hook Isolation).
#
# Constitution: Principle X (Templating Over Inference), Principle XII
# (Hook Isolation).

# --- Global Hook Settings ---
hook_defaults:
  timeout: 30
  block_on_fail: true

# --- PRE_DISPATCH Hooks ---
# Run after context assembly, before agent dispatch.
# Use case: payload validation, budget pre-check, external gate (Conversus).
PRE_DISPATCH:
  payload_sanity:
    name: "Payload Sanity Check"
    script: "scripts/verify/guards/check-payload.sh"
    enabled: true
    block_on_fail: true
    description: "Block dispatch if payload is empty or under 100 chars"
  budget_precheck:
    name: "Budget Pre-Check"
    script: "scripts/verify/guards/check-budget.sh"
    enabled: true
    block_on_fail: true
    description: "Block dispatch if cumulative cost exceeds budget ceiling"

# --- POST_DISPATCH Hooks ---
# Run after agent returns output, before verification.
# Use case: output validation, response quality gate.
POST_DISPATCH:
  output_sanity:
    name: "Output Sanity Check"
    script: "scripts/verify/guards/check-output.sh"
    enabled: true
    block_on_fail: true
    description: "Record as blocked if agent output is empty or under 100 chars"

# --- POST_VERIFY Hooks ---
# Run after verification completes, before result recording.
# Use case: phase completeness check, summary quality gate.
POST_VERIFY:
  phase_completeness:
    name: "Phase Completeness Check"
    script: "scripts/verify/guards/check-phase-complete.sh"
    enabled: true
    block_on_fail: false
    description: "Warn if SUMMARY.md exists but has no content sections"

# --- PRE_ADVANCE Hooks ---
# Run after result recording, before phase/task state advance.
# Use case: final budget enforcement, knowledge consolidation trigger.
PRE_ADVANCE:
  budget_enforcement:
    name: "Budget Enforcement"
    script: "scripts/verify/guards/check-budget-advance.sh"
    enabled: true
    block_on_fail: true
    description: "Block advance if budget exceeded after recording cost"
  knowledge_trigger:
    name: "Knowledge Consolidation Trigger"
    script: "scripts/knowledge/trigger-consolidation.sh"
    enabled: false
    block_on_fail: false
    description: "Trigger knowledge consolidation on phase advance (future)"
```

### Step 3: Verify the schema and content

Run the following verification commands:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# 4 lifecycle points
for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do
  grep -q "^${p}:" templates/hooks.yaml && echo "PASS: $p declared" || echo "FAIL: $p missing"
done

# Hook entries have required fields
for f in name script enabled block_on_fail; do
  count=$(grep -c "$f:" templates/hooks.yaml)
  test "$count" -ge 4 && echo "PASS: $f field ($count occurrences)" || echo "FAIL: $f field (only $count)"
done

# At least 6 hook entries total
hooks=$(grep -c '    name:' templates/hooks.yaml)
test "$hooks" -ge 6 && echo "PASS: $hooks hook entries" || echo "FAIL: only $hooks hooks"

# No deep nesting (8+ spaces = level 3+)
# Level 1 = no indent (lifecycle points), Level 2 = 2 spaces (hook keys), Level 2 fields = 4 spaces
deep=$(grep -cE '^        [a-z]' templates/hooks.yaml)
test "$deep" -eq 0 && echo "PASS: max 2 levels nesting" || echo "FAIL: $deep deep nesting lines"

# Default timeout
grep -q 'timeout: 30' templates/hooks.yaml && echo "PASS: timeout configured" || echo "FAIL: no timeout"

# Hook Isolation principle referenced
grep -q 'Hook Isolation' templates/hooks.yaml && echo "PASS: Principle XII referenced" || echo "FAIL: no Hook Isolation reference"
```

## Must-Haves

### Truths

- hooks.yaml declares exactly 4 lifecycle points (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE)
  - Check: `for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do grep -q "^${p}:" templates/hooks.yaml || exit 1; done && echo PASS`
- Each hook entry has name, script, enabled, and block_on_fail fields
  - Check: `test "$(grep -c 'block_on_fail:' templates/hooks.yaml)" -ge 4`
- At least 6 hook entries declared across all lifecycle points
  - Check: `test "$(grep -c '    name:' templates/hooks.yaml)" -ge 6`
- Default timeout is configured (30 seconds)
  - Check: `grep -q 'timeout: 30' templates/hooks.yaml`
- Schema uses max 2 levels of nesting
  - Check: `test "$(grep -cE '^        [a-z]' templates/hooks.yaml)" -eq 0`

### Artifacts

- `templates/hooks.yaml` (min 40 lines, contains "PRE_DISPATCH")

### Key Links

- `templates/hooks.yaml` → `.specify/memory/constitution.md` (implements Principle XII: Hook Isolation)
- `templates/hooks.yaml` → `specs/004-engine-architecture/spec.md` (implements US5, FR-214)

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T02 Verification ==="

# File exists and has minimum lines
test -f templates/hooks.yaml && echo "PASS: file exists" || echo "FAIL: file missing"
lines=$(wc -l < templates/hooks.yaml | tr -d ' ')
test "$lines" -ge 40 && echo "PASS: $lines lines (min 40)" || echo "FAIL: only $lines lines"

# 4 lifecycle points
for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do
  grep -q "^${p}:" templates/hooks.yaml && echo "PASS: $p" || echo "FAIL: $p missing"
done

# Hook entries
hooks=$(grep -c '    name:' templates/hooks.yaml)
test "$hooks" -ge 6 && echo "PASS: $hooks hooks (min 6)" || echo "FAIL: only $hooks hooks"

# Required fields present on hooks
for f in name script enabled block_on_fail; do
  count=$(grep -c "$f:" templates/hooks.yaml)
  test "$count" -ge 4 && echo "PASS: $f ($count)" || echo "FAIL: $f ($count)"
done

# No deep nesting
deep=$(grep -cE '^        [a-z]' templates/hooks.yaml)
test "$deep" -eq 0 && echo "PASS: max 2 nesting levels" || echo "FAIL: $deep deep lines"

# Timeout configured
grep -q 'timeout: 30' templates/hooks.yaml && echo "PASS: timeout" || echo "FAIL: no timeout"
```

## Inputs

### From Previous Tasks

None — T02 has no upstream task dependencies within P04.

### From Disk (Pre-existing)

- `specs/004-engine-architecture/spec.md` — US5 (AS1-AS6), US6 (AS1-AS5), FR-214, NFR-205 (30s timeout). Full requirements for hook system.
- `.specify/memory/constitution.md` — Principle XII (Hook Isolation): hooks receive read-only snapshots, MUST NOT modify engine state. Principle X (Templating Over Inference): hook behavior declared in config.
- `scripts/dispatch/build-context.sh` — The pipeline that hooks will eventually wrap. Understanding the pipeline flow clarifies lifecycle point placement.

## Expected Output

The file `templates/hooks.yaml` containing:
- Header comment with schema description, lifecycle point documentation, and constitution references
- `hook_defaults:` block with timeout and default block_on_fail settings
- 4 lifecycle point blocks (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE)
- At least 6 hook entries total with name, script, enabled, block_on_fail, and description
- Built-in guard hooks for payload sanity, output sanity, budget checks, and phase completeness
- Maximum 2 levels of nesting, parseable by grep/sed/awk

## State Context

- **Current State**: executing
- **Milestone**: M004
- **Phase**: P04
- **Task**: T02
- **Tier**: C

## Constraints

- **Verification Criteria**: See phase plan must-haves
- **Duration Budget**: 2h
- **Dispatch Budget**: 3
- **Budget Enforcement**: warn