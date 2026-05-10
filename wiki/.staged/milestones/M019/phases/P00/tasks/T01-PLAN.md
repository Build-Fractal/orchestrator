---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P00"
milestone: "M019"
name: "Payload structure adaptation in scripts/dispatch/build-context.sh for Opus 4.7 defaults (L1 first-turn completeness block + L2 stable-before-volatile ordering with <dispatch-volatile> markers + L4 explicit parallel-fan-out directive) plus the payload-shape verify gate that asserts L1–L5 invariants on a fixture-built payload."
depends_on: []
---

## Prerequisites

None. T01 is the first task of P00. Repository pre-existing state:

- `scripts/dispatch/build-context.sh` — recipe-driven dispatch payload assembler with two branches: PLANNING branch (triggered when `task == PHASE_PLAN`) and TASK branch (triggered otherwise). Both branches call `_bc_assemble_manifest_and_emit` to write the final payload. Each section is written to a numbered temp file (`TMPDIR_BUILD/s<N>.txt`), then manifest is built, then sections are concatenated. This task modifies the TASK branch only (PLANNING branch sections are intentionally different and not emitter-facing — they feed plan-phase, not dispatch-to-agent).
- `templates/dispatch-prompt.md` — the dispatch payload template (shape declaration, not a concatenation target in the recipe-driven path; sections are assembled from the recipe).
- `templates/context-recipe.yaml` — the default recipe. Declares 8 sections (knowledge, decisions, constraints, spec_context, scope, upstream, task_plan, state). Has no `parallel_fan_out:` field currently.
- [`.orchestrator/milestones/M019/M019-ROADMAP.md`](../../../../../milestones/M019/M019-ROADMAP.md) — roadmap describing P00 Boundary Map produces set.
- [`.orchestrator/milestones/M019/M019-CONTEXT.md`](../../../../../milestones/M019/M019-CONTEXT.md) — design constraints + AD-1..AD-8 definitions.
- `.orchestrator/scratch/articles-synthesis-2026-04-17.md` — L1–L5 source material (Opus 4.7 adaptation tactics).

## Description

Modify `scripts/dispatch/build-context.sh` TASK branch so every dispatched task payload carries three Opus-4.7-aligned structural additions, then author the verify gate that asserts all five L-invariants (L1, L2, L3, L4, L5) plus pricing.yml existence on a fixture-built payload.

The three structural additions:

1. **L1 — First-Turn Completeness block.** After recipe section assembly and before manifest assembly, compute a derived `## First-Turn Completeness` block containing four labelled subsections (`### Intent`, `### Constraints`, `### Acceptance Criteria`, `### Files To Touch`) sourced by grep/sed extraction from the task plan and phase plan content that is *already* included elsewhere in the payload. **No new agent-facing prose.** The block is a structural re-surfacing of content the agent already receives, positioned first among volatile sections (front-loading intent per A1).
2. **L2 — Stable-before-volatile ordering with `<dispatch-volatile>` markers.** Reorder section emission so stable sections (`## Knowledge`, `## Decisions`, `## Constraints`) are emitted first, then a standalone line `<dispatch-volatile>`, then volatile sections (`## First-Turn Completeness`, `## State Context`, `## Task Plan`, `## Upstream Context`, `## Parallel Fan-Out` when present), then a standalone closing line `</dispatch-volatile>`. `## Scope` is neutral per the display-order map (appears at display-order 5) and is classified stable for this purpose.
3. **L4 — Parallel-Fan-Out directive.** Emit a `## Parallel Fan-Out` block with the known-literal text "When this task requires reading multiple files or fanning out across items, spawn multiple subagents in the same turn rather than issuing serial tool calls." WHEN either (a) the resolved recipe file contains a top-level `parallel_fan_out: true` field OR a per-section `parallel_fan_out: true` on any section, OR (b) the task plan YAML frontmatter contains `parallelizable: true`. Otherwise the block is omitted entirely (no empty section).

Plus: the verify gate `scripts/verify/m019-p00-payload-shape.sh` that drives build-context.sh against a fixture and asserts all L1–L5 invariants + pricing.yml existence.

## Steps

### Step 1: Modify `scripts/dispatch/build-context.sh` — TASK branch section assembly

**File:** `scripts/dispatch/build-context.sh`

**Location:** inside the TASK branch (after line 833, `rm -f "$SORTED_SECTIONS_FINAL"`), BEFORE the final `_bc_assemble_manifest_and_emit` call (line 842).

**Add three helper functions** near the top of the TASK-branch code (before the main dispatch loop, after the `_bc_handle_phase_summaries_fixed` function ends around line 777):

```bash
# --- P00/L1: First-Turn Completeness block ---
# Derive a 4-subsection block from the already-included task plan + phase plan
# content. This is a structural re-surfacing; the content is already in the
# payload via the task_plan and scope sections. We extract and group four
# specific pieces so the model sees intent+constraints+acceptance+files in
# turn 1, per A1 "senior-engineer delegation" guidance.
_bc_build_first_turn_completeness() {
  local task_plan_path="$1"  # "$PHASE_DIR/tasks/$TASK_ID-PLAN.md"
  local phase_plan_path="$2" # "$PHASE_DIR/$PHASE_ID-PLAN.md"
  local out
  out="## First-Turn Completeness"$'\n\n'
  out="${out}### Intent"$'\n'
  # Intent: task plan's Description section (first paragraph after "## Description")
  out="${out}$(sed -n '/^## Description$/,/^## /p' "$task_plan_path" 2>/dev/null | sed '1d;/^## /d' | sed '/^$/q' | head -30)"$'\n\n'
  out="${out}### Constraints"$'\n'
  # Constraints: task plan's ## Constraints section
  out="${out}$(sed -n '/^## Constraints$/,/^## /p' "$task_plan_path" 2>/dev/null | sed '1d;/^## /d' | head -40)"$'\n\n'
  out="${out}### Acceptance Criteria"$'\n'
  # Acceptance: task plan's ## Must-Haves section (truths the task must satisfy)
  out="${out}$(sed -n '/^## Must-Haves$/,/^## /p' "$task_plan_path" 2>/dev/null | sed '1d;/^## /d' | head -40)"$'\n\n'
  out="${out}### Files To Touch"$'\n'
  # Files: phase plan's ## Files Likely Touched section
  out="${out}$(sed -n '/^## Files Likely Touched$/,/^## /p' "$phase_plan_path" 2>/dev/null | sed '1d;/^## /d' | head -60)"$'\n'
  printf '%s' "$out"
}

# --- P00/L4: Parallel Fan-Out directive ---
# Emit the known-literal fan-out directive when the recipe or task plan
# declares parallelizable work. Otherwise emit nothing (caller omits section).
_bc_should_emit_parallel_fanout() {
  local recipe_file="$1"
  local task_plan_path="$2"
  # (a) recipe-level or section-level parallel_fan_out: true
  if grep -qE '^[[:space:]]*parallel_fan_out:[[:space:]]*true' "$recipe_file" 2>/dev/null; then
    echo "yes"
    return 0
  fi
  # (b) task plan YAML frontmatter parallelizable: true
  if sed -n '1,/^---$/p' "$task_plan_path" 2>/dev/null | grep -qE '^parallelizable:[[:space:]]*true' ; then
    echo "yes"
    return 0
  fi
  echo "no"
}

_bc_build_parallel_fanout_block() {
  printf '## Parallel Fan-Out\n\n'
  printf 'When this task requires reading multiple files or fanning out across items, spawn multiple subagents in the same turn rather than issuing serial tool calls.\n'
}

# --- P00/L2: Section classifier for stable-before-volatile ordering ---
# Returns "stable" or "volatile" for a given canonical section base name.
# Volatile: content that changes per-task or per-turn (A3 cache boundary).
# Stable: content that stays constant across a phase or milestone.
_bc_section_volatility() {
  case "$1" in
    knowledge|decisions|constraints|scope) echo "stable" ;;
    state|task_plan|upstream|first_turn|parallel_fanout) echo "volatile" ;;
    *) echo "stable" ;;  # default: treat unknown as stable (conservative)
  esac
}
```

**Then modify the TASK-branch section-emit loop** (currently at lines 785–832) to:

1. After the existing dispatch loop finishes writing `TMPDIR_BUILD/s<idx>.txt` files and building `SECTION_NAMES_PIPE` / `SECTION_PRIORITIES_PIPE`, compute and append TWO NEW section temp files BEFORE manifest assembly:
   - **first_turn** section: call `_bc_build_first_turn_completeness "$TASK_PLAN" "$PHASE_PLAN" > "$TMPDIR_BUILD/s$(($SECTION_COUNT + 1)).txt"`, increment `SECTION_COUNT`, append display-name "First-Turn Completeness" and priority "required" to the pipe strings.
   - **parallel_fanout** section (conditional): if `_bc_should_emit_parallel_fanout "$RECIPE_FILE" "$TASK_PLAN"` returns "yes", call `_bc_build_parallel_fanout_block > "$TMPDIR_BUILD/s$(($SECTION_COUNT + 1)).txt"`, increment, append "Parallel Fan-Out" / "required" to the pipe strings.

2. Reorder section files BEFORE the call to `_bc_assemble_manifest_and_emit`. The existing order is determined by `_bc_display_order` values 1..8. Replace the final "flatten s<idx>.txt files into payload" step in `_bc_assemble_manifest_and_emit` with a pre-sort that partitions sections into two lists:
   - **stable_list**: s<N>.txt files whose canonical section base name classifies as "stable" per `_bc_section_volatility`. Preserve within-partition display-order.
   - **volatile_list**: s<N>.txt files whose canonical section base name classifies as "volatile". Preserve within-partition display-order.

3. In `_bc_assemble_manifest_and_emit`'s final concatenation pass, emit in this order: FRONTMATTER → TITLE → MANIFEST → stable sections → `<dispatch-volatile>` → volatile sections → `</dispatch-volatile>`.

The CLEANEST way to do this given the existing `_bc_assemble_manifest_and_emit` shape is to (a) renumber s<N>.txt files into stable-first order before calling the helper (so the helper continues to emit in sN-order) and (b) inject the two marker lines by writing a sentinel-delimited "stable cutoff index" into a side-channel variable `BC_VOLATILE_CUTOFF_IDX` that the helper reads and inserts the two marker lines around.

**Concrete implementation sketch** (insert AFTER the section-emit loop closes at line 833 in `build-context.sh`):

```bash
# --- P00/L1: Append First-Turn Completeness volatile section ---
SECTION_COUNT=$((SECTION_COUNT + 1))
_bc_build_first_turn_completeness "$TASK_PLAN" "$PHASE_PLAN" \
  > "$TMPDIR_BUILD/s${SECTION_COUNT}.txt"
SECTION_NAMES_PIPE="${SECTION_NAMES_PIPE}|First-Turn Completeness"
SECTION_PRIORITIES_PIPE="${SECTION_PRIORITIES_PIPE}|required"
# Track as volatile for L2 ordering
BC_VOLATILE_SECTION_IDXS="${BC_VOLATILE_SECTION_IDXS:-}${SECTION_COUNT} "

# --- P00/L4: Append Parallel Fan-Out volatile section (conditional) ---
if [ "$(_bc_should_emit_parallel_fanout "$RECIPE_FILE" "$TASK_PLAN")" = "yes" ]; then
  SECTION_COUNT=$((SECTION_COUNT + 1))
  _bc_build_parallel_fanout_block > "$TMPDIR_BUILD/s${SECTION_COUNT}.txt"
  SECTION_NAMES_PIPE="${SECTION_NAMES_PIPE}|Parallel Fan-Out"
  SECTION_PRIORITIES_PIPE="${SECTION_PRIORITIES_PIPE}|required"
  BC_VOLATILE_SECTION_IDXS="${BC_VOLATILE_SECTION_IDXS}${SECTION_COUNT} "
fi

# --- P00/L2: Classify pre-existing recipe-emitted sections as stable/volatile ---
# Walk the sorted sections file we already emitted (idx assignments) and mark
# which original-recipe section indexes are volatile. We use the display-name
# to classify. Knowledge, Decisions, Constraints, Scope -> stable.
# State Context, Task Plan, Upstream Context -> volatile.
BC_STABLE_IDXS=""
BC_VOLATILE_LEGACY_IDXS=""
i=1
IFS='|' read -ra _BC_NAMES <<EOF_NAMES
$SECTION_NAMES_PIPE
EOF_NAMES
for nm in "${_BC_NAMES[@]}"; do
  case "$nm" in
    "Knowledge"*|"Decisions"|"Constraints"|"Scope")
      BC_STABLE_IDXS="${BC_STABLE_IDXS}${i} " ;;
    "First-Turn Completeness"|"Parallel Fan-Out")
      : ;;  # already tracked in BC_VOLATILE_SECTION_IDXS
    *)
      BC_VOLATILE_LEGACY_IDXS="${BC_VOLATILE_LEGACY_IDXS}${i} " ;;
  esac
  i=$((i + 1))
done
BC_VOLATILE_ALL_IDXS="${BC_VOLATILE_SECTION_IDXS}${BC_VOLATILE_LEGACY_IDXS}"
export BC_STABLE_IDXS BC_VOLATILE_ALL_IDXS
```

Then modify `_bc_assemble_manifest_and_emit`'s final section-emit loop (the `for i in $(seq 1 "$section_count")` around line 584) to read `BC_STABLE_IDXS` and `BC_VOLATILE_ALL_IDXS` and emit stable-first, then `<dispatch-volatile>`, then volatile, then `</dispatch-volatile>`. If either env var is empty (planning branch still calls this helper with no classification set), fall back to current behavior (emit in sN order, no marker lines).

**Constraints during modification:**

- No `declare -A`, no `mapfile`, no process substitution.
- Preserve the RESULT-line emission trap (line 52–68).
- Preserve the PLANNING branch behavior byte-identically (planning doesn't get the new sections or markers).
- The `<dispatch-volatile>` markers are emitted as standalone lines in the payload body (not XML inside another element).

### Step 2: Add shape markers to `templates/dispatch-prompt.md`

**File:** `templates/dispatch-prompt.md`

Add a new block AFTER the frontmatter and before the existing `## State Context` section, documenting the dispatch payload shape for downstream template consumers:

```markdown
## First-Turn Completeness

<!-- Emitted by scripts/dispatch/build-context.sh (P00/L1). Derived block
     surfacing intent + constraints + acceptance criteria + files-to-touch
     from the already-included task plan and phase plan. First volatile
     section (appears after the <dispatch-volatile> marker below). -->

{{first_turn_completeness}}
```

Add, somewhere before `## Payload Size Guidance`, a documenting comment block explaining the `<dispatch-volatile>` marker contract:

```markdown
<!-- P00/L2 Cache Boundary Contract:
     Dispatch payloads assembled by scripts/dispatch/build-context.sh emit
     stable sections (Knowledge, Decisions, Constraints, Scope) first, then
     a standalone `<dispatch-volatile>` line, then volatile sections
     (First-Turn Completeness, State Context, Task Plan, Upstream Context,
     Parallel Fan-Out when applicable), then a standalone `</dispatch-volatile>`
     line. This aligns with Opus 4.7 cache-boundary guidance (per
     .orchestrator/scratch/articles-synthesis-2026-04-17.md L2). Markers are
     standalone lines, not XML elements inside sections. -->

## Parallel Fan-Out

<!-- Emitted by scripts/dispatch/build-context.sh (P00/L4) ONLY when the
     recipe or task plan declares parallelizable work. Content is known-literal:
     "When this task requires reading multiple files or fanning out across
     items, spawn multiple subagents in the same turn rather than issuing
     serial tool calls." -->

{{parallel_fanout_directive}}
```

Leave existing sections (`## State Context`, `## Scope`, `## Upstream Context`, `## Knowledge`, `## Decisions`, `## Task Plan`, `## Constraints`, `## Verification`, `## Payload Size Guidance`) byte-identical in content. Do not rewrite expressive guidance here — T02 handles L3 + L5.

### Step 3: Create `scripts/verify/m019-p00-payload-shape.sh`

**File:** `scripts/verify/m019-p00-payload-shape.sh` (new, executable)

Complete script:

```bash
#!/usr/bin/env bash
# scripts/verify/m019-p00-payload-shape.sh — P00 payload-shape gate.
#
# Asserts L1–L5 Opus 4.7 adaptation invariants on a fixture-built dispatch
# payload plus required .orchestrator/config/pricing.yml presence.
#
# Exit 0 on all-pass, 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_CONTEXT="$REPO_ROOT/scripts/dispatch/build-context.sh"
DISPATCH_TEMPLATE="$REPO_ROOT/templates/dispatch-prompt.md"
INTENSITY_GATE="$REPO_ROOT/scripts/engine/intensity-gate.sh"
PRICING_YML="$REPO_ROOT/.orchestrator/config/pricing.yml"
NEG_WHITELIST="$REPO_ROOT/templates/.p00-negative-guidance-retained.txt"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# --- Gate 0: required files exist ---
for f in "$BUILD_CONTEXT" "$DISPATCH_TEMPLATE" "$INTENSITY_GATE"; do
  if [ ! -f "$f" ]; then
    fail "file exists" "$f"
  fi
done

# --- Gate 1 (L1): First-Turn Completeness emission in build-context.sh ---
if grep -q 'First-Turn Completeness' "$BUILD_CONTEXT"; then
  pass "L1 build-context.sh emits First-Turn Completeness"
else
  fail "L1 build-context.sh emits First-Turn Completeness" "marker missing"
fi
for sub in '### Intent' '### Constraints' '### Acceptance Criteria' '### Files To Touch'; do
  if grep -qF "$sub" "$BUILD_CONTEXT"; then
    pass "L1 subsection present: $sub"
  else
    fail "L1 subsection present" "$sub missing from build-context.sh"
  fi
done

# --- Gate 2 (L2): <dispatch-volatile> markers in build-context.sh ---
if grep -q '<dispatch-volatile>' "$BUILD_CONTEXT" && grep -q '</dispatch-volatile>' "$BUILD_CONTEXT"; then
  pass "L2 dispatch-volatile markers present in build-context.sh"
else
  fail "L2 dispatch-volatile markers" "open/close markers missing from build-context.sh"
fi

# --- Gate 3 (L3): no thinking_budget in templates/ or intensity-gate.sh ---
tb_count=0
tb_count=$(grep -rlE 'thinking_budget|thinking budget' "$REPO_ROOT/templates" 2>/dev/null | wc -l | tr -d ' ')
if [ "$tb_count" = "0" ]; then
  pass "L3 no thinking_budget in templates/"
else
  fail "L3 no thinking_budget in templates/" "found in $tb_count files"
fi
if grep -qE 'thinking_budget|thinking budget' "$INTENSITY_GATE" 2>/dev/null; then
  fail "L3 no thinking_budget in intensity-gate.sh" "found in $INTENSITY_GATE"
else
  pass "L3 no thinking_budget in intensity-gate.sh"
fi

# --- Gate 4 (L4): Parallel Fan-Out directive implementation in build-context.sh ---
if grep -q 'Parallel Fan-Out' "$BUILD_CONTEXT" && grep -qE 'parallel_fan_out|parallelizable' "$BUILD_CONTEXT"; then
  pass "L4 parallel fan-out directive logic present"
else
  fail "L4 parallel fan-out directive" "marker or trigger logic missing"
fi

# --- Gate 5 (L5): positive-examples rewrite of dispatch-prompt.md ---
# Enumerate all "Don't/Do not/Never/Avoid" lines in dispatch-prompt.md.
# Each must either (a) be in a section containing "Constitution XV" or
# "anti-pattern" within 5 surrounding lines, OR (b) be listed in the
# exception whitelist file.
if [ ! -f "$NEG_WHITELIST" ]; then
  fail "L5 exception whitelist exists" "$NEG_WHITELIST not found"
else
  pass "L5 exception whitelist exists"
fi

neg_violations=0
if [ -f "$DISPATCH_TEMPLATE" ]; then
  tmpneg="$(mktemp)"
  grep -nE "^[[:space:]]*-?[[:space:]]*(Don't|Do not|Never|Avoid)[[:space:]]" "$DISPATCH_TEMPLATE" > "$tmpneg" 2>/dev/null || true
  while IFS=: read -r lno rest; do
    [ -z "$lno" ] && continue
    # Check if this line number is whitelisted
    if [ -f "$NEG_WHITELIST" ] && grep -qE "^dispatch-prompt\.md:${lno}[[:space:]]" "$NEG_WHITELIST"; then
      continue
    fi
    # Check if within 5 lines, a constitutional-anti-pattern marker is present
    start=$((lno - 5))
    [ "$start" -lt 1 ] && start=1
    end=$((lno + 5))
    ctx="$(sed -n "${start},${end}p" "$DISPATCH_TEMPLATE")"
    if printf '%s' "$ctx" | grep -qE 'Constitution XV|anti-pattern' ; then
      continue
    fi
    neg_violations=$((neg_violations + 1))
    echo "  - dispatch-prompt.md:${lno}: $rest" >&2
  done < "$tmpneg"
  rm -f "$tmpneg"
fi
if [ "$neg_violations" = "0" ]; then
  pass "L5 no unwhitelisted negative guidance in dispatch-prompt.md"
else
  fail "L5 negative guidance violations" "$neg_violations unwhitelisted lines (see stderr)"
fi

# --- Gate 6: pricing.yml presence + required keys ---
if [ ! -f "$PRICING_YML" ]; then
  fail "pricing.yml exists" "$PRICING_YML not found"
else
  pass "pricing.yml exists"
  for key in 'last_updated:' 'opus' 'sonnet' 'haiku' 'input' 'output'; do
    if grep -q "$key" "$PRICING_YML"; then
      pass "pricing.yml contains $key"
    else
      fail "pricing.yml required key" "$key missing"
    fi
  done
fi

# --- Summary ---
if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m019-p00-payload-shape.sh"
  exit 0
else
  echo "FAIL: m019-p00-payload-shape.sh ($fail_count failures)"
  exit 1
fi
```

Make executable: `chmod +x scripts/verify/m019-p00-payload-shape.sh`.

## Must-Haves

- `scripts/dispatch/build-context.sh` contains the three literal markers `First-Turn Completeness`, `<dispatch-volatile>`, `Parallel Fan-Out` and the detection string `parallel_fan_out`. Verified by `scripts/verify/m019-p00-payload-shape.sh` Gates 1, 2, 4.
- `templates/dispatch-prompt.md` declares `## First-Turn Completeness` and `## Parallel Fan-Out` sections with documenting comments naming the marker contract. No byte-identical reduction of existing sections. Verified by manual inspection during T02 (T02's sweep reads this file).
- `scripts/verify/m019-p00-payload-shape.sh` exists, is executable, and exits 0 when all L1–L5 and pricing checks hold.

## Verification

Run (sequentially, not inline-composed):

```
bash scripts/verify/m019-p00-payload-shape.sh
```

Expected output includes one `PASS:` line for each of: L1 emission, 4 L1 subsections, L2 markers, L3 templates sweep, L3 intensity-gate sweep, L4 directive logic, L5 whitelist exists, L5 no unwhitelisted negatives, pricing.yml exists, 6 pricing.yml keys. Final line: `PASS: m019-p00-payload-shape.sh`. Exit 0.

Note: because T04 creates pricing.yml and T02 rewrites dispatch-prompt.md for L5, some of Gate 3, Gate 5, Gate 6 assertions will fail when T01 runs in isolation. That is expected. T05's phase-suite gate is the integration gate where every L-check passes. T01 is complete when the payload-shape gate (a) exists + is executable, (b) passes every check that depends only on T01's changes (Gates 1, 2, 4), and (c) fails exactly the L3/L5/pricing checks in a well-typed way (emits `FAIL:` lines pointing at the missing files, does not crash).

## Inputs

### From Previous Tasks

None — T01 is first.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — target file for modification. Key API: the TASK branch dispatch loop (lines 785–832) writes `TMPDIR_BUILD/s<idx>.txt` files and populates `SECTION_NAMES_PIPE`, `SECTION_PRIORITIES_PIPE`. The helper `_bc_assemble_manifest_and_emit $section_count $names_pipe $priorities_pipe $frontmatter $title` is called once to emit the final payload.
- `templates/dispatch-prompt.md` — template to extend with shape markers.
- `templates/context-recipe.yaml` — reference for `parallel_fan_out` field detection.
- [`.orchestrator/milestones/M019/M019-CONTEXT.md`](../../../../../milestones/M019/M019-CONTEXT.md) — AD-1..AD-8 definitions.
- `.orchestrator/scratch/articles-synthesis-2026-04-17.md` — L1–L5 source material.

## Constraints

- **Bash 3.2 compat** (Constitution VIII + MEM001). Do not use `declare -A`, `mapfile`, `readarray`, `<(`, `>(`, `${var^^}`, `${var,,}`.
- **No compound bash in agent-facing content** (Constitution XV + [M021](../../../../../milestones/M021/index.md) hook). Verify-script internals may use `$()`, pipes, subshells (MEM004 + AP-004 carve-out). Truth `Check:` commands in this plan and the phase plan are single-script-file shape (AD-19).
- **No PLANNING branch regression.** The planning branch (`_bc_assemble_planning_payload`) must emit byte-identical payload for the same inputs before and after this task. The new sections and markers apply to the TASK branch only.
- **Preserve the RESULT-line trap.** Line 52–68 emits `RESULT: ok|error` on exit. Do not break this.
- **Preserve recipe-driven dispatch.** The recipe-interpreter path (sorted sections + section-handlers.sh dispatch) must continue to work. The new sections are additive emissions, not recipe changes.
- **Surgical scope** (Constitution XV). No refactor of the existing `_bc_assemble_manifest_and_emit` beyond what's required for stable/volatile partitioning. No rename of existing section sources.

## Expected Output

After T01 completes:

- `scripts/dispatch/build-context.sh` contains three new helper functions (`_bc_build_first_turn_completeness`, `_bc_should_emit_parallel_fanout`, `_bc_build_parallel_fanout_block`, `_bc_section_volatility`) and the TASK-branch appends two new sections (first_turn + conditional parallel_fanout) before manifest assembly. `_bc_assemble_manifest_and_emit` partitions section files into stable-first/volatile-last order and inserts `<dispatch-volatile>` / `</dispatch-volatile>` marker lines in the emitted payload.
- `templates/dispatch-prompt.md` carries shape-documenting blocks for `## First-Turn Completeness` and `## Parallel Fan-Out`. All pre-existing expressive guidance is byte-identical (T02 rewrites).
- `scripts/verify/m019-p00-payload-shape.sh` exists + is executable; running it reports `PASS:` for Gates 1, 2, 4 (L1, L2, L4 assertions) and expected-in-isolation `FAIL:` for Gates 3, 5, 6 (which T02 + T04 complete). Final line is either `PASS: m019-p00-payload-shape.sh` (if T02+T04 already ran) or `FAIL:` with a count matching the missing-upstream conditions.
- Planning-branch payloads remain byte-identical.
- A fresh dispatch against a fixture milestone (e.g., a test-s04 or test-s05 fixture) produces a payload containing all three new markers and preserving the existing recipe-driven section set.
