---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M004"
name: "Section Handlers Library"
depends_on: []
---

## Description

Create `scripts/dispatch/lib/section-handlers.sh` — a new Bash 3.2 sibling library under the dispatch tree that implements one handler function per recipe section source type. This library is pure section-assembly mechanics; it does not parse YAML, does not emit events, and does not call `emit_result`. The caller (`build-context.sh`, refactored in T02) owns all of that.

The handlers extract logic currently inlined in `scripts/dispatch/build-context.sh` (`gather_knowledge_from_index`, `gather_decisions`, `gather_upstream_summaries`, the State/Scope/Constraints section string builders) into reusable functions that any recipe-driven caller can consume.

This implements FR-210 (recipe-driven assembly), FR-220 (emit_result on caller side), Principle X (Templating Over Inference) — scripts implement mechanics, templates declare policy — and Principle XI (Single Source of Truth) by making `templates/context-recipe.yaml` the one place sections are declared.

## Cross-Cutting Constraints (verbatim from P05-PLAN.md)

1. **Bash 3.2** — no `declare -A`, no `readarray`, no `mapfile`, no `<(…)` as a redirect target in `while read` loops. Use `mktemp` temp files for derived data iteration.
2. **Double-sourcing guard on lines 3–4** — shebang line 1, one-line comment line 2, `[ -n "${_SECTION_HANDLERS_SOURCED:-}" ] && return 0` line 3, `_SECTION_HANDLERS_SOURCED=1` line 4. Must pass `head -5 | grep -q '_SECTION_HANDLERS_SOURCED'`.
3. **Sibling library sourcing** — compute paths via `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` then use `$SCRIPT_DIR` for all cross-script references.
4. **No inline `date`** — sibling libraries must not call `date`. The caller owns timestamps via `orch_now`.
5. **Caller owns `emit_result`** — this library is pure; no result emission.
6. **No `jq`.**
7. **P06-deferred items — do NOT touch.** Do not edit `scripts/verify/check-must-haves.sh`, `scripts/lib/events.sh`, or `scripts/lifecycle/record-result.sh`.

## Steps

### Step 1: Verify prerequisites exist (from repo root)

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# P02 libraries must exist
test -f scripts/lib/errors.sh && echo "ok: errors.sh"
test -f scripts/lib/events.sh && echo "ok: events.sh"
test -f scripts/lib/run-context.sh && echo "ok: run-context.sh"

# P04 parser must exist
test -f scripts/lib/recipe-parser.sh && echo "ok: recipe-parser.sh"
test -f templates/context-recipe.yaml && echo "ok: context-recipe.yaml"

# Knowledge helpers we will wrap
test -x scripts/dispatch/scope-filter.sh && echo "ok: scope-filter.sh"
test -x scripts/knowledge/traverse-graph.sh && echo "ok: traverse-graph.sh"
test -x scripts/knowledge/resolve-entries.sh && echo "ok: resolve-entries.sh"
test -x scripts/knowledge/increment-hits.sh && echo "ok: increment-hits.sh"
```

All lines must print `ok: ...`. If any fail, STOP and escalate — P05's prerequisites are not met.

### Step 2: Create the directory

```bash
mkdir -p scripts/dispatch/lib
```

### Step 3: Create `scripts/dispatch/lib/section-handlers.sh`

Write a file with this exact top structure (first 4 lines are load-bearing for the head-5 guard check):

```bash
#!/usr/bin/env bash
# scripts/dispatch/lib/section-handlers.sh — Per-source-type section assembly
[ -n "${_SECTION_HANDLERS_SOURCED:-}" ] && return 0
_SECTION_HANDLERS_SOURCED=1
```

Then, below the guard, add the header comment block documenting the handler contract:

```bash
#
# Pure section-assembly library for recipe-driven build-context.sh. Every
# handler is a function that takes common orchestrator coordinates and prints
# the assembled section body to stdout. Handlers do NOT emit events, do NOT
# call emit_result, and do NOT read YAML — they are pure mechanics. The caller
# (build-context.sh) parses the recipe via scripts/lib/recipe-parser.sh and
# dispatches each section to the right handler here.
#
# Functions (all Bash 3.2 compatible):
#
#   handle_computed        <orch_root> <milestone> <phase> <task> <section_name>
#   handle_phase_summaries <orch_root> <milestone> <phase> <task>
#   handle_phase_plan      <orch_root> <milestone> <phase> <task>
#   handle_task_plan       <orch_root> <milestone> <phase> <task>
#   handle_template        <orch_root> <milestone> <phase> <task> <section_name>
#   handle_knowledge       <orch_root> <milestone> <phase> <task> [<included_ids_file>]
#   handle_decisions       <orch_root> <milestone> <phase> <task>
#   handle_file            <orch_root> <milestone> <phase> <task> <source_filename>
#   dispatch_section_handler <source> <section_name> <orch_root> <milestone> <phase> <task> [<included_ids_file>]
#
# Resolution rules shared by all handlers:
#   - <orch_root> may be either .specify/orchestrator OR a fixture milestone dir
#     (the caller has already normalized this). Handlers derive the milestone
#     directory as: "${orch_root}/milestones/${milestone}" if that exists, else
#     they fall back to treating <orch_root> as the milestone dir.
#
# Constitution: Principle X (Templating Over Inference), Principle XI (Single
# Source of Truth). AP-001 compliance: no process substitution in while loops.
```

Then source helpers — but do NOT source `errors.sh`/`events.sh`/`run-context.sh` from this library. The caller owns those. The library only needs the path to the knowledge helpers.

```bash
# --- Sibling path anchors ---
_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SH_DISPATCH_DIR="$(cd "${_SH_DIR}/.." && pwd)"
_SH_PROJECT_ROOT="$(cd "${_SH_DISPATCH_DIR}/.." && pwd)"

_SH_SCOPE_FILTER="${_SH_DISPATCH_DIR}/scope-filter.sh"
_SH_TRAVERSE_GRAPH="${_SH_PROJECT_ROOT}/knowledge/traverse-graph.sh"
_SH_RESOLVE_ENTRIES="${_SH_PROJECT_ROOT}/knowledge/resolve-entries.sh"
_SH_INCREMENT_HITS="${_SH_PROJECT_ROOT}/knowledge/increment-hits.sh"
_SH_READ_ROADMAP="${_SH_PROJECT_ROOT}/state/read-roadmap.sh"
_SH_READ_CONFIG="${_SH_PROJECT_ROOT}/state/read-config.sh"
```

### Step 4: Implement `_sh_resolve_milestone_dir` internal helper

```bash
# _sh_resolve_milestone_dir <orch_root> <milestone>
# Prints the milestone directory path. Supports both .specify/orchestrator
# layout and fixture layout where orch_root IS the milestone dir.
_sh_resolve_milestone_dir() {
  local orch_root="$1"
  local milestone="$2"
  if [ -d "${orch_root}/milestones/${milestone}" ]; then
    printf '%s\n' "${orch_root}/milestones/${milestone}"
  elif [ -d "${orch_root}/phases" ]; then
    printf '%s\n' "${orch_root}"
  else
    return 1
  fi
}
```

### Step 5: Implement `handle_computed`

```bash
# handle_computed <orch_root> <milestone> <phase> <task> <section_name>
# Returns a computed block. Currently only "state" is supported: prints the
# State Context block with milestone/phase/task/tier fields.
handle_computed() {
  local orch_root="$1" milestone="$2" phase="$3" task="$4" section_name="$5"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1

  case "$section_name" in
    state|State|STATE)
      local roadmap="${ms_dir}/${milestone}-ROADMAP.md"
      local tier="unknown"
      if [ -f "$roadmap" ] && [ -x "$_SH_READ_ROADMAP" ]; then
        tier="$(bash "$_SH_READ_ROADMAP" "$roadmap" tier 2>/dev/null || echo unknown)"
      fi
      printf '## State Context\n\n'
      printf -- '- **Current State**: executing\n'
      printf -- '- **Milestone**: %s\n' "$milestone"
      printf -- '- **Phase**: %s\n' "$phase"
      if [ "$task" != "PHASE_PLAN" ]; then
        printf -- '- **Task**: %s\n' "$task"
      fi
      printf -- '- **Tier**: %s\n' "$tier"
      ;;
    *)
      printf 'section-handlers: unknown computed section: %s\n' "$section_name" >&2
      return 1
      ;;
  esac
}
```

### Step 6: Implement `handle_phase_summaries`

Extract the `gather_upstream_summaries` logic from the current `build-context.sh` (lines 301–321 of the pre-refactor file). The logic:

```bash
# handle_phase_summaries <orch_root> <milestone> <phase> <task>
# Concatenates upstream phase summaries. Upstream phases are read from the
# roadmap "depends" field for the current phase. Prints "## Upstream Context"
# header followed by "### <PhaseID> Summary" blocks with the summary body.
handle_phase_summaries() {
  local orch_root="$1" milestone="$2" phase="$3"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1
  local roadmap="${ms_dir}/${milestone}-ROADMAP.md"
  printf '## Upstream Context\n\n'
  if [ ! -f "$roadmap" ] || [ ! -x "$_SH_READ_ROADMAP" ]; then
    printf 'No upstream summaries available.\n'
    return 0
  fi
  local phase_data depends
  phase_data="$(bash "$_SH_READ_ROADMAP" "$roadmap" phase "$phase" 2>/dev/null || true)"
  depends="none"
  if [ -n "$phase_data" ]; then
    depends="$(printf '%s' "$phase_data" | awk '{print $4}')"
  fi
  if [ -z "$depends" ] || [ "$depends" = "none" ]; then
    printf 'No upstream summaries available.\n'
    return 0
  fi
  local dep_list_file any_printed
  dep_list_file="$(mktemp)"
  printf '%s' "$depends" | tr ',' '\n' > "$dep_list_file"
  any_printed=0
  local dep
  while IFS= read -r dep; do
    dep="$(printf '%s' "$dep" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$dep" ] && continue
    local summary_file="${ms_dir}/phases/${dep}/${dep}-SUMMARY.md"
    if [ -f "$summary_file" ]; then
      printf '### %s Summary\n' "$dep"
      cat "$summary_file"
      printf '\n'
      any_printed=1
    fi
  done < "$dep_list_file"
  rm -f "$dep_list_file"
  if [ "$any_printed" -eq 0 ]; then
    printf 'No upstream summaries available.\n'
  fi
}
```

### Step 7: Implement `handle_phase_plan`

Extract the phase plan excerpt logic from the current `build-context.sh` (around lines 516–531 — the `grep -E '^## Goal'` / `'^## Demo'` / `sed -n '/^## Must-Haves/'` block).

```bash
# handle_phase_plan <orch_root> <milestone> <phase> <task>
# Returns the "## Scope" block containing Goal, Demo, and Must-Haves excerpt
# from the phase plan file.
handle_phase_plan() {
  local orch_root="$1" milestone="$2" phase="$3"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1
  local phase_plan="${ms_dir}/phases/${phase}/${phase}-PLAN.md"
  printf '## Scope\n\n'
  if [ ! -f "$phase_plan" ]; then
    printf 'Phase plan not found.\n'
    return 0
  fi
  local goal_line demo_line must_haves
  goal_line="$(grep -E '^## Goal' "$phase_plan" -A 2 2>/dev/null | tail -n +2 | head -2 || true)"
  demo_line="$(grep -E '^## Demo' "$phase_plan" -A 2 2>/dev/null | tail -n +2 | head -2 || true)"
  must_haves="$(sed -n '/^## Must-Haves/,/^## [^M]/p' "$phase_plan" | head -20 || true)"
  printf '### Goal\n%s\n\n### Demo\n%s\n\n### Must-Haves\n%s\n' \
    "$goal_line" "$demo_line" "$must_haves"
}
```

### Step 8: Implement `handle_task_plan`

```bash
# handle_task_plan <orch_root> <milestone> <phase> <task>
# Returns the "## Task Plan" block containing the full task plan file body.
handle_task_plan() {
  local orch_root="$1" milestone="$2" phase="$3" task="$4"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1
  local task_plan="${ms_dir}/phases/${phase}/tasks/${task}-PLAN.md"
  printf '## Task Plan\n\n'
  if [ ! -f "$task_plan" ]; then
    printf 'Task plan not found: %s\n' "$task_plan"
    return 0
  fi
  cat "$task_plan"
}
```

### Step 9: Implement `handle_template` (constraints block)

The current `build-context.sh` assembles a Constraints block from config-defaults values (verification criteria, duration_budget, dispatch_budget, budget_enforcement). Port that logic. The caller passes the resolved config values through the environment so the library does not have to know the config format.

```bash
# handle_template <orch_root> <milestone> <phase> <task> <section_name>
# Returns a templated block. Currently only "constraints" is supported.
# Caller must set SH_VERIFICATION_CRITERIA, SH_DURATION_BUDGET,
# SH_DISPATCH_BUDGET, SH_BUDGET_ENFORCEMENT env vars before invocation.
handle_template() {
  local section_name="$5"
  case "$section_name" in
    constraints|Constraints|CONSTRAINTS)
      printf '## Constraints\n\n'
      printf -- '- **Verification Criteria**: %s\n' "${SH_VERIFICATION_CRITERIA:-See phase plan must-haves}"
      printf -- '- **Duration Budget**: %s\n' "${SH_DURATION_BUDGET:-2h}"
      printf -- '- **Dispatch Budget**: %s\n' "${SH_DISPATCH_BUDGET:-3}"
      printf -- '- **Budget Enforcement**: %s\n' "${SH_BUDGET_ENFORCEMENT:-warn}"
      ;;
    *)
      printf 'section-handlers: unknown template section: %s\n' "$section_name" >&2
      return 1
      ;;
  esac
}
```

### Step 10: Implement `handle_knowledge`

Wrap the existing index pipeline. The caller passes an optional `<included_ids_file>` path as the fifth argument — when provided, the handler writes the set of included MEM IDs to that file so the caller can run `increment-hits.sh` after output.

```bash
# handle_knowledge <orch_root> <milestone> <phase> <task> [<included_ids_file>]
# Runs the index pipeline to emit a "## Knowledge" section. If the 5th
# argument is a writable file path, all resolved MEM IDs are written to it
# (one per line) so the caller can increment hit counts after emission.
handle_knowledge() {
  local orch_root="$1" milestone="$2" phase="$3"
  local included_ids_file="${5:-}"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1

  # Locate the knowledge index
  local knowledge_index=""
  if [ -f "${_SH_PROJECT_ROOT}/../KNOWLEDGE-INDEX.md" ]; then
    knowledge_index="${_SH_PROJECT_ROOT}/../KNOWLEDGE-INDEX.md"
  elif [ -f "${ms_dir}/KNOWLEDGE-INDEX.md" ]; then
    knowledge_index="${ms_dir}/KNOWLEDGE-INDEX.md"
  fi

  printf '## Knowledge\n\n'

  if [ -z "$knowledge_index" ]; then
    _sh_emit_flat_knowledge "$ms_dir" "$milestone" "$phase"
    return 0
  fi

  # Read phase depends for scope-filter
  local roadmap="${ms_dir}/${milestone}-ROADMAP.md"
  local depends="none"
  if [ -f "$roadmap" ] && [ -x "$_SH_READ_ROADMAP" ]; then
    local phase_data
    phase_data="$(bash "$_SH_READ_ROADMAP" "$roadmap" phase "$phase" 2>/dev/null || true)"
    if [ -n "$phase_data" ]; then
      depends="$(printf '%s' "$phase_data" | awk '{print $4}')"
    fi
  fi

  local dep_flag=""
  if [ "$depends" != "none" ] && [ -n "$depends" ]; then
    dep_flag="--depends $depends"
  fi

  # Step 1: scope-filter
  local filtered_file matched_file
  filtered_file="$(mktemp)"
  matched_file="$(mktemp)"
  bash "$_SH_SCOPE_FILTER" "$knowledge_index" "${milestone}/${phase}" \
    --type knowledge $dep_flag > "$filtered_file" 2>/dev/null || true

  if [ ! -s "$filtered_file" ]; then
    printf 'No knowledge entries in scope.\n'
    rm -f "$filtered_file" "$matched_file"
    return 0
  fi

  # Step 2: extract MEM IDs from filtered lines
  local line eid
  while IFS= read -r line; do
    eid="$(printf '%s' "$line" | grep -oE '^MEM[0-9]+' || true)"
    [ -n "$eid" ] && printf '%s\n' "$eid" >> "$matched_file"
  done < "$filtered_file"
  rm -f "$filtered_file"

  if [ ! -s "$matched_file" ]; then
    printf 'No knowledge entries in scope.\n'
    rm -f "$matched_file"
    return 0
  fi

  # Step 3: traverse graph 1-hop for each matched ID
  local all_ids_file related_file
  all_ids_file="$(mktemp)"
  related_file="$(mktemp)"
  cat "$matched_file" > "$all_ids_file"
  while IFS= read -r eid; do
    [ -z "$eid" ] && continue
    bash "$_SH_TRAVERSE_GRAPH" --id "$eid" --max-depth 1 --max-entries 5 \
      >> "$related_file" 2>/dev/null || true
  done < "$matched_file"
  cat "$related_file" >> "$all_ids_file"
  rm -f "$related_file" "$matched_file"

  # Step 4: deduplicate
  local sorted_file
  sorted_file="$(mktemp)"
  sort -u "$all_ids_file" > "$sorted_file"
  rm -f "$all_ids_file"

  # Forward IDs to caller if requested
  if [ -n "$included_ids_file" ]; then
    cp "$sorted_file" "$included_ids_file"
  fi

  # Step 5: resolve
  local resolved
  resolved="$(cat "$sorted_file" | bash "$_SH_RESOLVE_ENTRIES" 2>/dev/null || true)"
  local entry_count
  entry_count="$(grep -c 'MEM' "$sorted_file" 2>/dev/null || echo 0)"
  rm -f "$sorted_file"

  if [ -z "$resolved" ]; then
    printf 'No knowledge entries in scope.\n'
  else
    printf '<!-- %s knowledge entries resolved from index -->\n\n' "$entry_count"
    printf '%s\n' "$resolved"
  fi
}

# Internal: flat KNOWLEDGE.md fallback when no index is present.
_sh_emit_flat_knowledge() {
  local ms_dir="$1" milestone="$2" phase="$3"
  local knowledge_file="${ms_dir}/KNOWLEDGE.md"
  if [ ! -f "$knowledge_file" ]; then
    printf 'No knowledge entries in scope.\n'
    return 0
  fi
  local roadmap="${ms_dir}/${milestone}-ROADMAP.md"
  local depends="none"
  if [ -f "$roadmap" ] && [ -x "$_SH_READ_ROADMAP" ]; then
    local phase_data
    phase_data="$(bash "$_SH_READ_ROADMAP" "$roadmap" phase "$phase" 2>/dev/null || true)"
    if [ -n "$phase_data" ]; then
      depends="$(printf '%s' "$phase_data" | awk '{print $4}')"
    fi
  fi
  local dep_flag=""
  if [ "$depends" != "none" ] && [ -n "$depends" ]; then
    dep_flag="--depends $depends"
  fi
  local entries
  entries="$(bash "$_SH_SCOPE_FILTER" "$knowledge_file" "${milestone}/${phase}" \
    --type knowledge $dep_flag 2>/dev/null || true)"
  if [ -z "$entries" ]; then
    printf 'No knowledge entries in scope.\n'
  else
    printf '%s\n' "$entries"
  fi
}
```

### Step 11: Implement `handle_decisions`

```bash
# handle_decisions <orch_root> <milestone> <phase> <task>
# Scope-filters DECISIONS.md and emits the "## Decisions" block.
handle_decisions() {
  local orch_root="$1" milestone="$2" phase="$3"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1
  printf '## Decisions\n\n'
  local decisions_file="${ms_dir}/DECISIONS.md"
  if [ ! -f "$decisions_file" ]; then
    printf 'No decision entries in scope.\n'
    return 0
  fi
  local roadmap="${ms_dir}/${milestone}-ROADMAP.md"
  local depends="none"
  if [ -f "$roadmap" ] && [ -x "$_SH_READ_ROADMAP" ]; then
    local phase_data
    phase_data="$(bash "$_SH_READ_ROADMAP" "$roadmap" phase "$phase" 2>/dev/null || true)"
    if [ -n "$phase_data" ]; then
      depends="$(printf '%s' "$phase_data" | awk '{print $4}')"
    fi
  fi
  local dep_flag=""
  if [ "$depends" != "none" ] && [ -n "$depends" ]; then
    dep_flag="--depends $depends"
  fi
  local entries
  entries="$(bash "$_SH_SCOPE_FILTER" "$decisions_file" "${milestone}/${phase}" \
    --type decisions $dep_flag 2>/dev/null || true)"
  if [ -z "$entries" ]; then
    printf 'No decision entries in scope.\n'
  else
    printf '%s\n' "$entries"
  fi
}
```

### Step 12: Implement `handle_file`

```bash
# handle_file <orch_root> <milestone> <phase> <task> <source_filename>
# Generic filename dispatcher. Routes KNOWLEDGE.md / DECISIONS.md to their
# dedicated handlers; falls back to a raw cat for anything else at the
# milestone-dir root.
handle_file() {
  local orch_root="$1" milestone="$2" phase="$3" task="$4" source_filename="$5"
  case "$source_filename" in
    KNOWLEDGE.md|knowledge.md)
      handle_knowledge "$orch_root" "$milestone" "$phase" "$task"
      ;;
    DECISIONS.md|decisions.md)
      handle_decisions "$orch_root" "$milestone" "$phase" "$task"
      ;;
    *)
      local ms_dir
      ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1
      local f="${ms_dir}/${source_filename}"
      if [ -f "$f" ]; then
        cat "$f"
      else
        printf 'section-handlers: file not found: %s\n' "$f" >&2
        return 1
      fi
      ;;
  esac
}
```

### Step 13: Implement `dispatch_section_handler`

The top-level router the caller uses to go from `parse_recipe_sections` output to a handler call.

```bash
# dispatch_section_handler <source> <section_name> <orch_root> <milestone> <phase> <task> [<included_ids_file>]
# Routes a recipe section to its handler by source value:
#   source: computed        → handle_computed
#   source: phase_summaries → handle_phase_summaries
#   source: phase_plan      → handle_phase_plan
#   source: task_plan       → handle_task_plan
#   source: template        → handle_template
#   source: <anything>.md   → handle_file (which further routes KNOWLEDGE/DECISIONS)
dispatch_section_handler() {
  local source="$1" section_name="$2"
  local orch_root="$3" milestone="$4" phase="$5" task="$6"
  local included_ids_file="${7:-}"
  case "$source" in
    computed)
      handle_computed "$orch_root" "$milestone" "$phase" "$task" "$section_name"
      ;;
    phase_summaries)
      handle_phase_summaries "$orch_root" "$milestone" "$phase" "$task"
      ;;
    phase_plan)
      handle_phase_plan "$orch_root" "$milestone" "$phase" "$task"
      ;;
    task_plan)
      handle_task_plan "$orch_root" "$milestone" "$phase" "$task"
      ;;
    template)
      handle_template "$orch_root" "$milestone" "$phase" "$task" "$section_name"
      ;;
    *.md)
      handle_file "$orch_root" "$milestone" "$phase" "$task" "$source" "$included_ids_file"
      ;;
    *)
      printf 'section-handlers: unknown source type: %s (section=%s)\n' \
        "$source" "$section_name" >&2
      return 1
      ;;
  esac
}
```

Note: `handle_file` doesn't currently take `<included_ids_file>` as a parameter; knowledge-specific callers should call `handle_knowledge` directly when they need the ID file. The dispatcher forwards it only for the `.md` branch — adjust the dispatcher to call `handle_knowledge` with the ID file when the filename is `KNOWLEDGE.md`:

```bash
    *.md)
      if [ "$source" = "KNOWLEDGE.md" ] || [ "$source" = "knowledge.md" ]; then
        handle_knowledge "$orch_root" "$milestone" "$phase" "$task" "$included_ids_file"
      else
        handle_file "$orch_root" "$milestone" "$phase" "$task" "$source"
      fi
      ;;
```

Replace the earlier `*.md` branch with this variant when finalizing the file.

### Step 14: Make executable

```bash
chmod +x scripts/dispatch/lib/section-handlers.sh
```

### Step 15: Smoke test the sourcing from repo root

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Sourcing must not print anything and must return 0
( . scripts/dispatch/lib/section-handlers.sh; type handle_computed >/dev/null 2>&1 && echo "ok: sourced" )

# Double-sourcing must be a no-op
( . scripts/dispatch/lib/section-handlers.sh; . scripts/dispatch/lib/section-handlers.sh; echo "ok: double-source" )

# Each handler function must be defined
for fn in handle_computed handle_phase_summaries handle_phase_plan handle_task_plan \
          handle_template handle_knowledge handle_decisions handle_file \
          dispatch_section_handler; do
  ( . scripts/dispatch/lib/section-handlers.sh && type "$fn" >/dev/null 2>&1 ) \
    && echo "ok: $fn" || echo "FAIL: $fn"
done
```

All lines must print `ok:`.

### Step 16: Behavioral smoke test — run `handle_computed` against a real milestone

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
( . scripts/dispatch/lib/section-handlers.sh && handle_computed .specify/orchestrator M004 P04 T04 state )
# Expected output:
# ## State Context
#
# - **Current State**: executing
# - **Milestone**: M004
# - **Phase**: P04
# - **Task**: T04
# - **Tier**: C
```

## Must-Haves

### Truths

- `scripts/dispatch/lib/section-handlers.sh` exists with a double-sourcing guard on lines 3–4
  - Check: `head -5 scripts/dispatch/lib/section-handlers.sh | grep -q '_SECTION_HANDLERS_SOURCED'`
- All 8 handlers plus the dispatcher are defined
  - Check: `for fn in handle_computed handle_phase_summaries handle_phase_plan handle_task_plan handle_template handle_knowledge handle_decisions handle_file dispatch_section_handler; do grep -q "^${fn}()" scripts/dispatch/lib/section-handlers.sh || exit 1; done`
- No Bash 4+ constructs
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/dispatch/lib/section-handlers.sh`
- No process substitution in while loops (AP-001)
  - Check: `! grep -qE 'done\s*<\s*<\(' scripts/dispatch/lib/section-handlers.sh`
- No inline `date` calls (Principle IX)
  - Check: `! grep -nE '\$\(date\b|^[[:space:]]*date[[:space:]]+-u' scripts/dispatch/lib/section-handlers.sh`
- No jq usage
  - Check: `! grep -q 'jq ' scripts/dispatch/lib/section-handlers.sh`
- Library is sourceable without errors
  - Check: `( . scripts/dispatch/lib/section-handlers.sh && type handle_computed >/dev/null )`

### Artifacts

- `scripts/dispatch/lib/section-handlers.sh` (min 200 lines, contains "_SECTION_HANDLERS_SOURCED")

### Key Links

- `scripts/dispatch/lib/section-handlers.sh` → `scripts/dispatch/scope-filter.sh`
- `scripts/dispatch/lib/section-handlers.sh` → `scripts/knowledge/traverse-graph.sh`
- `scripts/dispatch/lib/section-handlers.sh` → `scripts/knowledge/resolve-entries.sh`

## Verification

Run these from the repo root:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T01 Verification ==="

# File exists
test -f scripts/dispatch/lib/section-handlers.sh && echo "PASS: file exists" || echo "FAIL: file missing"

# Executable
test -x scripts/dispatch/lib/section-handlers.sh && echo "PASS: executable" || echo "FAIL: not executable"

# Min lines
lines=$(wc -l < scripts/dispatch/lib/section-handlers.sh | tr -d ' ')
test "$lines" -ge 200 && echo "PASS: $lines lines (min 200)" || echo "FAIL: only $lines lines"

# Double-sourcing guard on lines 3-4
head -5 scripts/dispatch/lib/section-handlers.sh | grep -q '_SECTION_HANDLERS_SOURCED' \
  && echo "PASS: guard" || echo "FAIL: guard missing"

# Handler functions
for fn in handle_computed handle_phase_summaries handle_phase_plan handle_task_plan \
          handle_template handle_knowledge handle_decisions handle_file \
          dispatch_section_handler; do
  grep -q "^${fn}()" scripts/dispatch/lib/section-handlers.sh \
    && echo "PASS: $fn defined" || echo "FAIL: $fn missing"
done

# Bash 3.2 compat
! grep -qE 'declare -A|readarray|mapfile' scripts/dispatch/lib/section-handlers.sh \
  && echo "PASS: Bash 3.2" || echo "FAIL: Bash 4+ construct"

# No process substitution in while loops
! grep -qE 'done\s*<\s*<\(' scripts/dispatch/lib/section-handlers.sh \
  && echo "PASS: no process subst" || echo "FAIL: process subst found"

# No inline date
! grep -nE '\$\(date\b|^[[:space:]]*date[[:space:]]+-u' scripts/dispatch/lib/section-handlers.sh \
  && echo "PASS: no inline date" || echo "FAIL: inline date found"

# Sourceable
( . scripts/dispatch/lib/section-handlers.sh && type handle_computed >/dev/null 2>&1 ) \
  && echo "PASS: sourceable" || echo "FAIL: source error"

# Behavioral: handle_computed returns state block for M004/P04/T04
( . scripts/dispatch/lib/section-handlers.sh && \
  handle_computed .specify/orchestrator M004 P04 T04 state | grep -q 'Milestone.*M004' ) \
  && echo "PASS: handle_computed behavioral" || echo "FAIL: handle_computed output wrong"
```

## Inputs

### From Previous Tasks

None — T01 is the first task in P05.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — Read for reference only. This task extracts logic from it into handlers; T02 rewrites it. Key functions to port: `gather_knowledge_from_index` (lines ~167–259), `gather_knowledge_flat` (~263–278), `gather_decisions` (~281–298), `gather_upstream_summaries` (~301–321).
- `scripts/lib/recipe-parser.sh` — Its `parse_recipe_sections` output format is `<name>|<source>|<priority>|<order>|<filter>|<cache_hint>` (pipe-delimited, sorted by order ascending). T01 does NOT source this file — T01 is the handler layer; T02 owns recipe parsing.
- `scripts/lib/errors.sh` / `scripts/lib/events.sh` / `scripts/lib/run-context.sh` — NOT sourced by this library. The caller (T02) owns these.
- `scripts/dispatch/scope-filter.sh` — Entry-point args: `scope-filter.sh <file> <scope-context M###/P##> [--type knowledge|decisions] [--depends P01,P02]`. Prints filtered entries to stdout, exit 0 on success.
- `scripts/knowledge/traverse-graph.sh` — Args: `--id <MEM-ID> --max-depth N --max-entries N`. Prints related MEM IDs to stdout, one per line.
- `scripts/knowledge/resolve-entries.sh` — Reads MEM IDs from stdin, one per line. Prints resolved entry content to stdout.
- `scripts/knowledge/increment-hits.sh` — Args: `--id <MEM-ID>`. Increments the hit counter. Called by T02 (the caller), NOT by this library.
- `scripts/state/read-roadmap.sh` — Args: `<roadmap-file> phase <P##>` prints a whitespace-separated line where field 4 is the comma-separated depends list. Args: `<roadmap-file> tier` prints the milestone tier.
- `scripts/state/read-config.sh` — NOT called by this library. T02 owns config reading and passes values via env vars (`SH_VERIFICATION_CRITERIA`, etc.).
- `templates/context-recipe.yaml` — Reference only (T01 doesn't read YAML). Defines the default 7 sections. For each, the `source:` field determines which handler this library will be asked to invoke. `source: computed` → state. `source: KNOWLEDGE.md` → knowledge. `source: DECISIONS.md` → decisions. `source: phase_summaries` → upstream. `source: phase_plan` → scope. `source: task_plan` → task_plan. `source: template` → constraints.

## Expected Output

A new file `scripts/dispatch/lib/section-handlers.sh` containing:

1. Shebang + one-line comment + double-sourcing guard (lines 1–4).
2. Header comment block documenting the handler contract.
3. Sibling-path anchors (`_SH_DIR`, `_SH_DISPATCH_DIR`, `_SH_PROJECT_ROOT`, `_SH_SCOPE_FILTER`, `_SH_TRAVERSE_GRAPH`, `_SH_RESOLVE_ENTRIES`, `_SH_INCREMENT_HITS`, `_SH_READ_ROADMAP`, `_SH_READ_CONFIG`).
4. `_sh_resolve_milestone_dir` internal helper.
5. `handle_computed`, `handle_phase_summaries`, `handle_phase_plan`, `handle_task_plan`, `handle_template`, `handle_knowledge`, `_sh_emit_flat_knowledge` (internal), `handle_decisions`, `handle_file`, `dispatch_section_handler` — all Bash 3.2 compatible, all sourceable, all pure mechanics.
6. Executable permission (`chmod +x`).
7. File length ≥ 200 lines (the handler bodies above total roughly 260 lines before compression).

No changes to any other file in the repo.
