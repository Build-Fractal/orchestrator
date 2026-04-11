#!/usr/bin/env bash
# scripts/dispatch/lib/section-handlers.sh — Per-source-type section assembly
[ -n "${_SECTION_HANDLERS_SOURCED:-}" ] && return 0
_SECTION_HANDLERS_SOURCED=1
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

# dispatch_section_handler <source> <section_name> <orch_root> <milestone> <phase> <task> [<included_ids_file>]
# Routes a recipe section to its handler by source value:
#   source: computed        → handle_computed
#   source: phase_summaries → handle_phase_summaries
#   source: phase_plan      → handle_phase_plan
#   source: task_plan       → handle_task_plan
#   source: template        → handle_template
#   source: KNOWLEDGE.md    → handle_knowledge (forwards included_ids_file)
#   source: <anything>.md   → handle_file (which further routes DECISIONS)
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
      if [ "$source" = "KNOWLEDGE.md" ] || [ "$source" = "knowledge.md" ]; then
        handle_knowledge "$orch_root" "$milestone" "$phase" "$task" "$included_ids_file"
      else
        handle_file "$orch_root" "$milestone" "$phase" "$task" "$source"
      fi
      ;;
    *)
      printf 'section-handlers: unknown source type: %s (section=%s)\n' \
        "$source" "$section_name" >&2
      return 1
      ;;
  esac
}
